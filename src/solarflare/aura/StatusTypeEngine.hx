package solarflare.aura;

/** Typed calls only after receiver validation. No instigator filtering or skill-id matching. */
class StatusTypeEngine implements StatusTypeSource {
 static var empty:Array<Dynamic>=[];
 var foes=new TargetStatusEngine();
 var statusType:hl.Type;
 public function new() {}
 public function validOwner(owner:Dynamic,enemy:Bool):Bool {
  if(owner==null || (enemy ? !foes.isEnemy(owner) : !solarflare.HealthCache.isHeroObject(owner))) return false;
  var object:ent.GameObject=owner; return !object.isDead();
 }
 public function container(owner:Dynamic):Dynamic {
  var object:ent.GameObject=owner; var list:Dynamic=object.statuses;
  // The engine's hasStatusType also treats a successfully read null list as empty.
  return list==null ? empty : list;
 }
 public function length(container:Dynamic):Int return container==empty ? 0 : solarflare.FieldWalk.arrayLen(container,-1);
 public function at(container:Dynamic,index:Int):Dynamic return solarflare.FieldWalk.arrayAt(container,index);
 public function state(application:Dynamic):Int {
  if(application==null) return -1;
  if(statusType==null) {
   var type=hl.Type.getDynamic(application);
   for(_ in 0...16) {
    if(type==null || type.kind!=hl.Type.TypeKind.HObj) break;
    if(type.getTypeName()=="st.skill.Status") { statusType=type; break; }
    type=type.getSuper();
   }
  }
  if(statusType==null || !hl.Type.getDynamic(application).safeCast(statusType)) return -1;
  var status:st.skill.Status=application;
  if(status.removed) return 0;
  // isType logs/falls back to false for missing inf; preserve this as unknown instead.
  return status.inf==null ? -1 : 1;
 }
 public function matches(application:Dynamic,typeId:String):Bool {
  var status:st.skill.Status=application; return status.isType(typeId);
 }
}
