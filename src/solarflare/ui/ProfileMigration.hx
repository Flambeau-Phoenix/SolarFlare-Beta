package solarflare.ui;

/**
 * Pure profile snapshot normalization and v17 -> v18 schema migration.
 * Free of native ImGui, hl.Bytes, or runtime dependencies for isolated validation.
 */
class ProfileMigration {
	public static inline var VERSION:Int = 18;

	/** Remove retired feature-local profile banks from one universal snapshot and enforce schema v18. */
	public static function normalizeProfileSnapshot(data:Dynamic):Dynamic {
		if (data == null)
			return {};
		try {
			var geaux = Reflect.field(data, "geaux");
			if (geaux != null)
				Reflect.setField(data, "geaux", flattenLegacyFeature(geaux, "slots"));
			var auras = Reflect.field(data, "auras");
			if (auras != null)
				Reflect.setField(data, "auras", flattenLegacyFeature(auras, "list"));
			var attackCombo = Reflect.field(data, "attackCombo");
			if (attackCombo != null)
				Reflect.setField(data, "attackCombo", migrateAttackCombo(attackCombo));
			var activeTheme = Reflect.field(data, "activeTheme");
			if (activeTheme != null)
				Reflect.setField(data, "activeTheme", migrateThemeName(activeTheme));
			Reflect.setField(data, "v", VERSION);
		} catch (_:Dynamic) {}
		return data;
	}

	/** Pure migration for legacy theme names to v18 ThemeKind constants. */
	public static function migrateThemeName(name:Dynamic):String {
		if (name == null) return "purple_gold";
		var s = Std.string(name).toLowerCase();
		return switch (s) {
			case "volcanic": "obsidian_ember";
			case "midnight": "voidsteel_blue";
			case "emerald": "moonlit_slate";
			case "obsidian": "obsidian_ember";
			case "purple_gold", "obsidian_ember", "voidsteel_blue", "ash_gold", "solarflare_crimson", "moonlit_slate", "high_contrast", "custom": s;
			default: "purple_gold";
		};
	}

	/** Pure migration for legacy attack combo settings data. */
	public static function migrateAttackCombo(data:Dynamic):Dynamic {
		if (data == null) return {};
		var out:Dynamic = {};
		try {
			for (f in Reflect.fields(data))
				Reflect.setField(out, f, Reflect.field(data, f));
			if (Reflect.hasField(data, "mode") && !Reflect.hasField(data, "type") && !Reflect.hasField(data, "comboType")) {
				var m = Std.parseInt(Std.string(Reflect.field(data, "mode")));
				if (m == 2) {
					Reflect.setField(out, "type", 1);
					var a = Reflect.hasField(data, "art") ? Std.parseInt(Std.string(Reflect.field(data, "art"))) : 0;
					Reflect.setField(out, "customStyle", a == 0 ? 0 : 1);
				} else {
					Reflect.setField(out, "type", 0);
					if (m == 1)
						Reflect.setField(out, "shape", 0);
				}
			}
			if (Reflect.hasField(data, "comboType") && !Reflect.hasField(data, "type"))
				Reflect.setField(out, "type", Reflect.field(data, "comboType"));
			if (Reflect.hasField(data, "style") && !Reflect.hasField(data, "customStyle"))
				Reflect.setField(out, "customStyle", Reflect.field(data, "style"));
		} catch (_:Dynamic) {}
		return out;
	}

	/** v16 compatibility: use flat state when present, otherwise import the selected nested layout once. */
	public static function flatOrSelectedLegacy(data:Dynamic, flatField:String):Dynamic {
		if (data == null || Reflect.hasField(data, flatField))
			return data;
		try {
			var profiles = Reflect.field(data, "profiles");
			if (profiles == null)
				return data;
			var active = Reflect.field(data, "active");
			if (active != null && Reflect.hasField(profiles, Std.string(active)))
				return Reflect.field(profiles, Std.string(active));
			var keys = Reflect.fields(profiles);
			if (keys.length > 0)
				return Reflect.field(profiles, keys[0]);
		} catch (_:Dynamic) {}
		return data;
	}

	public static function flattenLegacyFeature(data:Dynamic, flatField:String):Dynamic {
		var source = flatOrSelectedLegacy(data, flatField);
		try {
			Reflect.deleteField(source, "profiles");
			Reflect.deleteField(source, "active");
			Reflect.deleteField(source, "regionOverride");
		} catch (_:Dynamic) {}
		return source;
	}
}
