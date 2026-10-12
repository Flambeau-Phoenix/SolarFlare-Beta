package solarflare.castbar;

import haxe.crypto.Sha256;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

/**
 * Cached learned evidence, with staged validation and content-verified replacement backups.
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
	/** Content-hash backups kept per store (main file and abandoned stage together); older ones are pruned. */
	static inline var MAX_BACKUPS = 20;
	/** Bounds one prune pass so a large legacy pile is cleared over several flushes, never in one stall. */
	static inline var MAX_PRUNE_PER_CALL = 200;
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
	function backup(source:String):String {
		var bytes = File.getBytes(source);
		var hash = Sha256.make(bytes).toHex();
		var destination = source + ".sha256-" + hash + ".bak";
		var created = !FileSystem.exists(destination);
		if (created) File.saveBytes(destination, bytes);
		if (Sha256.make(File.getBytes(destination)).toHex() != hash) throw "Cast-time backup verification failed";
		if (created) pruneBackups(Path.withoutDirectory(destination));
		return hash;
	}
	/** Keeps the newest MAX_BACKUPS `<file>[.staged].sha256-*.bak` files; the one just written is never removed. Best effort. */
	function pruneBackups(justWritten:String):Void {
		try {
			var dir = Path.directory(path);
			var stem = Path.withoutDirectory(path) + ".";
			var found:Array<{name:String, time:Float}> = [];
			for (name in FileSystem.readDirectory(dir == "" ? "." : dir)) {
				if (!StringTools.startsWith(name, stem) || !StringTools.endsWith(name, ".bak") || name.indexOf(".sha256-") < 0) continue;
				found.push({name: name, time: FileSystem.stat(dir == "" ? name : dir + "/" + name).mtime.getTime()});
			}
			if (found.length <= MAX_BACKUPS) return;
			found.sort(function(a, b) {
				if (a.name == justWritten) return -1;
				if (b.name == justWritten) return 1;
				if (a.time != b.time) return a.time > b.time ? -1 : 1;
				return a.name > b.name ? -1 : (a.name < b.name ? 1 : 0);
			});
			var removed = 0;
			var i = MAX_BACKUPS;
			while (i < found.length && removed < MAX_PRUNE_PER_CALL) {
				try FileSystem.deleteFile(dir == "" ? found[i].name : dir + "/" + found[i].name) catch (_:Dynamic) {}
				removed++;
				i++;
			}
		} catch (_:Dynamic) {}
	}
}
