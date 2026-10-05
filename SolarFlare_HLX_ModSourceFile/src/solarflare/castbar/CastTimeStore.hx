package solarflare.castbar;

import haxe.crypto.Sha256;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

/** Cached learned evidence, with staged validation and content-verified replacement backups. */
class CastTimeStore {
	public var book(default, null):CastTimeBook;
	public var lastError(default, null):String = "";
	public var compatible(default, null):Bool = false;
	public var canLearn(default, null):Bool = false;
	public var loadedEvidence(default, null):String = null;
	var path:String;
	var lastAttempt:Float = Math.NEGATIVE_INFINITY;
	var enabled:Bool;
	public function new(path:String, fingerprint:String) {
		this.path = path;
		enabled = fingerprint != null && ~/^[0-9a-f]{64}$/.match(fingerprint);
		canLearn = enabled;
		book = new CastTimeBook(fingerprint);
		try {
			if (FileSystem.exists(path)) {
				loadedEvidence = File.getContent(path);
				var loaded = CastTimeBook.fromJson(loadedEvidence);
				compatible = enabled && loaded.sourceFingerprint == fingerprint;
				if (compatible) book = loaded;
			} else compatible = enabled;
		} catch (e:Dynamic) { lastError = Std.string(e); }
	}
	/** Called by observe/background and logout, never by a draw function. */
	public function flush(now:Float, shutdown:Bool = false):Bool {
		if (!enabled || !book.dirty || (!shutdown && now - lastAttempt < 5)) return false;
		lastAttempt = now;
		try {
			var parent = Path.directory(path);
			if (!FileSystem.exists(parent)) FileSystem.createDirectory(parent);
			var staged = path + ".staged";
			var json = book.toJson();
			// Preserve an abandoned stage as well; every replacement keeps complete content.
			if (FileSystem.exists(staged)) backup(staged);
			File.saveContent(staged, json);
			if (File.getContent(staged) != json || CastTimeBook.fromJson(File.getContent(staged)).sourceFingerprint != book.sourceFingerprint)
				throw "Staged cast-time validation failed";
			var originalHash:String = null;
			if (FileSystem.exists(path)) originalHash = backup(path);
			if (originalHash != null && Sha256.make(File.getBytes(path)).toHex() != originalHash) throw "Cast-time file changed during replacement";
			// Native rename replaces atomically; failure leaves the existing destination intact.
			FileSystem.rename(staged, path);
			book.markSaved(); compatible = true; loadedEvidence = json; lastError = "";
			return true;
		} catch (e:Dynamic) { lastError = Std.string(e); return false; }
	}
	static function backup(source:String):String {
		var bytes = File.getBytes(source);
		var hash = Sha256.make(bytes).toHex();
		var destination = source + ".sha256-" + hash + ".bak";
		if (!FileSystem.exists(destination)) File.saveBytes(destination, bytes);
		if (Sha256.make(File.getBytes(destination)).toHex() != hash) throw "Cast-time backup verification failed";
		return hash;
	}
}
