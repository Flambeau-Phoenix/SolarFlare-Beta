package solarflare.debug;

/** Bounded, recoverable rotation for opt-in diagnostic JSONL/text logs. */
class LogRotation {
	public static inline var MAX_BYTES:Int = 5 * 1024 * 1024;
	public static inline var RETAIN:Int = 3;

	public static function enforce(path:String):Void {
		if (path == null || path.length == 0)
			return;
		try {
			if (!sys.FileSystem.exists(path) || sys.FileSystem.isDirectory(path)
					|| sys.FileSystem.stat(path).size <= MAX_BYTES)
				return;
			var oldest = path + "." + RETAIN;
			if (sys.FileSystem.exists(oldest) && !sys.FileSystem.isDirectory(oldest))
				sys.FileSystem.deleteFile(oldest);
			var i = RETAIN - 1;
			while (i >= 1) {
				var src = path + "." + i;
				var dst = path + "." + (i + 1);
				if (sys.FileSystem.exists(src) && !sys.FileSystem.isDirectory(src))
					sys.FileSystem.rename(src, dst);
				i--;
			}
			sys.FileSystem.rename(path, path + ".1");
		} catch (_:Dynamic) {}
	}
}
