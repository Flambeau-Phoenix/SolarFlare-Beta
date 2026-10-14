package solarflare.statusboard;

/** One primitive alias index per published snapshot revision, shared by every BarTer cell. */
class StatusBoardApplicationIndex {
 var revision:Int=-1;
 var owner:Int=-1;
 var applications:Map<String,String>=new Map();
 public function new() {}
 public function sync(snaps:Array<solarflare.aura.AuraStatusSnap>,count:Int,nextRevision:Int,nextOwner:Int):Void {
  if (revision==nextRevision && owner==nextOwner) return;
  revision=nextRevision; owner=nextOwner; applications.clear();
  for (i in 0...count) {
   var s=snaps[i]; if (!s.known || !s.present || s.instanceId.length==0) continue;
   add(s.id.toLowerCase(),s.instanceId);
   for (id in s.idsLower) add(id,s.instanceId);
  }
 }
 function add(id:String,application:String):Void {
  var old=applications.get(id);
  if (old==null) applications.set(id,application);
  else if (old!=application) applications.set(id,"");
 }
 public function unique(id:String,complete:Bool):String {
  if (!complete) return "";
  var found=applications.get(id.toLowerCase()); return found==null ? "" : found;
 }
}
