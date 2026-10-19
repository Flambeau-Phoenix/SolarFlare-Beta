package solarflare.aura.signal;

/** Scheduler-owned primitive subscriber to the existing damage hooks. */
class AuraCombatEvents {
	static var identity=-1; static var owner=-1;
	static var at:Array<Float>=[-1,-1,-1];
	static var serials:Array<Int>=[0,0,0];
	static var lastPublish:Float=-1;
	public static function bind(id:Int,character:Int):Void {
		if(id==identity && character==owner) return;
		identity=id; owner=character;
		lastPublish=-1;
		for(i in 0...3) { at[i]=-1; serials[i]=0; }
	}
	public static function note(now:Float,damage:Bool,crit:Bool,block:Bool):Void {
		if(!Math.isFinite(now)) return;
		if(damage) fire(0,now); if(crit) fire(1,now); if(block) fire(2,now);
	}
	static function fire(i:Int,now:Float):Void { at[i]=now; serials[i]=AuraEventSequence.next(); }
	public static function publish(f:AuraSignalFrame,now:Float):Void {
		if(!f.heroKnown || (lastPublish>=0 && (now<lastPublish || now-lastPublish>AuraChangeTracker.GAP)))
			for(i in 0...3) if(!f.heroKnown || at[i]<now-AuraChangeTracker.GAP) { at[i]=-1; serials[i]=0; }
		lastPublish=now;
		f.damageTakenAge=age(0,now); f.critAge=age(1,now); f.blockAge=age(2,now);
		f.damageAgeKnown=f.heroKnown && at[0]>=0;
		f.critSerial=serials[1]; f.blockSerial=serials[2];
	}
	static function age(i:Int,now:Float):Float return at[i]<0 ? 1e9 : Math.max(0,now-at[i]);
}
