package solarflare.util;

/** Rebuild only on identity/order/key changes; dynamic visibility stays with the caller. */
class MembershipIndex<T> {
 var source:Array<T>=[];
 var keys:Array<String>=[];
 var rows:Map<String,Array<T>>=new Map();
 public var generation(default,null)=0;
 public function new() {}
 public function refresh(items:Array<T>,keyOf:T->String):Bool {
  var changed=source.length!=items.length;
  if(!changed) for(i in 0...items.length) if(source[i]!=items[i] || keys[i]!=keyOf(items[i])) { changed=true; break; }
  if(!changed) return false;
  source.resize(0); keys.resize(0); rows.clear();
  for(item in items) {
   var key=keyOf(item); source.push(item); keys.push(key);
   if(item==null || key==null || key=="") continue;
   var members=rows.get(key);
   if(members==null) { members=[]; rows.set(key,members); }
   members.push(item);
  }
  generation++; return true;
 }
 public function get(key:String):Array<T> return rows.get(key);
}
