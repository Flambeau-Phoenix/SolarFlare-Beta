package solarflare.aura;

import solarflare.aura.signal.AuraSignalFrame;

/** Observation only; no engine references enter a rule or editor. */
class AuraMovementObserver {
	static var dashRef:Dynamic;
	static var dashGeneration=0;
	static var heroRef:Dynamic;
	static var ownerGeneration:Int=-1;
	static var nextSample:Float=0;
	public static var state(default,null)=new solarflare.resourcetracker.DashState();
	public static var cooldown(default,null)=new solarflare.aura.signal.SkillSignalSnap();
	public static function reset():Void { if(dashRef!=null) dashGeneration++; dashRef=null; heroRef=null; state.clear(); cooldown.reset(); nextSample=0; }
	public static function observe(now:Float,wanted:Bool):Void {
		#if hl
		if(!wanted) { reset(); return; }
		var hero=solarflare.HealthCache.localHero;
		if(hero==null || !solarflare.HealthCache.isHeroObject(hero)) { reset(); return; }
		if(heroRef!=hero || ownerGeneration!=solarflare.HealthCache.statusOwnerGen) { reset(); heroRef=hero; ownerGeneration=solarflare.HealthCache.statusOwnerGen; }
		if(now<nextSample) return;
		nextSample=now+0.05; state.clear(); cooldown.reset();
		try {
			var h:ent.Hero=hero; var s=h.dashSkill;
			if(dashRef!=s) { dashRef=s; dashGeneration++; }
			if(s==null) return;
			var id=solarflare.EngineSkillId.ofSkill(s);
			var max=s.getMaxCharges(); var n=s.getCurrentCharges(); var cd=s.getCooldownLeft();
			state.update(id,n,max,cd,s.getCooldown());
			cooldown.rawId=id; cooldown.known=cooldown.cooldownKnown=state.known;
			cooldown.charges=state.charges; cooldown.chargesMax=state.max; cooldown.ready=state.charges>0;
			cooldown.inCooldown=state.known && state.left>0; cooldown.cooldownLeft=state.left;
			cooldown.cooldownTotal=state.total; cooldown.cooldownProgress=state.remaining;
		} catch(_:Dynamic) {}
		#end
	}
	public static function sample(f:AuraSignalFrame):Void {
		f.dashKnown=state.known; f.dashId=state.id; f.dashGeneration=dashGeneration;
		f.dashCharges=state.charges; f.dashMax=state.max; f.dashRecharge=state.left;
		f.dashRechargeTotal=state.total; f.dashRechargeProgress=state.remaining;
	}
}
