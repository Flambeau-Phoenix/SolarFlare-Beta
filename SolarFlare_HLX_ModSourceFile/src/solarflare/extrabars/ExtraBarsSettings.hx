package solarflare.extrabars;

/** Settings-only persistence. Old profile payloads are accepted once when no root settings exist. */
class ExtraBarsSettings {
	public static function fromSettings(data:Dynamic):{config:Dynamic, legacy:Dynamic} {
		var config = field(data, "extraBars");
		var legacy = field(data, "extraBarsPrototype");
		if (config != null || legacy != null) return {config:config, legacy:legacy};
		// A few older saves kept the feature only in the selected universal snapshot.
		// Never choose another build's bars or consult profiles during profile switching.
		for (key in ["universalProfiles", "featureProfiles"]) {
			var bank = field(data, key);
			var active = field(bank, "active");
			var profiles = field(bank, "profiles");
			var selected = active == null ? null : field(profiles, Std.string(active));
			config = field(selected, "extraBars");
			legacy = field(selected, "extraBarsPrototype");
			if (config != null || legacy != null) return {config:config, legacy:legacy};
		}
		return {config:null, legacy:null};
	}

	/** Remove retired per-build copies on save without changing the in-memory snapshot. */
	public static function withoutBars(snapshot:Dynamic):Dynamic {
		if (snapshot == null) return null;
		var result = Reflect.copy(snapshot);
		Reflect.deleteField(result, "extraBars");
		Reflect.deleteField(result, "extraBarsPrototype");
		return result;
	}

	static function field(data:Dynamic, name:String):Dynamic return data == null ? null : Reflect.field(data, name);
}
