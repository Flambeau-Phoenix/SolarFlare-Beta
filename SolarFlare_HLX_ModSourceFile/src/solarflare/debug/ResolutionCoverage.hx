package solarflare.debug;

import sys.io.File;
import solarflare.debug.ResolutionLedger.LedgerAgg;

/**
 * Automatic route map / coverage checklist.
 *
 * Joins the static `ResolutionCatalog` (what the HUD needs) against the live
 * `ResolutionLedger` aggregates (what actually resolved at runtime) and emits a
 * tracked checklist: per key, whether the observation fired, which route won,
 * which routes were tried and missed, and what paid off. Written on Stop Recording.
 */
@:keep
class ResolutionCoverage {
	public static function writeReport():Void {
		var mdPath:String = "";
		var jsonPath:String = "";
		try {
			mdPath = solarflare.ui.SettingsStore.logFile("resolution-coverage.md");
			jsonPath = solarflare.ui.SettingsStore.logFile("resolution-coverage.json");
		} catch (_:Dynamic) {
			return;
		}
		var keys = buildKeys();
		var observed = 0;
		for (k in keys)
			if (k.observed)
				observed++;
		var uncat = uncataloged(keys);
		var summary = {
			type: "resolution-coverage",
			v: 1,
			at: Date.now().toString(),
			catalog: keys.length,
			observed: observed,
			missing: keys.length - observed,
			keys: keys,
			uncataloged: uncat
		};
		try
			File.saveContent(jsonPath, haxe.Json.stringify(summary))
		catch (_:Dynamic) {}
		try
			File.saveContent(mdPath, toMarkdown(summary))
		catch (_:Dynamic) {}
	}

	static function buildKeys():Array<CovKey> {
		var byKey:Map<String, Array<LedgerAgg>> = new Map();
		for (a in ResolutionLedger.rowsForDraw()) {
			if (a == null)
				continue;
			var arr = byKey.get(a.key);
			if (arr == null) {
				arr = [];
				byKey.set(a.key, arr);
			}
			arr.push(a);
		}
		var out:Array<CovKey> = [];
		var defs = ResolutionCatalog.all();
		var i = 0;
		while (i < defs.length) {
			var d = defs[i];
			i++;
			var list = byKey.get(d.key);
			var k:CovKey = {
				key: d.key,
				feature: d.feature,
				element: d.element,
				importance: d.importance,
				reason: d.reason,
				observed: list != null && list.length > 0,
				hits: 0,
				routes: [],
				misses: [],
				winner: "",
				src: "",
				hook: "",
				preview: "",
				kind: ""
			};
			out.push(k);
			if (list == null)
				continue;
			var missSeen:Map<String, Bool> = new Map();
			for (a in list) {
				k.hits += a.hits;
				var route = a.method + ":" + a.nameWon;
				k.routes.push({
					route: route,
					hits: a.hits,
					src: a.src,
					hook: a.hook,
					step: a.step,
					preview: a.preview,
					kind: a.kind
				});
				if (k.winner.length == 0)
					k.winner = route;
				if (a.src != null && a.src.length > 0)
					k.src = a.src;
				if (a.hook != null && a.hook.length > 0)
					k.hook = a.hook;
				if (a.preview != null && a.preview.length > 0)
					k.preview = a.preview;
				if (a.kind != null && a.kind.length > 0)
					k.kind = a.kind;
				var t = 0;
				while (t < a.tried.length) {
					var tr:Dynamic = a.tried[t];
					t++;
					var m = fld(tr, "method");
					var nm = fld(tr, "name");
					if (nm.length == 0 || nm == a.nameWon)
						continue;
					var token = m + ":" + nm;
					if (!missSeen.exists(token)) {
						missSeen.set(token, true);
						k.misses.push(token);
					}
				}
			}
		}
		return out;
	}

	static function uncataloged(keys:Array<CovKey>):Array<Dynamic> {
		var known:Map<String, Bool> = new Map();
		for (k in keys)
			known.set(k.key, true);
		var out:Array<Dynamic> = [];
		for (a in ResolutionLedger.rowsForDraw()) {
			if (a == null || known.exists(a.key))
				continue;
			out.push({key: a.key, hits: a.hits, winner: a.method + ":" + a.nameWon, src: a.src});
		}
		return out;
	}

	static function fld(o:Dynamic, name:String):String {
		if (o == null)
			return "";
		try {
			var v:Dynamic = Reflect.field(o, name);
			return v == null ? "" : Std.string(v);
		} catch (_:Dynamic) {
			return "";
		}
	}

	static function toMarkdown(s:Dynamic):String {
		var sb = new StringBuf();
		sb.add("# Resolution Coverage\n\n");
		sb.add("- generated: " + s.at + "\n");
		sb.add("- catalog keys: " + s.catalog + "\n");
		sb.add("- observed: " + s.observed + "\n");
		sb.add("- never observed: " + s.missing + "\n\n");
		sb.add("| Key | P | Observed | Hits | Winning route | Src | Hook | Preview | Tried+missed |\n");
		sb.add("|---|---|---|---|---|---|---|---|---|\n");
		var ks:Array<CovKey> = cast s.keys;
		for (k in ks) {
			sb.add("| " + k.key + " | " + k.importance + " | " + (k.observed ? "yes" : "NO") + " | " + k.hits
				+ " | " + k.winner + " | " + k.src + " | " + k.hook + " | " + k.preview
				+ " | " + k.misses.join(", ") + " |\n");
		}
		var un:Array<Dynamic> = cast s.uncataloged;
		if (un.length > 0) {
			sb.add("\n## Uncataloged (fired but not in catalog)\n\n");
			sb.add("| Key | Hits | Winner | Src |\n|---|---|---|---|\n");
			for (u in un)
				sb.add("| " + u.key + " | " + u.hits + " | " + u.winner + " | " + u.src + " |\n");
		}
		return sb.toString();
	}
}

typedef CovRoute = {
	var route:String;
	var hits:Int;
	var src:String;
	var hook:String;
	var step:String;
	var preview:String;
	var kind:String;
}

typedef CovKey = {
	var key:String;
	var feature:String;
	var element:String;
	var importance:String;
	var reason:String;
	var observed:Bool;
	var hits:Int;
	var routes:Array<CovRoute>;
	var misses:Array<String>;
	var winner:String;
	var src:String;
	var hook:String;
	var preview:String;
	var kind:String;
}
