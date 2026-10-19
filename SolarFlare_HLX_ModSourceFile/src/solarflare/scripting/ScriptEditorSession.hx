package solarflare.scripting;

import solarflare.aura.signal.AuraSignalFrame;
import solarflare.aura.signal.AuraConditionDef;

/** Drawing publishes requests. Observation owns parsing, dependencies and testing. */
class ScriptEditorSession {
	static var sessions:Array<ScriptEditorSession>=[];
	public var code(default,null):String="";
	public var state(default,null):String="Unchecked";
	public var message(default,null):String="";
	public var dependencies(default,null):Array<AuraConditionDef>=[];
	var dirty=false; var test=true; var changed:Float=0;
	var touched:Float=0;
	public function new() {}
	public function request(source:String,now:Float,immediate:Bool=false,run:Bool=true):Void {
		code=source; changed=immediate ? -1 : now; dirty=true; test=run; state="Checking..."; message="";
		touch(haxe.Timer.stamp());
	}
	public function touch(now:Float):Void {
		touched=now;
		if(sessions.indexOf(this)<0) { sessions.push(this); dirty=true; }
	}
	public static function appendCodes(out:Array<String>):Void {
		for(s in sessions) if(out.indexOf(s.code)<0) out.push(s.code);
	}
	public static function observe(frame:AuraSignalFrame,now:Float):Void {
		var i=0;
		while(i<sessions.length) {
			var s=sessions[i];
			if(now-s.touched>0.75) { sessions.splice(i,1); solarflare.ObserveDemand.statusDemandDirty=true; continue; }
			s.observeOne(frame,now); i++;
		}
	}
	function observeOne(frame:AuraSignalFrame,now:Float):Void {
		if(changed>=0 && now-changed<0.25) return;
		if(!dirty) {
			if(test && ScriptEngine.prepare(code).error=="") {
				var r=ScriptEngine.evaluate(code,frame); state=r.state; message=r.message;
			}
			return;
		}
		dirty=false;
		var p=ScriptEngine.prepare(code); dependencies=p.dependencies;
		solarflare.ObserveDemand.statusDemandDirty=true;
		if(p.error!="") { state="Error"; message=p.error; return; }
		if(!test) { state="Valid"; message="Expression checked. Test evaluates the latest frozen snapshot."; return; }
		var r=ScriptEngine.evaluate(code,frame); state=r.state; message=r.message;
	}
	public static function clear():Void sessions.resize(0);
}
