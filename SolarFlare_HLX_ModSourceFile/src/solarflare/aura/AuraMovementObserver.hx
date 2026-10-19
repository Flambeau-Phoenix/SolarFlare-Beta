package solarflare.aura;

import solarflare.aura.signal.AuraSignalFrame;

/** Observation only; no engine references enter a rule or editor. */
class AuraMovementObserver {
	static var dashRef:Dynamic;
	static var dashGeneration=0;
	public static function reset():Void { if(dashRef!=null) dashGeneration++; dashRef=null; }
	public static function sample(f:AuraSignalFrame):Void {
		f.dashKnown=false; f.dashId=""; f.dashCharges=f.dashMax=0; f.dashRecharge=Math.NaN;
		#if hl
		if(!solarflare.ObserveDemand.aurasNeedDash) { reset(); return; }
		var hero=solarflare.HealthCache.localHero;
		if(hero==null || !solarflare.HealthCache.isHeroObject(hero)) { reset(); return; }
		try {
			var h:ent.Hero=hero; var s=h.dashSkill;
			if(dashRef!=s) { dashRef=s; dashGeneration++; }
			if(s==null) return;
			f.dashId=solarflare.EngineSkillId.ofSkill(s); f.dashGeneration=dashGeneration;
			var max=s.getMaxCharges(); var n=s.getCurrentCharges(); var cd=s.getCooldownLeft();
			if(max<=0 || n<0 || !Math.isFinite(cd)) return;
			f.dashMax=max; f.dashCharges=Std.int(Math.min(max,n)); f.dashRecharge=n>=max ? 0 : Math.max(0,cd); f.dashKnown=true;
		} catch(_:Dynamic) {}
		#end
	}
}
