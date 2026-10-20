package solarflare.ui;

/** Identity-state edge log (state changes only, capped): explains a suspended profile strip after the fact. */
class IdentityLog {
	static var last:String = null;
	static var count:Int = 0;

	public static function note(state:String):Void {
		if (state == last || count >= 200) return;
		last = state;
		ProfileTrace.note("identity", state);
		count++;
		try {
			var dir = SettingsStore.logsDir();
			if (dir == null) return;
			var f = sys.io.File.append(haxe.io.Path.join([dir, "identity.log"]), false);
			f.writeString(Date.now().toString() + " " + state + "
");
			f.close();
		} catch (_:Dynamic) {}
	}
}
