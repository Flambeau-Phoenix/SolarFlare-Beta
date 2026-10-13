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
 static var requestedAt:Float=-1;
 static var attempted:Bool=false;
 public static var refreshes(default,null):Int=0;
 public static function syncOwner(generation:Int):Void {
  if (ownerGeneration == generation) return;
  clear(); ownerGeneration=generation;
 }
 public static function clear():Void { rows.clear(); indices.clear(); present.clear(); gone.resize(0); size=indexCount=0; wanted=""; attempted=false; requestedAt=-1; refreshes=0; }
 public static function beginPass():Void attempted=false;
 public static function request(instanceId:String,now:Float):Void {
  if (instanceId == null || instanceId.length == 0) return;
  wanted=instanceId; requestedAt=now;
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
  var text=StatusBoardNativeText.read(item,hero);
  if (text == null) { row.markup=""; row.runs.resize(0); row.positioned.resize(0); row.bodyHeight=0; row.layoutSize=-1; return; }
  if (row.title != text.title) row.layoutSize=-1;
  row.title=text.title; row.caption=text.caption;
  if (row.markup != text.description) { row.markup=text.description; row.runs=StatusBoardText.parse(text.description); row.layoutSize=-1; row.revision++; }
 }
}
