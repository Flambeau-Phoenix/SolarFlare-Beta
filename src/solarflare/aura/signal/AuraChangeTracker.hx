package solarflare.aura.signal;

/** Pure observation transitions. A gap establishes a new baseline, never an edge. */
class AuraChangeTracker {
	public static inline var GAP:Float = 0.5;
	public static inline var REFRESH_TOLERANCE:Float = 0.15;
	var generation:Int = -1;
	var owner:Int = -1;
	var last:Float = -1;
	var skills:Map<String, ChangeBaseline> = [];
	var statuses:Map<String, ChangeBaseline> = [];
	var dash:ChangeBaseline = new ChangeBaseline();
	var dashId:String = "";
	var dashGeneration:Int=-1;
	public function new() {}
	public function reset():Void {
		skills.clear(); statuses.clear(); dash = new ChangeBaseline(); dashId = ""; last = -1;
	}
	public function observe(f:AuraSignalFrame, now:Float, identity:Int, character:Int, statusIds:Array<String>,skillIds:Array<String>=null):Void {
		if (identity != generation || character != owner || !f.heroKnown || last < 0 || now < last || now-last > GAP) {
			reset(); generation = identity; owner = character;
		}
		last = now;
		f.events.clear();
		var seen:Map<String,Bool> = [];
		for (i in 0...f.skillCount) {
			var s=f.skills[i]; var key=keyOf(s.rawId); seen.set(key,true);
			if(skillIds!=null) {
				var wanted=false; for(id in skillIds) if(keyOf(id)==key || keyOf(id)==keyOf(s.aliasId)) { wanted=true; break; }
				if(!wanted) { seen.remove(key); continue; }
			}
			var b=skills.get(key); if(b==null) { b=new ChangeBaseline(); skills.set(key,b); }
			var valid=f.heroKnown && s.known && (s.chargesMax>0 || s.cooldownKnown);
			var count=s.chargesMax>0 ? s.charges : (s.ready ? 1 : 0);
			b.count(valid,count,now);
			publish(f,"event.skill.chargeGained",key,b,0,valid,now);
			publish(f,"event.skill.chargeSpent",key,b,1,valid,now);
		}
		for(key in skills.keys()) if(!seen.exists(key)) skills.remove(key);
		var seedDash=dashId!=f.dashId || dashGeneration!=f.dashGeneration || !dash.isSeeded;
		if(dashId!=f.dashId || dashGeneration!=f.dashGeneration) { dash=new ChangeBaseline(); dashId=f.dashId; dashGeneration=f.dashGeneration; }
		var dashKnown=f.heroKnown && f.dashKnown;
		dash.count(dashKnown,f.dashCharges,now);
		publish(f,"event.dash.gained","",dash,0,dashKnown,now);
		if(dashKnown) for(i in 0...f.playerCastCount) {
			var c=f.playerCasts[i];
			if(keyOf(c.skillId)==keyOf(f.dashId) && c.known && c.serial>dash.castSerial) {
				// Historical cast records from before this dash baseline are not new uses.
				if(!seedDash && now-c.age>=dash.seededAt) { dash.at[2]=now-c.age; dash.serials[2]=c.serial; }
				dash.castSerial=c.serial;
			}
		}
		publish(f,"event.dash.used","",dash,2,dashKnown,now);
		seen.clear();
		for(id in statusIds) {
			var key=keyOf(id); if(seen.exists(key)) continue; seen.set(key,true);
			var b=statuses.get(key); if(b==null) { b=new ChangeBaseline(); statuses.set(key,b); }
			var s=f.findStatus(id);
			var valid=f.heroKnown && (s==null ? f.statusDomainKnown : s.known);
			var present=s!=null && s.present;
			var timed=present && s.durationKnown && s.durationNative && !s.infinite && Math.isFinite(s.durationLeft);
			var stackKnown=!present || s.stacksKnown;
			b.status(valid,present,stackKnown,present ? s.stacks : 0,timed,timed ? s.durationLeft : 0,
				present ? s.instanceId : "",now);
			publish(f,"event.status.gained",key,b,0,valid,now);
			publish(f,"event.status.lost",key,b,1,valid,now);
			publish(f,"event.status.refreshed",key,b,2,valid && (!present || timed),now);
			publish(f,"event.status.stacksGained",key,b,3,valid && stackKnown,now);
			publish(f,"event.status.stacksLost",key,b,4,valid && stackKnown,now);
		}
		for(key in statuses.keys()) if(!seen.exists(key)) statuses.remove(key);
	}
	static function publish(f:AuraSignalFrame,signal:String,subject:String,b:ChangeBaseline,index:Int,known:Bool,now:Float):Void {
		var v=b.values[index]; v.known=known; v.age=b.at[index]<0 ? 1e9 : Math.max(0,now-b.at[index]); v.serial=b.serials[index];
		f.events.set(eventKey(signal,subject),v);
	}
	public static function keyOf(id:String):String return id==null ? "" : StringTools.trim(id).toLowerCase();
	public static function eventKey(signal:String,subject:String):String return signal+"\n"+keyOf(subject);
}

private class ChangeBaseline {
	public var values:Array<AuraEventValue> = [];
	public var at:Array<Float> = [-1,-1,-1,-1,-1];
	public var serials:Array<Int> = [0,0,0,0,0];
	public var castSerial:Int=0;
	public var seededAt:Float=0;
	var seeded=false; var n=0; var present=false; var timed=false; var left:Float=0; var instance="";
	public var isSeeded(get,never):Bool;
	function get_isSeeded():Bool return seeded;
	var stacksKnown=false; var last:Float=-1;
	public function new() { for(_ in 0...5) values.push(new AuraEventValue()); }
	function fire(index:Int,now:Float):Void { at[index]=now; serials[index]=AuraEventSequence.next(); }
	function invalidate():Void { seeded=false; stacksKnown=false; for(i in 0...5) { at[i]=-1; serials[i]=0; } }
	public function count(known:Bool,value:Int,now:Float):Void {
		if(!known) { invalidate(); return; }
		if(seeded) { if(value>n) fire(0,now); else if(value<n) fire(1,now); }
		else seededAt=now;
		n=value; seeded=true;
	}
	public function status(known:Bool,p:Bool,sk:Bool,value:Int,t:Bool,l:Float,id:String,now:Float):Void {
		if(!known) { invalidate(); return; }
		if(seeded) {
			if(p && !present) fire(0,now);
			if(!p && present) fire(1,now);
			if(p && present && t && timed && ((id!="" && instance!="" && id!=instance)
				|| l>Math.max(0,left-(now-last))+AuraChangeTracker.REFRESH_TOLERANCE)) fire(2,now);
			if(sk && stacksKnown) { if(value>n) fire(3,now); else if(value<n) fire(4,now); }
		}
		else seededAt=now;
		seeded=true; present=p; n=value; stacksKnown=sk; timed=t; left=l; instance=id; last=now;
	}
}
