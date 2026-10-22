package solarflare.barter;

import solarflare.statusboard.StatusBoardText;
import solarflare.statusboard.StatusBoardTooltipCache.StatusBoardTooltip;
import solarflare.statusboard.StatusBoardTooltipLabels;

/**
 * Hover-driven description cache for BarTer skill ("s:id") and consumable ("i:kind") cells.
 * Same shape as StatusBoardTooltipCache: draw only posts a primitive key into a one-slot mailbox, and the
 * observer resolves it. No hover means no work; rows hold primitives only and never an engine pointer.
 *
 * Triggers (docs/EVENT_DRIVEN_PLAYBOOK.md): hover start (edge), native loadout epoch (the edge that populates BarTer),
 * locale change (fingerprint), identity change (clear), a 20 s net for a long hover, and a 1 s retry for rows that could not resolve.
 */
class BarTerTipCache {
 public static inline var MAX:Int=128;
 public static inline var EXPIRE_S:Float=0.25;
 public static inline var SAFETY_S:Float=20;
 public static inline var RETRY_S:Float=1;
 static var rows:Map<String,StatusBoardTooltip>=new Map();
 /** Native loadout epoch each skill row was resolved in; a weapon change bumps it and makes skill rows stale. */
 static var epochs:Map<String,Int>=new Map();
 static var size:Int=0;
 static var wanted:String="";
 static var wantedLabel:String="";
 static var wantedSnap:BarTerSnap=null;
 static var requestedAt:Float=-1000;
 static var edge:Bool=false;
 static var attempted:Bool=false;
 public static var refreshes(default,null):Int=0;

 /** Memoized on the frozen cell so hovering never rebuilds the key string per frame. */
 public static function keyOf(s:BarTerSnap):String {
  var id=s.isItem ? s.itemKind : s.skillId;
  if (s.tipKeyId != id || s.tipKeyItem != s.isItem) { s.tipKey=(s.isItem ? "i:" : "s:")+id; s.tipKeyId=id; s.tipKeyItem=s.isItem; }
  return s.tipKey;
 }
 public static function eligible(s:BarTerSnap):Bool return s.isItem ? s.itemKind.length>0 : s.kind == "skill" && s.skillId.length>0;
 public static function get(key:String):StatusBoardTooltip return rows.get(key);

 public static function clear():Void { rows.clear(); epochs.clear(); size=0; wanted=wantedLabel=""; wantedSnap=null; requestedAt=-1000; edge=attempted=false; refreshes=0; }
 public static function beginPass():Void attempted=false;
 /** Called from draw on hover: primitives and the frozen cell only. */
 public static function request(key:String,now:Float,label:String,snap:BarTerSnap):Void {
  if (key == null || key.length == 0) return;
  if (key != wanted || now-requestedAt>EXPIRE_S) edge=true;
  wanted=key; wantedLabel=label; wantedSnap=snap; requestedAt=now;
 }
 /** The hovered key that needs a (re)resolve this pass, else "". Compares only. */
 public static function due(now:Float,epoch:Int=0):String {
  if (wanted.length == 0 || attempted || now-requestedAt>EXPIRE_S) return "";
  var row=rows.get(wanted);
  if (row == null || row.locale != StatusBoardTooltipLabels.locale) return wanted;
  var skill=wanted.charCodeAt(0) == "s".code;
  // The loadout changed since this skill row was resolved: its rank, cooldown pool and text may differ.
  if (skill && epochs.get(wanted) != epoch) return wanted;
  var age=now-row.lastRefresh;
  if (row.failed || row.resolution == "missing" || row.resolution == "catalog") return age>=RETRY_S ? wanted : "";
  // Item text is static per kind + locale; skill text can change with rank, talents and gear.
  if (skill && ((edge && age>=RETRY_S) || age>=SAFETY_S)) return wanted;
  return "";
 }
 /** The row for the current hover, so the observer can prepare its layout. */
 public static function hovered(now:Float):StatusBoardTooltip return wanted.length>0 && now-requestedAt<=EXPIRE_S ? rows.get(wanted) : null;

 /** One observer pass: resolve the hovered key if due, then refresh its dynamic facts line. */
 public static function service(now:Float,hero:Dynamic,skillOf:String->Dynamic,epoch:Int=0,itemOf:String->Dynamic->Dynamic=null):Void {
  if (wanted.length == 0 || now-requestedAt>EXPIRE_S) return;
  StatusBoardTooltipLabels.refresh();
  var key=due(now,epoch);
  if (key.length>0) resolve(key,now,hero,skillOf,epoch,null,itemOf);
  var row=rows.get(wanted);
  if (row != null && wantedSnap != null) facts(row,wantedSnap);
 }
 /**
  * Native populate edge (BarTerNativeKeys.sample): the live skill for `id` is in hand. If it is the hovered cell and its
  * row is missing, stale for this epoch, failed or in another language, resolve it now rather than waiting for Geaux's
  * identity map, which is rebuilt on layout changes. Idle cost: two compares per action while nothing is hovered.
  */
 public static function offerSkill(id:String,skill:Dynamic,hero:Dynamic,epoch:Int,now:Float):Void {
  if (wanted.length == 0 || now-requestedAt>EXPIRE_S || skill == null || wanted.charCodeAt(0) != "s".code) return;
  if (wanted.length != id.length+2 || wanted.substr(2) != id) return;
  StatusBoardTooltipLabels.refresh();
  var row=rows.get(wanted);
  // A row rendered from the CDB by id (no live skill then) is upgraded to the rank-aware live text here.
  if (row != null && row.locale == StatusBoardTooltipLabels.locale && !row.failed && row.resolution == "skill" && epochs.get(wanted) == epoch) return;
  resolve(wanted,now,hero,null,epoch,skill);
 }
 static function resolve(key:String,now:Float,hero:Dynamic,skillOf:String->Dynamic,epoch:Int,live:Dynamic,itemOf:String->Dynamic->Dynamic=null):Void {
  attempted=true;
  var row=rows.get(key);
  if (row == null) {
   if (size>=MAX) { rows.clear(); epochs.clear(); size=0; }
   row=new StatusBoardTooltip(key); rows.set(key,row); size++;
  }
  row.lastRefresh=now; refreshes++; edge=false; epochs.set(key,epoch);
  var id=key.substr(2);
  var tip=key.charCodeAt(0) == "s".code ? BarTerTipText.skill(live != null ? live : skillOf(id),id,wantedLabel,hero) : BarTerTipText.item(id,wantedLabel,itemOf == null ? null : itemOf(id,hero));
  if (row.title != tip.title) row.layoutSize=-1;
  row.title=tip.title; row.caption=tip.caption; row.resolution=tip.resolution; row.failed=tip.failed; row.locale=tip.locale;
  if (row.markup != tip.description) { row.markup=tip.description; row.runs=StatusBoardText.parse(tip.description); row.layoutSize=-1; row.revision++; }
 }

 /** Dynamic line from the already-frozen cell; rebuilt only when a displayed value changes. */
 public static function facts(row:StatusBoardTooltip,s:BarTerSnap):Void {
  var labels=StatusBoardTooltipLabels;
  var key=s.keyLabel.length>0 && s.keyLabel != "Unknown" ? s.keyLabel : "";
  if (s.isItem) {
   var itemState=s.usable ? 1 : 0;
   if (row.factsStacks == s.count && row.factsState == itemState && row.factsKey == key && row.factsLocale == labels.locale) return;
   row.factsStacks=s.count; row.factsState=itemState; row.factsKey=key; row.factsLocale=labels.locale;
   var itemParts=[labels.owned+": "+s.count];
   if (key.length>0) itemParts.push(labels.key+": "+key);
   if (!s.usable) itemParts.push(labels.notUsable);
   row.facts=itemParts.join(" · ");
   return;
  }
  var cd=s.cdLeft>0.05 ? Math.ceil(s.cdLeft) : 0;
  var charges=s.chargesMax>1 ? s.charges*256+s.chargesMax : -1;
  var state=(s.available ? 1 : 0)|(s.affordable ? 2 : 0)|(s.cooldownValid ? 4 : 0);
  if (row.factsStacks == charges && row.factsDuration == cd && row.factsState == state && row.factsKey == key && row.factsLocale == labels.locale) return;
  row.factsStacks=charges; row.factsDuration=cd; row.factsState=state; row.factsKey=key; row.factsLocale=labels.locale;
  var parts:Array<String>=[];
  if (key.length>0) parts.push(labels.key+": "+key);
  if (s.chargesMax>1) parts.push(labels.charges+": "+s.charges+"/"+s.chargesMax);
  if (cd>0) parts.push(labels.cooldown+": "+StatusBoardText.duration(s.cdLeft));
  else if (s.available && s.cooldownValid) parts.push(labels.ready);
  if (s.available && !s.affordable) parts.push(labels.noResources);
  if (!s.available) parts.push(labels.notUsable);
  row.facts=parts.join(" · ");
 }

 /** Assignment edit: drop rows no cell references any more. */
 public static function prune(keep:Array<String>):Void {
  var kept:Map<String,Bool>=new Map();
  for (k in keep) kept.set(k,true);
  var stale=[for (k in rows.keys()) if (!kept.exists(k)) k];
  for (k in stale) { rows.remove(k); epochs.remove(k); size--; }
  if (stale.indexOf(wanted)>=0) wanted="";
 }
 /** Bounded coverage inventory for explicit diagnostics; never called by draw. */
 public static function coverage():Array<{key:String,title:String,resolution:String,failed:Bool,locale:String}>
  return [for (k in rows.keys()) {key:k,title:rows.get(k).title,resolution:rows.get(k).resolution,failed:rows.get(k).failed,locale:rows.get(k).locale}];
}
