package solarflare.aura;

/** Fresh factories only, before editing. Never call during save/load/copy. */
class AuraPresentationDefaults {
 public static function fresh(a:AuraDef):AuraDef {
  if (a==null) return null;
  a.region="icon"; a.visual.set(true); a.showIcon.set(true);
  a.showLabel.set(false); a.progressRing.set(false); a.showFuse.set(false); a.fuseBottom.set(false);
  a.stackCounter.set(false); a.isCounter.set(false); a.showCountdown.set(false); a.useGlobalCountdown.set(false);
  a.showBanner.set(false); a.timerBoard.set(false); a.canvasElements=[]; a.iconGlow=false;
  var hasWindow=false;
  var primary=a.effects!=null && a.effects.length>0 ? a.effects[0] : null;
  if (a.effects==null) a.effects=[];
  for (e in a.effects) {
   if (e==null) continue;
   e.glow.set(false);
   if (e.kind==AuraEffect.KIND_WINDOW) hasWindow=true;
   if (e.kind==AuraEffect.KIND_ICON || e.kind==AuraEffect.KIND_ALERT) e.enabled.set(false);
  }
  if (!hasWindow) {
   var e=new AuraEffect("fresh_window",AuraEffect.KIND_WINDOW,primary!=null ? primary.when : AuraEffect.WHEN_WHILE_TRUE);
   if (primary!=null) { e.hold=primary.hold; e.holdRef.set(e.hold); }
   a.effects.push(e);
  }
  return a;
 }
}
