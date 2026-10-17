package solarflare.castbar;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

/**
 * Cached learned evidence, with staged validation. No backup copies are written.
 *
 * v4.1b: the release runs this with persist=false (session-only). The on-disk cache never loaded across
 * restarts in practice (the final rename failed), so it is deleted from users' installs in bounded steps
 * and nothing is written. Learning stays in memory for the session. REMOVE this class, CastTimeBook
 * persistence and the seed `assets/cdb/skill-cast-times.json` in v4.2b.
 */
class CastTimeStore {
	public var book(default, null):CastTimeBook;
	public var lastError(default, null):String = "";
	public var compatible(default, null):Bool = false;
	public var canLearn(default, null):Bool = false;
	public var loadedEvidence(default, null):String = null;
	/** Bounds one legacy-cache purge pass so a large pile is cleared over several ticks, never in one stall. */
	static inline var MAX_PURGE_PER_CALL = 100;
	var path:String;
	var lastAttempt:Float = Math.NEGATIVE_INFINITY;
	var enabled:Bool;
	var persist:Bool;
	var purgeDone:Bool = false;
	var lastPurge:Float = Math.NEGATIVE_INFINITY;
	/** persist=false: session-only learning; the on-disk cache family is deleted and never written. */
	public function new(path:String, fingerprint:String, persist:Bool = true) {
		this.path = path;
		this.persist = persist;
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
		if (!persist) {
			purgeLegacyCache(now);
			return false;
		}
		if (!enabled || !book.dirty || (!shutdown && now - lastAttempt < 5)) return false;
		lastAttempt = now;
		try {
			var parent = Path.directory(path);
			if (!FileSystem.exists(parent)) FileSystem.createDirectory(parent);
			var staged = path + ".staged";
			var json = book.toJson();
			File.saveContent(staged, json);
			if (File.getContent(staged) != json || CastTimeBook.fromJson(File.getContent(staged)).sourceFingerprint != book.sourceFingerprint)
				throw "Staged cast-time validation failed";
			// Native rename replaces atomically; failure leaves the existing destination intact.
			FileSystem.rename(staged, path);
			book.markSaved(); compatible = true; loadedEvidence = json; lastError = "";
			return true;
		} catch (e:Dynamic) { lastError = Std.string(e); return false; }
	}
	/** Deletes `<file>`, `<file>.staged` and their `.sha256-*.bak` backups; at most MAX_PURGE_PER_CALL per call, every 5 s. */
	function purgeLegacyCache(now:Float):Void {
		if (purgeDone || now - lastPurge < 5) return;
		lastPurge = now;
		try {
			var dir = Path.directory(path);
			var scan = dir == "" ? "." : dir;
			if (!FileSystem.exists(scan)) {
				purgeDone = true;
				return;
			}
			var stem = Path.withoutDirectory(path);
			var removed = 0;
			var more = false;
			for (name in FileSystem.readDirectory(scan)) {
				if (!isCacheFamily(name, stem)) continue;
				if (removed >= MAX_PURGE_PER_CALL) {
					more = true;
					break;
				}
				try FileSystem.deleteFile(dir == "" ? name : dir + "/" + name) catch (_:Dynamic) {}
				removed++;
			}
			if (!more) purgeDone = true;
		} catch (_:Dynamic) { purgeDone = true; }
	}
	static function isCacheFamily(name:String, stem:String):Bool {
		if (name == stem || name == stem + ".staged") return true;
		return StringTools.startsWith(name, stem + ".") && StringTools.endsWith(name, ".bak") && name.indexOf(".sha256-") > 0;
	}
}
