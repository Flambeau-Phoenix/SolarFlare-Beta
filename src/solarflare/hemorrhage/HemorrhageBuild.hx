package solarflare.hemorrhage;

class HemorrhageBuild {
	public static macro function stamp():haxe.macro.Expr {
		return macro $v{"hemorrhage-v1 / " + Date.now().toString()};
	}
}
