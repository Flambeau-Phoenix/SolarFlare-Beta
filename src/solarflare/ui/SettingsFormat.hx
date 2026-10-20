package solarflare.ui;

/**
 * One-time settings file format conversion.
 *
 * Format 2 (this build): compact JSON, no `featureProfiles` alias of the profile bank, and migration recovery payloads
 * pruned once migration has finished. A file without `format` is older. On load it is copied byte for byte to a backup that is
 * never overwritten and verified, then the normal save rewrites it in the new shape and stamps `format`. The conversion cannot
 * run twice, and it cannot run without its backup: a backup failure turns saving off for the session.
 *
 * Pure file helpers (no ImGui), so the policy is unit-testable.
 */
class SettingsFormat {
	public static inline var CURRENT:Int = 2;
	static inline var BACKUP_INFIX:String = ".pre-format";

	/** 1 for any file written before `format` existed. */
	public static function formatOf(data:Dynamic):Int {
		if (data == null || !Reflect.isObject(data) || Std.isOfType(data, String) || Std.isOfType(data, Array)) return 1;
		var raw:Dynamic = Reflect.field(data, "format");
		if (!Std.isOfType(raw, Int) && !Std.isOfType(raw, Float)) return 1;
		var n:Float = raw;
		return Math.isFinite(n) && n >= 1 ? Std.int(n) : 1;
	}

	public static function needsConversion(data:Dynamic):Bool return formatOf(data) < CURRENT;

	/**
	 * Byte-exact copy of `source` (which must parse) beside it as `<name>.pre-format<N>-<sha256>.bak`. An existing backup of the
	 * same bytes is kept as is, never rewritten. Throws if the copy cannot be verified.
	 */
	public static function backup(source:String):String {
		if (source == null || !sys.FileSystem.exists(source)) throw "Missing settings file to back up";
		var bytes = sys.io.File.getBytes(source);
		haxe.Json.parse(bytes.toString());
		var digest = haxe.crypto.Sha256.make(bytes).toHex();
		var target = source + BACKUP_INFIX + CURRENT + "-" + digest + ".bak";
		if (!sys.FileSystem.exists(target)) sys.io.File.saveBytes(target, bytes);
		var saved = sys.io.File.getBytes(target);
		if (saved.compare(bytes) != 0) throw "Settings backup verification failed";
		return target;
	}

	/** True when a converted-from backup sits beside the settings file (it covers everything the conversion prunes). */
	public static function backupExists(settingsPath:String):Bool {
		if (settingsPath == null || settingsPath.length == 0) return false;
		try {
			var dir = haxe.io.Path.directory(settingsPath);
			var stem = haxe.io.Path.withoutDirectory(settingsPath) + BACKUP_INFIX;
			for (name in sys.FileSystem.readDirectory(dir == "" ? "." : dir))
				if (StringTools.startsWith(name, stem) && StringTools.endsWith(name, ".bak")) return true;
		} catch (_:Dynamic) {}
		return false;
	}
}
