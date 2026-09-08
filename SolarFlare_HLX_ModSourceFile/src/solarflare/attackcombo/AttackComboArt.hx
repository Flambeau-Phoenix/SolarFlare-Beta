package solarflare.attackcombo;

import solarflare.ui.GameIcons;

/**
 * Banner key matrix + chrome/launcher preload.
 * Banner images are loaded from the mod's assets/icons directory.
 */
class AttackComboArt {
	public static var status:String = "banner assets pending";
	static var loaded:Bool = false;
	static var reloadRequested:Bool = true;

	public static function hasPending():Bool return reloadRequested;

	/** Zero-allocation lookup used by both preload and presentation. */
	public static function candidate(artSet:Int, count:Int):String {
		var n = count;
		if (n < 0) n = 0;
		if (n > 4) n = 4;
		if (artSet == 1) {
			// Purple-blade series packed in first atlas.
			return switch (n) {
				case 0: "0ComboAttack";
				case 1: "01ComboAttack";
				case 2: "02ComboAttack";
				case 3: "03ComboAttack";
				default: "04FullCombo";
			};
		}
		// Sun/shuriken series. Style_* and Style2_* are duplicate sun variants.
		return switch (n) {
			case 0: "0NoCombo";
			case 1: "1AttackCombo";
			case 2: "2AttackCombo";
			case 3: "3AttackCombo";
			default: "4FullCombo";
		};
	}

	public static function requestReload():Void reloadRequested = true;
	public static function isLoaded():Bool return loaded;

	/** Observe-phase texture registration, after the ImGui frame is initialized. */
	public static function tickPreload():Void {
		if (!reloadRequested)
			return;
		reloadRequested = false;
		loaded = false;
		GameIcons.resetSearchDirs();
		GameIcons.preloadAll();
		var found = 0;
		for (set in 0...2)
			for (count in 0...5)
			{
				var key = candidate(set, count);
				GameIcons.preload(key);
				if (GameIcons.cachedW(key) > 0)
					found++;
			}
		loaded = found > 0;
		status = loaded ? "banner assets ready" : "banner assets unavailable — use Reload after assets are installed";
	}

	/** Compact cached diagnostic containing resolved mod directory, icon directory, requested key, and preload count. */
	public static function diagnostic():String {
		var found = 0;
		for (set in 0...2)
			for (count in 0...5)
			{
				var key = candidate(set, count);
				if (GameIcons.cachedW(key) > 0)
					found++;
			}
		return "Status: " + status + " | Banners: " + found + "/10 | " + GameIcons.diagnostic();
	}
}
