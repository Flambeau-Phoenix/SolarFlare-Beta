package solarflare.cdb;

/** One drop line of a loot table. Text is baked once in keep() so draw only reads strings. */
typedef LootRow = {
	/** Share of the owning table, 0..1. Weighted tables are normalised, independent tables keep the authored chance. */
	var chance:Float;
	/** Item id, or "" when this row rolls a nested table. */
	var item:String;
	/** Nested table id, or "" for an item row. */
	var table:String;
	var chanceText:String;
	/** "x2-5", or "" for the default single item. */
	var qtyText:String;
	var lvlText:String;
	/** Quantity, level band, foe type, difficulty, reputation and row flags, joined with " | ". */
	var detailText:String;
}

typedef LootSource = {var kind:String; var id:String; var name:String;}

/** One "Level: 4" style line from the item row. */
typedef LootDetail = {var label:String; var value:String;}

/** An item row that appears directly in one table. */
typedef LootDrop = {var table:String; var row:LootRow;}

class LootItem {
	public var id:String;
	public var name:String;
	public var type:String;
	public var rarity:String;
	/** Atlas key in atlas_loot ("" when the item has no portrait). */
	public var art:String;
	/** Lowercase "name id type rarity" for search. */
	public var haystack:String;
	public var drops:Array<LootDrop> = [];
	/** Flavour/description text from the CDB, "" when none. */
	public var desc:String = "";
	/** Stat and detail lines baked from the item row (level, classes, affixes, effects, skills...). */
	public var details:Array<LootDetail> = [];
	/** "Rare | Chest | 3 tables", baked for the list row. */
	public var subtitle:String = "";
	/** Stable ImGui id for the list row. */
	public var rowId:String;

	public function new(id:String, name:String, type:String, rarity:String, art:String) {
		this.id = id;
		this.name = name;
		this.type = type;
		this.rarity = rarity;
		this.art = art;
		haystack = (name + " " + id + " " + type + " " + rarity).toLowerCase();
		rowId = "##loot_i_" + id;
	}
}

class LootTable {
	public var id:String;
	public var weighted:Bool;
	public var affinity:Bool;
	public var rows:Array<LootRow> = [];
	public var sources:Array<LootSource> = [];
	public var sourceCount:Int = 0;
	/** Tables that nest this one, sorted. */
	public var parents:Array<String> = [];
	/** Up to three portrait keys for the list row (direct items first, then nested ones). */
	public var previewArt:Array<String> = [];
	/** Lowercase id, item names and source names for search. */
	public var haystack:String = "";
	/** "7 drops | weighted pick | 2 sources", baked for the list row. */
	public var subtitle:String = "";
	public var modeText:String = "";
	public var sourcesText:String = "";
	public var itemCount:Int = 0;
	/** Stable ImGui id for the list row. */
	public var rowId:String;

	public function new(id:String) {
		this.id = id;
		rowId = "##loot_t_" + id;
	}
}

/**
 * A unit with a boss-kill and/or heroic loot table. Drop lists are the tables flattened to items, so a boss reads
 * like an AtlasLoot page: item, chance per kill, caption. The CDB has no dungeon rows, so bosses group by creature type.
 */
class LootBoss {
	public var id:String;
	public var name:String;
	public var level:Int;
	/** Creature type (Manfish, Kobold, Bee...). */
	public var family:String;
	public var bossTable:String;
	/** "" when the boss has no heroic table. */
	public var heroicTable:String;
	/** The unit's regular loot table, "" when none. */
	public var regularTable:String;
	public var normalDrops:Array<LootRow> = [];
	public var heroicDrops:Array<LootRow> = [];
	public var regularDrops:Array<LootRow> = [];
	/** Up to three portrait keys (heroic loot first). */
	public var previewArt:Array<String> = [];
	public var haystack:String = "";
	public var subtitle:String = "";
	public var rowId:String;

	public function new(id:String, name:String, level:Int, family:String, bossTable:String, heroicTable:String, regularTable:String) {
		this.id = id;
		this.name = name;
		this.level = level;
		this.family = family;
		this.bossTable = bossTable;
		this.heroicTable = heroicTable;
		this.regularTable = regularTable;
		rowId = "##loot_b_" + id;
	}

	public function hasHeroic():Bool return heroicTable != "";
}

private class FlatAcc {
	public var chance:Float;
	public var row:LootRow;
	public var via:String;

	public function new(chance:Float, row:LootRow, via:String) {
		this.chance = chance;
		this.row = row;
		this.via = via;
	}
}

/** Loot tables baked from the CDB (tools/build_loot_catalog.py); initialized before UI, never from draw(). */
class LootCatalog {
	public static var tables(default, null):Array<LootTable> = [];
	public static var items(default, null):Array<LootItem> = [];
	/** Distinct item types and rarities in display order, for the filter combos. */
	public static var types(default, null):Array<String> = [];
	public static var rarities(default, null):Array<String> = [];
	public static var withArt(default, null):Int = 0;
	public static var bosses(default, null):Array<LootBoss> = [];
	/** Creature types that have a boss, sorted. */
	public static var families(default, null):Array<String> = [];
	static var bossById = new Map<String, LootBoss>();
	static var tableById = new Map<String, LootTable>();
	static var itemById = new Map<String, LootItem>();
	static var ready = false;

	static var RARITY_ORDER = ["Common", "Uncommon", "Rare", "Epic", "Legendary"];
	static var FOE_FLAGS = ["Basic foes", "Special foes", "Dungeon foes"];
	static var ROW_FLAGS = ["scales with level", "personal loot", "uses item level"];
	static inline var MAX_SOURCE_LINES:Int = 12;

	public static function keep():Void {
		if (ready)
			return;
		ready = true;
		var data:Dynamic = haxe.Json.parse(haxe.Resource.getString("loot-tables"));
		var difficulty:Array<String> = data.difficulty;
		var itemRows:Array<Dynamic> = data.items;
		for (row in itemRows) {
			var item = new LootItem(row.id, row.n != null && row.n != "" ? row.n : row.id, row.ty, row.r, row.a);
			item.desc = row.d != null ? row.d : "";
			var lines:Array<Dynamic> = row.p != null ? row.p : [];
			var extra = [item.desc];
			for (l in lines) {
				item.details.push({label: l[0], value: l[1]});
				extra.push(l[0] + " " + l[1]);
			}
			item.haystack += " " + extra.join(" ").toLowerCase();
			items.push(item);
			itemById.set(item.id, item);
			if (item.art.length > 0)
				withArt++;
		}
		var tableRows:Array<Dynamic> = data.tables;
		for (row in tableRows) {
			var table = new LootTable(row.id);
			table.weighted = row.w == true;
			table.affinity = row.a == true;
			var rows:Array<Dynamic> = row.rows;
			var total:Float = 0;
			for (r in rows)
				total += r.p;
			for (r in rows)
				table.rows.push(bakeRow(r, table.weighted, total, difficulty));
			var srcRows:Array<Dynamic> = row.src;
			for (s in srcRows)
				table.sources.push({kind: s[0], id: s[1], name: s[2]});
			table.sourceCount = row.srcN;
			tables.push(table);
			tableById.set(table.id, table);
		}
		link();
		bakeBosses(data.bosses);
		tables.sort(function(a, b) return compare(a.id, b.id));
		items.sort(function(a, b) return compare(a.name, b.name));
		for (item in items) {
			if (item.type != "" && types.indexOf(item.type) < 0)
				types.push(item.type);
			if (item.rarity != "" && rarities.indexOf(item.rarity) < 0)
				rarities.push(item.rarity);
		}
		types.sort(compare);
		rarities.sort(function(a, b) return RARITY_ORDER.indexOf(a) - RARITY_ORDER.indexOf(b));
	}

	static function compare(a:String, b:String):Int {
		var x = a.toLowerCase();
		var y = b.toLowerCase();
		return x < y ? -1 : (x > y ? 1 : 0);
	}

	static function bakeRow(r:Dynamic, weighted:Bool, total:Float, difficulty:Array<String>):LootRow {
		var chance:Float = weighted ? (total > 0 ? r.p / total : 0) : r.p;
		var mn:Null<Int> = r.mn;
		var mx:Null<Int> = r.mx;
		var lo:Null<Int> = r.lo;
		var hi:Null<Int> = r.hi;
		var qty = "";
		if (mn != null || mx != null) {
			var a = mn != null ? mn : 1;
			var b = mx != null ? mx : a;
			if (!(a == 1 && b == 1))
				qty = a == b ? "x" + a : "x" + a + "-" + b;
		}
		var lvl = "";
		if (lo != null && hi != null)
			lvl = "Lv " + lo + "-" + hi;
		else if (lo != null)
			lvl = "Lv " + lo + "+";
		else if (hi != null)
			lvl = "up to Lv " + hi;
		var cond:Array<String> = [];
		var c:Null<Int> = r.c;
		if (c != null)
			pushFlags(cond, c, FOE_FLAGS);
		if (r.d != null) {
			var d:Array<Int> = r.d;
			var top = difficulty.length - 1;
			if (!(d[0] == 0 && d[1] == top))
				cond.push(d[0] == d[1] ? difficulty[d[0]] + " only" : (d[1] == top ? difficulty[d[0]] + "+" : difficulty[d[0]] + " to " + difficulty[d[1]]));
		}
		if (r.r != null) {
			var rep:Array<Dynamic> = r.r;
			cond.push("Rep " + rep[0] + " L" + rep[1]);
		}
		var f:Null<Int> = r.f;
		if (f != null)
			pushFlags(cond, f, ROW_FLAGS);
		var detail:Array<String> = [];
		if (r.t != null)
			detail.push("Nested table");
		if (qty != "")
			detail.push(qty);
		if (lvl != "")
			detail.push(lvl);
		detail = detail.concat(cond);
		return {
			chance: chance,
			item: r.i != null ? r.i : "",
			table: r.t != null ? r.t : "",
			chanceText: percent(chance),
			qtyText: qty,
			lvlText: lvl,
			detailText: detail.join(" | ")
		};
	}

	static function pushFlags(into:Array<String>, bits:Int, names:Array<String>):Void {
		for (i in 0...names.length)
			if ((bits & (1 << i)) != 0)
				into.push(names[i]);
	}

	/** 35%, 2.5%, 0.08%: enough precision to tell a rare drop from a very rare one. */
	public static function percent(chance:Float):String {
		var v = chance * 100;
		if (v >= 10)
			return Math.round(v) + "%";
		if (v >= 1)
			return Math.round(v * 10) / 10 + "%";
		if (v >= 0.01)
			return Math.round(v * 100) / 100 + "%";
		return v > 0 ? "<0.01%" : "0%";
	}

	/** Reverse links and list-row text: item drops, nesting parents, previews, search text. */
	static function link():Void {
		for (table in tables) {
			var seen = new Map<String, Bool>();
			for (row in table.rows) {
				if (row.item != "") {
					var item = itemById.get(row.item);
					if (item != null)
						item.drops.push({table: table.id, row: row});
					if (!seen.exists(row.item)) {
						seen.set(row.item, true);
						table.itemCount++;
					}
				} else if (row.table != "") {
					var child = tableById.get(row.table);
					if (child != null && child.parents.indexOf(table.id) < 0)
						child.parents.push(table.id);
				}
			}
		}
		for (table in tables) {
			table.parents.sort(compare);
			var names = [table.id];
			for (row in table.rows) {
				if (row.item == "")
					continue;
				var item = itemById.get(row.item);
				if (item == null)
					continue;
				names.push(item.name);
				if (item.art != "" && table.previewArt.length < 3 && table.previewArt.indexOf(item.art) < 0)
					table.previewArt.push(item.art);
			}
			for (s in table.sources)
				names.push(s.name);
			table.haystack = names.join(" ").toLowerCase();
			table.modeText = table.weighted ? "Weighted pick: one drop is chosen by weight" : "Independent rolls: each line rolls on its own";
			if (table.affinity)
				table.modeText += " | affinity-aware";
			var parts = [table.rows.length + (table.rows.length == 1 ? " drop" : " drops"), table.weighted ? "weighted" : "independent"];
			if (table.sourceCount > 0)
				parts.push(table.sourceCount + (table.sourceCount == 1 ? " source" : " sources"));
			else if (table.parents.length > 0)
				parts.push("nested");
			table.subtitle = parts.join(" | ");
			var lines:Array<String> = [];
			for (s in table.sources) {
				if (lines.length >= MAX_SOURCE_LINES)
					break;
				lines.push(s.name == s.id ? s.id + " (" + s.kind + ")" : s.name + " (" + s.kind + " " + s.id + ")");
			}
			if (table.sourceCount > lines.length)
				lines.push("+" + (table.sourceCount - lines.length) + " more");
			table.sourcesText = lines.join(", ");
		}
		for (item in items) {
			item.drops.sort(function(a, b) return a.row.chance > b.row.chance ? -1 : (a.row.chance < b.row.chance ? 1 : 0));
			var count = item.drops.length;
			var parts = [item.rarity, item.type, count + (count == 1 ? " table" : " tables")];
			item.subtitle = parts.join(" | ");
		}
		// Tables that only nest others have no direct items: borrow preview art from their children.
		for (table in tables) {
			if (table.previewArt.length > 0)
				continue;
			for (row in table.rows) {
				var child = row.table != "" ? tableById.get(row.table) : null;
				if (child == null)
					continue;
				for (art in child.previewArt)
					if (table.previewArt.length < 3 && table.previewArt.indexOf(art) < 0)
						table.previewArt.push(art);
			}
		}
	}

	static function bakeBosses(rows:Array<Dynamic>):Void {
		if (rows == null)
			return;
		for (r in rows) {
			var boss = new LootBoss(r.id, r.n != null && r.n != "" ? r.n : r.id, r.lv, r.ty, r.b, r.h, r.g);
			boss.normalDrops = flatten(boss.bossTable);
			boss.heroicDrops = flatten(boss.heroicTable);
			boss.regularDrops = flatten(boss.regularTable);
			var preview = boss.heroicDrops.length > 0 ? boss.heroicDrops : boss.normalDrops;
			for (d in preview) {
				var item = itemById.get(d.item);
				if (item != null && item.art != "" && boss.previewArt.length < 3)
					boss.previewArt.push(item.art);
			}
			var heroic = boss.hasHeroic() ? "heroic " + boss.heroicDrops.length : "no heroic table";
			boss.subtitle = "Lv " + boss.level + " | " + boss.family + " | " + heroic + " | normal " + boss.normalDrops.length;
			var names = [boss.name, boss.id, boss.family];
			for (d in boss.normalDrops.concat(boss.heroicDrops).concat(boss.regularDrops)) {
				var item = itemById.get(d.item);
				if (item != null)
					names.push(item.name);
			}
			boss.haystack = names.join(" ").toLowerCase();
			bosses.push(boss);
			bossById.set(boss.id, boss);
			if (families.indexOf(boss.family) < 0)
				families.push(boss.family);
		}
		families.sort(compare);
		bosses.sort(function(a, b) return a.family == b.family ? (a.level != b.level ? a.level - b.level : compare(a.name, b.name)) : compare(a.family, b.family));
	}

	/**
	 * A table reduced to its items: nested tables multiply their chance in, and an item reachable twice combines as
	 * 1-(1-a)(1-b). Level, foe and difficulty gates on rows are not applied; their text stays in detailText.
	 */
	static function flatten(tableId:String):Array<LootRow> {
		var out = new Map<String, FlatAcc>();
		var order:Array<String> = [];
		if (tableId != null && tableId != "")
			flattenInto(tableId, 1.0, 0, "", out, order);
		var rows:Array<LootRow> = [];
		for (id in order) {
			var acc = out.get(id);
			var detail = acc.row.detailText;
			if (acc.via != "")
				detail = detail == "" ? "via " + acc.via : detail + " | via " + acc.via;
			rows.push({chance: acc.chance, item: id, table: "", chanceText: percent(acc.chance), qtyText: acc.row.qtyText,
				lvlText: acc.row.lvlText, detailText: detail});
		}
		rows.sort(function(a, b) {
			if (a.chance != b.chance)
				return a.chance > b.chance ? -1 : 1;
			var x = itemById.get(a.item);
			var y = itemById.get(b.item);
			return compare(x != null ? x.name : a.item, y != null ? y.name : b.item);
		});
		return rows;
	}

	static function flattenInto(tableId:String, multiplier:Float, depth:Int, via:String, out:Map<String, FlatAcc>, order:Array<String>):Void {
		var table = tableById.get(tableId);
		if (table == null || depth > 5)
			return;
		for (row in table.rows) {
			var chance = row.chance * multiplier;
			if (row.item != "") {
				var acc = out.get(row.item);
				if (acc == null) {
					out.set(row.item, new FlatAcc(chance, row, via));
					order.push(row.item);
				} else
					acc.chance = 1 - (1 - acc.chance) * (1 - chance);
			} else if (row.table != "")
				flattenInto(row.table, chance, depth + 1, via == "" ? row.table : via, out, order);
		}
	}

	public static function boss(id:String):LootBoss return id == null ? null : bossById.get(id);

	public static function table(id:String):LootTable return id == null ? null : tableById.get(id);

	public static function item(id:String):LootItem return id == null ? null : itemById.get(id);
}
