package solarflare.aura.signal;

/** Native-free catalog/search and edit session. Browsing never mutates a rule. */
class AuraConditionPickerModel {
	public var entries(default, null):Array<AuraConditionPickerEntry> = [];
	public var groups(default, null):Array<String> = [];
	public var matches(default, null):Array<Int> = [];
	public var groupCounts(default, null):Array<Int> = [];
	public var query(default, null):String = "";
	public var group(default, null):String = "";
	public var highlight(default, null):Int = -1;
	public var active(default, null):Bool = false;
	public var targetRule(default, null):AuraRuleDef;
	public var target(default, null):AuraConditionDef;
	public var queryCount(default, null):Int = 0;
	public var revision(default, null):Int = 0;
	var tokens:Array<String> = [];
	var validOwner:Void->Bool;
	var beforeEdit:Void->Void;
	var afterEdit:Void->Void;
	public function new(catalog:Array<AuraSignalDescriptor> = null) {
		if (catalog == null) catalog = AuraSignalCatalog.all();
		for (d in catalog) if (groups.indexOf(d.group) < 0) groups.push(d.group);
		// Stable presentation families, then original catalog order within a family.
		for (g in groups) {
			var grouped:Array<AuraConditionPickerEntry> = [];
			for (i in 0...catalog.length) if (catalog[i].group == g) grouped.push(new AuraConditionPickerEntry(catalog[i], i));
			grouped.sort(function(a, b) return a.familyOrder == b.familyOrder ? a.catalogOrder - b.catalogOrder : a.familyOrder - b.familyOrder);
			for (entry in grouped) entries.push(entry);
		}
		refilter();
	}
	public static function normalize(value:String):String {
		return value == null ? "" : StringTools.replace(StringTools.replace(StringTools.replace(value.toLowerCase(), "_", ""), "-", ""), " ", "");
	}
	public function open(rule:AuraRuleDef, condition:AuraConditionDef, ownerValid:Void->Bool, snapshot:Void->Void, sync:Void->Void):Bool {
		cancel(); targetRule = rule; target = condition; validOwner = ownerValid; beforeEdit = snapshot; afterEdit = sync;
		active = true;
		if (!isValid()) { cancel(); return false; }
		query = ""; group = ""; tokens.resize(0); refilter();
		for (i in 0...matches.length) if (entries[matches[i]].descriptor.id == target.signal) { highlight = i; break; }
		return true;
	}
	public function isValid():Bool {
		return active && targetRule != null && target != null && targetRule.conditions != null
			&& targetRule.conditions.indexOf(target) >= 0 && (validOwner == null || validOwner());
	}
	public function cancel():Void {
		active = false; targetRule = null; target = null; validOwner = null; beforeEdit = null; afterEdit = null;
	}
	public function setQuery(value:String):Void {
		if (value == null) value = ""; if (query == value) return;
		query = value; tokens.resize(0);
		for (token in ~/\s+/g.split(StringTools.trim(value))) {
			var key = normalize(token); if (key != "") tokens.push(key);
		}
		refilter();
	}
	public function setGroup(value:String):Void {
		if (value == null || groups.indexOf(value) < 0) value = "";
		if (group == value) return; group = value; refilter();
	}
	function refilter():Void {
		matches.resize(0); groupCounts.resize(0); for (_ in groups) groupCounts.push(0); queryCount = 0;
		for (i in 0...entries.length) {
			var e = entries[i]; var found = true;
			for (token in tokens) if (e.searchKey.indexOf(token) < 0) { found = false; break; }
			if (!found) continue;
			queryCount++; groupCounts[groups.indexOf(e.descriptor.group)]++;
			if (group == "" || group == e.descriptor.group) matches.push(i);
		}
		highlight = matches.length == 0 ? -1 : 0; revision++;
	}
	public function moveHighlight(delta:Int):Void {
		if (matches.length == 0) { highlight = -1; return; }
		highlight = Std.int(Math.max(0, Math.min(matches.length - 1, highlight + delta)));
	}
	public function setHighlightById(id:String):Void {
		for (i in 0...matches.length) if (entries[matches[i]].descriptor.id == id) { highlight = i; return; }
	}
	public function highlighted():AuraSignalDescriptor return highlight < 0 || highlight >= matches.length ? null : entries[matches[highlight]].descriptor;
	public function choose(id:String):Bool {
		if (!isValid()) { cancel(); return false; }
		var d:AuraSignalDescriptor = null;
		for (e in entries) if (e.descriptor.id == id) { d = e.descriptor; break; }
		if (d == null) return false;
		if (target.signal == id) { cancel(); return false; }
		if (beforeEdit != null) beforeEdit();
		if (!isValid()) { cancel(); return false; }
		// Match the full builder's existing signal-change policy, including retained leaf inversion.
		target.signal = d.id; target.op = AuraConditionValidator.defaultOperator(d);
		target.subject = ""; target.subjectLabel = "";
		target.numberValue = d.kind == Percent ? 0.35 : 1; target.boolValue = true;
		if (afterEdit != null) afterEdit();
		cancel(); return true;
	}
}

class AuraConditionPickerEntry {
	public var descriptor(default, null):AuraSignalDescriptor;
	public var searchKey(default, null):String;
	public var caption(default, null):String;
	public var choiceLabel(default, null):String;
	public var currentChoiceLabel(default, null):String;
	public var hitLabel(default, null):String;
	public var typeCaption(default, null):String;
	public var currentCaption(default, null):String;
	public var tooltip(default, null):String;
	public var family(default, null):String;
	public var familyOrder(default, null):Int;
	public var catalogOrder(default, null):Int;
	public function new(d:AuraSignalDescriptor, order:Int = 0) {
		descriptor = d; searchKey = AuraConditionPickerModel.normalize(d.id + " " + d.label + " " + d.group);
		catalogOrder = order;
		tooltip = d.label + "\n" + d.id;
		hitLabel = "###condition_choice_" + d.id;
		choiceLabel = d.label + "###condition_choice_" + d.id;
		currentChoiceLabel = d.label + "  (current)###condition_choice_" + d.id;
		var type = switch (d.kind) {
			case Number: "Amount"; case Percent: "Percentage"; case Count: "Count";
			case Duration: "Seconds"; case Boolean: "True / false"; case Identity: "Identity";
		};
		caption = d.group + "  |  " + type;
		typeCaption = type; currentCaption = type + " | current";
		family = ""; familyOrder = 0;
		switch (d.group) {
			case "Resources":
				if (StringTools.startsWith(d.id, "resource.health.") || StringTools.startsWith(d.id, "resource.shield.")) family = "Health and shields";
				else if (StringTools.startsWith(d.id, "resource.mana.") || StringTools.startsWith(d.id, "resource.rage.") || StringTools.startsWith(d.id, "resource.spark.")) { family = "Power"; familyOrder = 1; }
				else if (StringTools.startsWith(d.id, "resource.combo.") || d.id == "resource.generic.ratio") { family = "Class resource and combo points"; familyOrder = 2; }
				else { family = "Other resources"; familyOrder = 4; }
			case "Skills":
				switch (d.id) {
					case "skill.ready", "skill.equipped", "skill.affordable": family = "Availability";
					case "skill.inCooldown", "skill.cooldownLeft", "skill.cooldownProgress": family = "Cooldowns"; familyOrder = 1;
					case "skill.charges", "skill.chargesMax", "event.skill.chargeGained", "event.skill.chargeSpent": family = "Charges"; familyOrder = 2;
					case "event.playerCast.recent": family = "Recent casts"; familyOrder = 3;
					default: family = "Other skills"; familyOrder = 4;
				}
			case "Class mechanics":
				if (StringTools.startsWith(d.id, "prayer.")) family = "Prayers";
				else if (StringTools.startsWith(d.id, "chaincast.")) { family = "Chaincast"; familyOrder = 1; }
				else if (StringTools.startsWith(d.id, "conduit.")) { family = "Conduits"; familyOrder = 2; }
				else if (StringTools.startsWith(d.id, "attackCombo.")) { family = "Attack combo"; familyOrder = 3; }
				else { family = "Other mechanics"; familyOrder = 4; }
			case "Movement":
				if (StringTools.startsWith(d.id, "event.dash.")) { family = "Recent dash events"; familyOrder = 1; }
				else if (StringTools.startsWith(d.id, "dash.")) family = "Charges and recharge";
				else { family = "Other movement"; familyOrder = 4; }
			default:
		}
	}
}
