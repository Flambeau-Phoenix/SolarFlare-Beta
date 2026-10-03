package solarflare.extrabars;

/** All retained bindings reserve their key. Two owners suffice to explain every duplicate. */
class ExtraBarsAssignmentIndex {
 var owners:Map<Int,Array<{bar:String,index:Int,label:String}>> = new Map();
 public function new() {}
 public function rebuild(model:ExtraBarsConfig):Void {
  owners.clear();
  for (bar in model.bars) for(i in 0...10) {
   var key=bar.slots[i].keyCode; if(key<=0) continue;
   var list=owners.get(key); if(list==null) { list=[]; owners.set(key,list); }
   if(list.length<2) list.push({bar:bar.id,index:i,label:bar.name+", cell "+(i+1)});
  }
 }
 public function conflict(bar:String,index:Int,key:Int):String {
  var list=owners.get(key); if(list!=null) for(owner in list)
   if(owner.bar!=bar || owner.index!=index) return "Already assigned to "+owner.label+".";
  return "";
 }
}
