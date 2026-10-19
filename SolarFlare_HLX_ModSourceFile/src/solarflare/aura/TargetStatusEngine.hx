package solarflare.aura;

import solarflare.aura.signal.StatusSignalSnap;

/** Typed engine reads after runtime receiver checks; never used by rendering. */
class TargetStatusEngine implements TargetStatusSource {
 var foeType:hl.Type;
 var statusType:hl.Type;
 public function new() {}
 static function namedType(value:Dynamic,name:String):hl.Type {
  var type=hl.Type.getDynamic(value);
  for(_ in 0...16) {
   if(type==null || type.kind!=hl.Type.TypeKind.HObj) return null;
   if(type.getTypeName()==name) return type;
   type=type.getSuper();
  }
  return null;
 }
 public function isEnemy(target:Dynamic):Bool {
  if(target==null) return false;
  if(foeType==null) foeType=namedType(target,"ent.Foe");
  return target!=null && foeType!=null && hl.Type.getDynamic(target).safeCast(foeType);
 }
 public function alive(target:Dynamic):Bool {
  var unit:ent.GameObject=target; return !unit.isDead();
 }
 public function container(target:Dynamic):Dynamic {
  var unit:ent.GameObject=target; return unit.statuses;
 }
 public function length(container:Dynamic):Int return solarflare.FieldWalk.arrayLen(container,-1);
 public function at(container:Dynamic,index:Int):Dynamic return solarflare.FieldWalk.arrayAt(container,index);
 public function read(application:Dynamic,out:StatusSignalSnap):Int {
  if(statusType==null) statusType=namedType(application,"st.skill.Status");
  if(statusType==null || !hl.Type.getDynamic(application).safeCast(statusType)) return -1;
  var status:st.skill.Status=application;
  if(status.removed) return 0;
  out.rawId=solarflare.EngineText.cleanId(status.kind);
  if(out.rawId.length==0) return -1;
  out.ids.push(out.rawId); out.present=true; out.known=true;
  try { out.stacks=status.stacks; out.stacksKnown=out.stacks>=0; } catch(_:Dynamic) { out.stacksKnown=false; }
  var remain=solarflare.SkillRemain.read(status);
  out.durationKnown=remain.valid; out.infinite=remain.infinite;
  out.durationLeft=remain.left; out.durationProgress=remain.progress;
  return 1;
 }
}
