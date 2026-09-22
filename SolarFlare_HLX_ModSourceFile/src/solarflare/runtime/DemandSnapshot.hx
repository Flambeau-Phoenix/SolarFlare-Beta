package solarflare.runtime;

/** Frozen consumer demand for one present callback. */
class DemandSnapshot {
	public var vitals:Bool = false;
	public var overlays:Bool = false;
	public var skills:Bool = false;
	public var target:Bool = false;
	public var status:Bool = false;
	public var auras:Bool = false;
	public var lightsaber:Bool = false;
	public var encounter:Bool = false;
	public var diagnostics:Bool = false;

	public function new() {}

	public function capture(cfg:solarflare.ui.ConfigPanel):Void {
		var d = solarflare.ObserveDemand;
		vitals = d.resourceBars || d.auras || d.auraBuilderOpen || d.prayers
			|| d.comboPoints || d.chaincast || d.conduit;
		overlays = d.prayers || d.comboPoints || d.chaincast || d.conduit || d.attackCombo;
		skills = d.geaux || d.geauxBuilder || d.auras || d.aurasNeedInstant
			|| d.aurasNeedSpecial || d.auraBuilderOpen;
		target = d.targetHud || d.castBars || d.combatLog || d.aurasNeedTarget || d.auraBuilderOpen;
		status = d.aurasNeedStatus;
		auras = d.auras || d.auraBuilderOpen;
		lightsaber = cfg != null && cfg.lightsaber != null && !cfg.lightsaber.hidden.get();
		diagnostics = solarflare.debug.ResolutionLedger.armed()
			|| solarflare.debug.PayloadProbe.armed() || solarflare.debug.FieldWalkLog.armed();
		encounter = d.riftFlag || diagnostics;
	}
}
