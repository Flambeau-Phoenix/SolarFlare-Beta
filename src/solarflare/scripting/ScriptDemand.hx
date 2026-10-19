package solarflare.scripting;

import solarflare.aura.signal.AuraConditionDef;

/** Dependency extraction is shared by real configuration and standalone tests. */
class ScriptDemand {
	public static function expand(conditions:Array<AuraConditionDef>,codes:Array<String>):Void {
		var count=conditions.length;
		for(i in 0...count) if(conditions[i].signal=="custom.script" && codes.indexOf(conditions[i].subject)<0) codes.push(conditions[i].subject);
		ScriptEngine.retain(codes);
		for(code in codes) {
			var program=ScriptEngine.prepare(code);
			if(program.error!="") continue;
			for(c in program.dependencies) conditions.push(c);
		}
	}
}
