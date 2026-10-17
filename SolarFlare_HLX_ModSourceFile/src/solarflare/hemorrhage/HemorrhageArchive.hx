package solarflare.hemorrhage;

import solarflare.hemorrhage.HemorrhageRun.HemorrhageAbility;
import solarflare.hemorrhage.HemorrhageRun.HemorrhageMetrics;

/** Engine/UI-free summary codec, CSV and recoverable file store. */
class HemorrhageArchive {
	public static inline var LIMIT:Int = 50;
	public var runs:Array<HemorrhageRun> = [];
	public var dirty:Bool = false;
	public var error:String = "";
	public var recovered:Bool = false;
	var path:String;
	var blocked:Bool = false;
	static var metricFields = ["damage", "physicalBleed", "sparkBleed", "physicalHits", "physicalCrits", "magicHits", "magicCrits", "criticalDamage", "bleedTicks", "bleedCrits", "unknown", "events"];
	static var runNumbers = ["wallMs", "elapsed", "attackSeconds", "tailSeconds", "chanceStart", "chanceMin", "chanceMax", "ratingStart", "ratingMin", "ratingMax", "dropped"];
	static var runStrings = ["id", "character", "build", "notes", "modBuild", "gameBuild", "reason"];
	public function new(path:String) this.path = path;
	public function count(character:String):Int {
		var n = 0; for (r in runs) if (r.character == character) n++; return n;
	}
	public function add(r:HemorrhageRun):Bool {
		for (saved in runs) if (saved.id == r.id) return true;
		if (count(r.character) >= LIMIT) return false;
		runs.push(r); dirty = true; return true;
	}
	public function remove(id:String):Void {
		for (r in runs) if (r.id == id) { runs.remove(r); dirty = true; return; }
	}
	static function finite(v:Dynamic):Bool return (Std.isOfType(v,Float) || Std.isOfType(v,Int)) && Math.isFinite(v);
	static function metricsData(m:HemorrhageMetrics):Dynamic {
		var d:Dynamic = {}; for (f in metricFields) Reflect.setField(d, f, Reflect.field(m,f)); return d;
	}
	public static function data(r:HemorrhageRun):Dynamic {
		var d:Dynamic = {state: (r.state:String), metrics: metricsData(r.metrics), abilities: []};
		for (f in runStrings) Reflect.setField(d,f,Reflect.field(r,f));
		for (f in runNumbers) { var v:Float = Reflect.field(r,f); Reflect.setField(d,f,Math.isFinite(v) ? v : null); }
		for (a in r.abilities) d.abilities.push({id:a.id,label:a.label,metrics:metricsData(a.metrics)});
		return d;
	}
	static function readMetrics(d:Dynamic):HemorrhageMetrics {
		if (d == null) throw "Missing metrics";
		var m = new HemorrhageMetrics();
		for (f in metricFields) {
			var v:Dynamic = Reflect.field(d,f);
			if (!finite(v) || v < 0 || v > 1e20) throw "Invalid metric " + f;
			if (f == "damage" || f == "physicalBleed" || f == "sparkBleed" || f == "criticalDamage") Reflect.setField(m,f,(v:Float));
			else { if (v > 2147483647 || v != Math.ffloor(v)) throw "Invalid count"; Reflect.setField(m,f,Std.int(v)); }
		}
		if (m.physicalCrits > m.physicalHits || m.magicCrits > m.magicHits || m.bleedCrits > m.bleedTicks
			|| m.bleed() > m.damage + 0.001) throw "Inconsistent metrics";
		return m;
	}
	public static function decode(raw:String):Array<HemorrhageRun> {
		if (raw.length > 32 * 1024 * 1024) throw "Archive too large";
		var root:Dynamic = haxe.Json.parse(raw);
		if (root == null || root.version != 1 || !Std.isOfType(root.runs,Array)) throw "Unsupported Hemorrhage archive";
		var out:Array<HemorrhageRun> = []; var seen = new Map<String,Bool>(); var counts = new Map<String,Int>();
		var rows:Array<Dynamic> = root.runs;
		if (rows.length > 5000) throw "Too many saved runs";
		for (d in rows) {
			var r = new HemorrhageRun();
			if (d.state != "Complete" && d.state != "Interrupted") throw "Invalid saved state";
			r.state = d.state;
			for (f in runStrings) {
				var v:Dynamic = Reflect.field(d,f); if (!Std.isOfType(v,String) || v.length > 4096) throw "Invalid " + f;
				Reflect.setField(r,f,v);
			}
			if (r.id == "" || r.character == "" || seen.exists(r.id)) throw "Invalid run identity";
			seen.set(r.id,true);
			var n = counts.exists(r.character) ? counts.get(r.character) : 0;
			if (n >= LIMIT) throw "Too many runs for character"; counts.set(r.character,n+1);
			for (f in runNumbers) {
				var v:Dynamic = Reflect.field(d,f);
				var stat = StringTools.startsWith(f,"chance") || StringTools.startsWith(f,"rating");
				if (v == null && stat) Reflect.setField(r,f,Math.NaN);
				else {
					if (!finite(v) || v < 0) throw "Invalid " + f;
					if (f == "dropped") { if(v>2147483647 || v!=Math.ffloor(v)) throw "Invalid drop count"; Reflect.setField(r,f,Std.int(v)); }
					else Reflect.setField(r,f,(v:Float));
				}
			}
			r.metrics = readMetrics(d.metrics);
			if (!Std.isOfType(d.abilities,Array) || d.abilities.length > 256) throw "Invalid ability breakdown";
			var abilities:Array<Dynamic> = d.abilities;
			for (a in abilities) {
				if (!Std.isOfType(a.id,String) || !Std.isOfType(a.label,String) || a.id.length > 512 || a.label.length > 1024) throw "Invalid ability";
				var item = new HemorrhageAbility(a.id,a.label); item.metrics = readMetrics(a.metrics); r.abilities.push(item);
			}
			out.push(r);
		}
		return out;
	}
	public function encode():String return haxe.Json.stringify({version:1,runs:[for(r in runs) data(r)]});
	public function load():Void {
		var present = false;
		for (p in [path,path+".tmp"]) {
			if (!sys.FileSystem.exists(p)) continue;
			present = true;
			try {
				runs = decode(sys.io.File.getContent(p)); recovered = p != path;
				if (recovered) error = "Recovered saved tests from " + haxe.io.Path.withoutDirectory(p) + ". Retry save to repair the primary file.";
				return;
			} catch (_:Dynamic) {}
		}
		if (present) { blocked = true; error = "Saved tests are unreadable. Existing files are preserved; saving is blocked."; }
	}
	public function save():Bool {
		if (blocked) return false;
		try {
			var raw = encode(); decode(raw);
			sys.io.File.saveContent(path+".tmp",raw);
			decode(sys.io.File.getContent(path+".tmp"));
			if (sys.FileSystem.exists(path)) {
				sys.FileSystem.deleteFile(path);
			}
			sys.FileSystem.rename(path+".tmp",path);
			dirty = recovered = false; error = ""; return true;
		} catch(e:Dynamic) { error = "Save failed: " + Std.string(e) + ". Results remain in memory; Retry save."; return false; }
	}
	/** Quote every cell, including newlines/quotes. Prevent spreadsheet formula execution. */
	public static function cell(s:String):String {
		if (s == null) s = "";
		var trimmed = StringTools.ltrim(s);
		if (trimmed.length > 0 && "=+-@\t\r".indexOf(trimmed.charAt(0)) >= 0) s = "'" + s;
		return '"' + StringTools.replace(s,'"','""') + '"';
	}
	static function csvNumber(v:Float):String return Math.isFinite(v) ? Std.string(v) : "";
	public static function csv(selected:Array<HemorrhageRun>):String {
		var rows = ["record,run_id,build,notes,timestamp_ms,mod_build,game_build,state,quality,elapsed_s,attack_s,tail_s,crit_start,crit_min,crit_max,rating_start,rating_min,rating_max,ability_id,ability,damage,dps,physical_bleed,spark_bleed,bleed_dps,bleed_share,physical_hits,physical_crits,magic_hits,magic_crits,direct_crit_damage,bleed_ticks,bleed_crits,unknown,dropped"];
		for (r in selected) {
			function row(kind:String, id:String, label:String, m:HemorrhageMetrics):Void {
				var values = [kind,r.id,r.build,r.notes,csvNumber(r.wallMs),r.modBuild,r.gameBuild,(r.state:String),r.quality(),csvNumber(r.elapsed),csvNumber(r.attackSeconds),csvNumber(r.tailSeconds),csvNumber(r.chanceStart),csvNumber(r.chanceMin),csvNumber(r.chanceMax),csvNumber(r.ratingStart),csvNumber(r.ratingMin),csvNumber(r.ratingMax),id,label,csvNumber(m.damage),csvNumber(r.elapsed>0 ? m.damage/r.elapsed : Math.NaN),csvNumber(m.physicalBleed),csvNumber(m.sparkBleed),csvNumber(r.elapsed>0 ? m.bleed()/r.elapsed : Math.NaN),csvNumber(m.damage>0 ? m.bleed()/m.damage : Math.NaN),Std.string(m.physicalHits),Std.string(m.physicalCrits),Std.string(m.magicHits),Std.string(m.magicCrits),csvNumber(m.criticalDamage),Std.string(m.bleedTicks),Std.string(m.bleedCrits),Std.string(m.unknown),Std.string(r.dropped)];
				rows.push([for(v in values) cell(v)].join(","));
			}
			row("summary","","",r.metrics);
			for (a in r.abilities) row("ability",a.id,a.label,a.metrics);
		}
		return rows.join("\r\n") + "\r\n";
	}
}
