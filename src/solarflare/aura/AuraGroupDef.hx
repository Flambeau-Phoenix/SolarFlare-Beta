package solarflare.aura;

/**
 * A dynamic display group: member auras (whose `group` tag equals this id) share one HUD window and
 * pack into a row, column or grid, closing gaps when a member is not showing. Independent of Aura Sets,
 * which decide when auras are armed. Pure settings: the window chrome lives on AuraConfig.
 */
class AuraGroupDef {
	public static inline var MAX:Int = 32;

	public static var GROWS:Array<String> = ["right", "left", "down", "up"];
	public static var ALIGNS:Array<String> = ["start", "center", "end"];
	public static var SORTS:Array<String> = ["list", "time"];

	public var id:String;
	public var name:String;
	/** Direction new members are added in. */
	public var grow:String = "right";
	/** Members per line before wrapping to the next one; 0 keeps one line. */
	public var wrap:Int = 0;
	public var spacing:Float = 4;
	/** Cross-axis alignment of members inside a line. */
	public var align:String = "center";
	/** "list" = library order, "time" = soonest expiry first. */
	public var sort:String = "list";
	/** Multipliers on top of each member's own Scale and Opacity. */
	public var scale:Float = 1;
	public var opacity:Float = 1;
	/** Raw record this group was imported from (window position), consumed by AuraConfig. */
	public var source:Dynamic = null;

	public function new(id:String, name:String) {
		this.id = id;
		this.name = name;
	}

	public inline function horizontal():Bool return grow == "right" || grow == "left";

	public function toObj():Dynamic {
		return {
			id: id, name: name, grow: grow, wrap: wrap, spacing: spacing,
			align: align, sort: sort, scale: scale, opacity: opacity
		};
	}

	/** Null when the record has no usable id. Out-of-range values clamp; unknown enums fall back. */
	public static function fromObj(d:Dynamic):AuraGroupDef {
		if (d == null || d.id == null)
			return null;
		var id = StringTools.trim(Std.string(d.id));
		if (id.length == 0)
			return null;
		var nm = d.name != null ? StringTools.trim(Std.string(d.name)) : "";
		var g = new AuraGroupDef(id, nm.length > 0 ? nm : id);
		g.grow = pick(d.grow, GROWS, "right");
		g.align = pick(d.align, ALIGNS, "center");
		g.sort = pick(d.sort, SORTS, "list");
		g.wrap = Std.int(num(d.wrap, 0, 0, 64));
		g.spacing = num(d.spacing, 4, 0, 64);
		g.scale = num(d.scale, 1, 0.25, 4);
		g.opacity = num(d.opacity, 1, 0.05, 1);
		return g;
	}

	/** `base`, or `base_2`, `base_3`... whichever `taken` does not already hold. */
	public static function uniqueId(base:String, taken:String->Bool):String {
		var root = base != null && StringTools.trim(base).length > 0 ? StringTools.trim(base) : "group";
		var id = root;
		var n = 2;
		while (taken(id)) id = root + "_" + (n++);
		return id;
	}

	/**
	 * Import a pack's groups beside existing ones: each incoming group gets a free id, and member
	 * aura records are re-tagged; tags naming no incoming group are cleared. Returns the new groups.
	 */
	public static function remapImport(rawGroups:Dynamic, auraRecords:Array<Dynamic>, taken:String->Bool):Array<AuraGroupDef> {
		var out:Array<AuraGroupDef> = [];
		var rename = new Map<String, String>();
		if (rawGroups != null && Std.isOfType(rawGroups, Array)) {
			var list:Array<Dynamic> = cast rawGroups;
			for (raw in list) {
				var g = fromObj(raw);
				if (g == null || rename.exists(g.id)) continue;
				var fresh = uniqueId(g.id, function(id) return taken(id) || [for (o in out) o.id].indexOf(id) >= 0);
				rename.set(g.id, fresh);
				g.id = fresh;
				g.source = raw;
				out.push(g);
			}
		}
		if (auraRecords != null)
			for (d in auraRecords) {
				if (d == null) continue;
				var tag = d.group != null ? Std.string(d.group) : "";
				d.group = rename.exists(tag) ? rename.get(tag) : "";
			}
		return out;
	}

	static function pick(v:Dynamic, options:Array<String>, fallback:String):String {
		var s = v != null ? Std.string(v) : "";
		return options.indexOf(s) >= 0 ? s : fallback;
	}

	static function num(v:Dynamic, fallback:Float, min:Float, max:Float):Float {
		if (v == null) return fallback;
		var f:Float = Std.isOfType(v, Float) || Std.isOfType(v, Int) ? v : Std.parseFloat(Std.string(v));
		if (!Math.isFinite(f)) return fallback;
		return f < min ? min : (f > max ? max : f);
	}
}
