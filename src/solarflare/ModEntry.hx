package solarflare;

import imgui.ImGui;

/**
 * hl-imgui README: construct the panel once, then ImGui.register.
 * imgui.ImGuiFrame (pulled in by -lib hl-imgui) hooks DX12Driver.present and
 * drives init / newFrame / render. This class never calls those.
 */
@:build(hlx.runtime.Mod.build())
class ModEntry {
	public static function main():Void {
		keepRoots();
		var panel:SolarFlarePanel = null;
		ImGui.register(HlxRuntime.moduleName(), () -> {
			try {
				if (panel == null)
					panel = new SolarFlarePanel();
				try
					panel.observeAssets()
				catch (_:Dynamic) {}
				var app:GameApp = null;
				try
					app = GameApp.get()
				catch (_:Dynamic) {}
				if (app != null) {
					try
						panel.observe(app)
					catch (_:Dynamic) {}
				} else
					panel.flushPendingSettings();
				try
					panel.draw()
				catch (_:Dynamic) {}
			} catch (_:Dynamic) {}
		});
	}

	/** Single DCE anchor for hook/table modules — do not duplicate in panel constructors. */
	static function keepRoots():Void {
		solarflare.cdb.CdbNames.keep();
		solarflare.cdb.CdbUnitNames.keep();
		solarflare.cdb.AuraCatalog.keep();
		solarflare.cdb.CdbAuraTable.keep();
		solarflare.geaux.GeauxCdTable.keep();
		solarflare.geaux.GeauxTalentTable.keep();
		solarflare.HealthHooks.keep();
		solarflare.attackcombo.AttackComboCache.keep();
		solarflare.geaux.GeauxHooks.keep();
		solarflare.combatlog.CombatLogHooks.keep();
		solarflare.combatlog.UniqueHeroName.keep();
		solarflare.lightsaber.Lightsaber.LightsaberHooks.keep();
		solarflare.lightsaber.Lightsaber.SaberJsonlArchive.keep();
		solarflare.EngineSkillId.keep();
		solarflare.debug.PayloadProbe.keep();
		solarflare.debug.ResolutionLedger.keep();
		solarflare.debug.FieldWalkLog.keep();
		solarflare.ui.CursorCaptureFix.keep();
	}
}
