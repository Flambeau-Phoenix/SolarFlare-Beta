package solarflare.ui;

/**
 * Append-only diagnostic trace for the profile / UI-layout / identity system: logs/profile-trace.log.
 * Events only (loads, ownership transitions, layout applies, saves, dropped actions); capped, never polled.
 */
class ProfileTrace {
	static inline var MAX:Int = 4000;
	static var count:Int = 0;
	static var started:Bool = false;

	public static function note(tag:String, msg:String):Void {
		if (count >= MAX) return;
		count++;
		try {
			var mod = ModPaths.modDir();
			if (mod == null) return;
			var dir = haxe.io.Path.join([mod, "logs"]);
			if (!sys.FileSystem.exists(dir)) sys.FileSystem.createDirectory(dir);
			var f = sys.io.File.append(haxe.io.Path.join([dir, "profile-trace.log"]), false);
			if (!started) {
				started = true;
				f.writeString("---- session " + Date.now().toString() + " ----\n");
			}
			f.writeString(Date.now().toString().substr(11) + " [" + tag + "] " + msg + "\n");
			f.close();
		} catch (_:Dynamic) {}
	}
}
