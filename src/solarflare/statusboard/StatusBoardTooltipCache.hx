package solarflare.statusboard;

class StatusBoardTooltip {
 public var instanceId:String;
 public var title:String="";
 public var caption:String="";
 public var markup:String="";
 public var runs:Array<StatusBoardText.StatusTextRun>=[];
 public var positioned:Array<StatusBoardText.StatusPositionedText>=[];
 public var heading:Array<StatusBoardText.StatusPositionedText>=[];
 public var headingHeight:Float=0;
 public var bodyHeight:Float=0;
 public var layoutSize:Float=-1;
 public var lastRefresh:Float=-1000;
 public var revision:Int=0;
 public var resolution:String="pending";
 public var sourceItemId:String="";
 public var statusId:String="";
 public var locale:String="";
 public var failed:Bool=false;
 public var facts:String="";
 public var factsStacks:Int=-2;
 public var factsDuration:Int=-2;
 public var factsState:Int=-1;
 public var factsLocale:String="";
 public var factsKey:String="";
 public function new(id:String) instanceId=id;
}

/** Primitive cache and hover mailbox. Native status references never enter this cache. */
class StatusBoardTooltipCache {
 public static inline var MAX:Int=512;
 static var ownerGeneration:Int=-1;
 static var rows:Map<String,StatusBoardTooltip>=new Map();
 static var indices:Map<String,Int>=new Map();
 static var size:Int=0;
 static var indexCount:Int=0;
 static var present:Map<String,Bool>=new Map();
 static var gone:Array<String>=[];
 static var wanted:String="";
 static var wantedLabel:String="";
 static var requestedAt:Float=-1;
 static var attempted:Bool=false;
 public static var refreshes(default,null):Int=0;
 public static function demand():Bool return solarflare.ObserveDemand.statusBoard || solarflare.ObserveDemand.barterStatusIds.length>0;
 public static function syncOwner(generation:Int):Void {
  if (ownerGeneration == generation) return;
  clear(); ownerGeneration=generation;
 }
 public static function clear():Void { rows.clear(); indices.clear(); present.clear(); gone.resize(0); size=indexCount=0; wanted=wantedLabel=""; attempted=false; requestedAt=-1; refreshes=0; }
 public static function beginPass():Void attempted=false;
 public static function request(instanceId:String,now:Float,label:String=""):Void {
  if (instanceId == null || instanceId.length == 0) return;
  wanted=instanceId; wantedLabel=label; requestedAt=now;
 }
 public static function due(now:Float):String {
  if (wanted.length == 0 || attempted || now-requestedAt > 0.25) return "";
  var row=rows.get(wanted);
  return row == null || now-row.lastRefresh>=1 ? wanted : "";
 }
 public static function get(id:String):StatusBoardTooltip return rows.get(id);
 public static function noteIndex(id:String,index:Int):Void {
  if (id.length == 0) return;
  if (!indices.exists(id)) { if (indexCount>=MAX) return; indexCount++; }
  indices.set(id,index);
 }
 public static function indexOf(id:String):Int { var n=indices.get(id); return n == null ? -1 : n; }
 public static function forgetIndex(id:String):Void { if (indices.remove(id)) indexCount--; }
 public static function invalidate(id:String):Void {
  var row=rows.get(id);
  if (row != null) { row.markup=""; row.runs.resize(0); row.positioned.resize(0); row.bodyHeight=0; rows.remove(id); size--; }
  forgetIndex(id); if (wanted == id) wanted="";
 }
 public static function reconcile(snaps:Array<solarflare.aura.AuraStatusSnap>,count:Int,complete:Bool):Void {
  present.clear();
  for (i in 0...count) {
   var s=snaps[i]; if (s.instanceId.length == 0) continue;
   if (s.known && !s.present) invalidate(s.instanceId);
   else present.set(s.instanceId,true);
  }
  if (complete) {
   gone.resize(0); for (id in indices.keys()) if (!present.exists(id)) gone.push(id);
   for (id in rows.keys()) if (!present.exists(id) && gone.indexOf(id)<0) gone.push(id);
   for (id in gone) invalidate(id);
  }
 }
 public static function observe(item:Dynamic,id:String,hero:Dynamic,now:Float):Void {
  if (id != due(now)) return;
  attempted=true;
  try { var status:st.skill.Status=item; if (status.removed) { invalidate(id); return; } } catch (_:Dynamic) { return; }
  var row=rows.get(id);
  if (row == null) { if (size>=MAX) return; row=new StatusBoardTooltip(id); rows.set(id,row); size++; }
  row.lastRefresh=now; refreshes++;
  var text=StatusBoardNativeText.read(item,hero,wantedLabel);
  if (text == null) {
   row.title=StatusBoardNativeText.fallback(wantedLabel); row.caption=""; row.statusId=row.sourceItemId=""; row.failed=true; row.resolution="failed";
   row.markup=StringTools.htmlEscape(StatusBoardTooltipLabels.unavailable); row.runs=StatusBoardText.parse(row.markup);
   row.positioned.resize(0); row.heading.resize(0); row.bodyHeight=row.headingHeight=0; row.layoutSize=-1; row.revision++; return;
  }
  if (row.title != text.title) row.layoutSize=-1;
  row.title=text.title; row.caption=text.caption;
  row.resolution=text.resolution; row.statusId=text.statusId; row.sourceItemId=text.sourceItemId; row.failed=text.failed; row.locale=text.locale;
  if (row.markup != text.description) { row.markup=text.description; row.runs=StatusBoardText.parse(text.description); row.layoutSize=-1; row.revision++; }
 }
 /** Prepared from frozen board snapshots, independent of timer/stack display toggles. */
 public static function facts(s:solarflare.aura.AuraStatusSnap,now:Float):Void {
  var row=rows.get(s.instanceId); if (row == null) return;
  var left=StatusBoardState.seconds(s,now);
  var unit=!s.durationKnown || s.infinite ? 0 : left>=3600 ? 2 : left>=60 ? 1 : 0;
  var duration=!s.durationKnown || s.infinite ? -1 : Std.int(unit==2 ? Math.floor(left/3600) : unit==1 ? Math.floor(left/60) : Math.ceil(left));
  var stacks=s.stacksKnown ? s.stacks : -1;
  var state=(s.durationKnown ? 1 : 0)|(s.infinite ? 2 : 0)|(s.stampSource=="cdb" ? 4 : 0)|(unit<<3);
  if(row.factsStacks==stacks && row.factsDuration==duration && row.factsState==state && row.factsLocale==StatusBoardTooltipLabels.locale) return;
  row.factsStacks=stacks; row.factsDuration=duration; row.factsState=state; row.factsLocale=StatusBoardTooltipLabels.locale;
  var text=s.stacksKnown ? StatusBoardTooltipLabels.stacks+": "+s.stacks : "";
  text+=(text.length>0 ? " · " : "")+(!s.durationKnown ? StatusBoardTooltipLabels.durationUnavailable : s.infinite ? StatusBoardTooltipLabels.noExpiry : (s.stampSource=="cdb" ? StatusBoardTooltipLabels.estimated : StatusBoardTooltipLabels.remaining)+": "+StatusBoardText.duration(StatusBoardState.seconds(s,now)));
  row.facts=text;
 }
 /** Bounded coverage inventory for explicit diagnostics; never called by draw. */
 public static function coverage():Array<{instanceId:String,statusId:String,title:String,resolution:String,sourceItemId:String,failed:Bool,locale:String}> {
  return [for (id in rows.keys()) {instanceId:id,statusId:rows.get(id).statusId,title:rows.get(id).title,resolution:rows.get(id).resolution,sourceItemId:rows.get(id).sourceItemId,failed:rows.get(id).failed,locale:rows.get(id).locale}];
 }
}
