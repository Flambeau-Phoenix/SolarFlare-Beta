package solarflare.hemorrhage;

import imgui.ImGui;
import imgui.ref.BoolRef;
import imgui.ref.FloatRef;
import solarflare.ui.HudChrome;
import solarflare.ui.SettingsStore;
import solarflare.ui.UiLayout;

class HemorrhageConfig {
	public var hidden = new BoolRef(true);
	public var autoScroll = new BoolRef(true);
	public var floatingText = new BoolRef(false);
	public var textSize = new FloatRef(18);
	public var textLifetime = new FloatRef(1.5);
	public var width = new FloatRef(560);
	public var height = new FloatRef(260);
	public var chrome = new HudChrome(40, 440);
	public var sizeDirty:Bool = true;
	var lastStatsAt:Float = -1;
	var lastIdentityGen:Int = -1;

	public function new() {}

	/** Known fields from Unit.attr / UnitAttributes, sampled before any ImGui window. */
	public function observe(hero:Dynamic, now:Float):Void {
		HemorrhageCache.tick(now, textLifetime.get());
		var gen = solarflare.HealthCache.identityGen;
		if (hidden.get() || hero == null) {
			HemorrhageCache.setStats(Math.NaN, Math.NaN);
			lastStatsAt = -1;
			return;
		}
		if (gen == lastIdentityGen && lastStatsAt >= 0 && now - lastStatsAt < 0.25) return;
		lastIdentityGen = gen;
		lastStatsAt = now;
		var chance = Math.NaN;
		var rating = Math.NaN;
		try {
			var attr = solarflare.FieldWalk.extractObject(hero, "attr");
			chance = solarflare.FieldWalk.extractNumber(attr, "critChance", Math.NaN);
			rating = solarflare.FieldWalk.extractNumber(attr, "critChanceRating", Math.NaN);
		} catch (_:Dynamic) {}
		HemorrhageCache.setStats(chance, rating);
	}

	public function drawEditorContents():Void {
		UiLayout.propertyGrid("##hemorrhage_settings", function() {
			UiLayout.propertyRow("Panel", function() {
				UiLayout.inlinePair("##hemorrhage_visibility", function(w:Single) {
					if (solarflare.ui.UiChrome.showingTile("##hemorrhage_show", "Showing", hidden, w, 28)) SettingsStore.markDirty();
				}, function(_:Single) {
					if (ImGui.checkbox("Auto-scroll##hemorrhage_scroll", autoScroll)) SettingsStore.markDirty();
				});
			});
			UiLayout.propertyRow("Floating text", function() {
				if (ImGui.checkbox("Enabled##hemorrhage_float", floatingText)) {
					HemorrhageCache.clearFloating();
					SettingsStore.markDirty();
				}
			}, "Damage labels rise in the area above the table. Enable Transparent, then Lock to stage the HUD.");
			UiLayout.propertyRow("Text size / lifetime", function() {
				UiLayout.inlinePair("##hemorrhage_float_settings", function(_:Single) {
					if (ImGui.sliderFloat("##hemorrhage_font", textSize, 12, 28, "%.0f px")) SettingsStore.markDirty();
				}, function(_:Single) {
					if (ImGui.sliderFloat("##hemorrhage_lifetime", textLifetime, 0.5, 3, "%.1f s")) SettingsStore.markDirty();
				});
			});
			UiLayout.propertyRow("Window", function() {
				UiLayout.inlinePair("##hemorrhage_chrome", function(_:Single) {
					if (ImGui.checkbox("Lock##hemorrhage_lock", chrome.locked)) SettingsStore.markDirty();
				}, function(_:Single) {
					if (ImGui.checkbox("Transparent##hemorrhage_trans", chrome.transparent)) SettingsStore.markDirty();
				});
			});
		});
		ImGui.textWrapped("Your physical critical hits and observed Hemorrhage damage on all enemies. Totals continue until Clear; the latest 1,024 events are retained.");
		if (ImGui.button("Clear history##hemorrhage_clear_settings")) HemorrhageCache.clear();
	}
}
