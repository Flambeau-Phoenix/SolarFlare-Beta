package solarflare.aimcast;

/**
 * One press casts a ground-target skill at the camera aim point.
 *
 * The game aims with the camera (no free pointer): pressing the skill key starts an aim job, and pressing it again
 * confirms. The confirm does three things (client.UnitController.startTargetMode job): turn the unit toward the
 * point, hand `SkillTarget.Point` to the use callback (UnitController.tryUseSkill), and leave aim mode with
 * `setJob(Stop)`. This runs those same three steps right after aim mode starts, so the first press is the confirm.
 * The point is the engine's own formula (AimCastMath). Observe thread, driven by an event-only postfix hook.
 */
class AimInstant {
	/** `st.skill.SkillStep` type label index of "Aim" in the CDB (`skill@steps.type`). */
	public static inline var AIM_STEP:Int = 25;
	public static var config:AimInstantConfig = null;
	static var busy:Bool = false;

	/** Called after `UnitController.startSkillAim(skill, callback, action)` returned. */
	public static function onAimStart(controller:Dynamic, skill:Dynamic):Void {
		var cfg = config;
		if (cfg == null || !cfg.enabled.get() || busy) return; // cheapest check first: everything else is skipped when off
		busy = true;
		var why:String = "";
		var ok = false;
		var id = "";
		try {
			var pc:client.UnitController = cast controller;
			var local = false;
			var inst = client.PlayerController.inst;
			if (inst != null) {
				var instDyn:Dynamic = inst;
				local = instDyn == controller;
			}
			var job = pc.currentJob;
			var aiming = job != null && job.isAiming();
			var unit:ent.Unit = pc.unit;
			var base:st.skill.BaseSkill = null;
			var step:st.skill.SkillStep = null;
			var allow = false;
			if (aiming && local && unit != null && skill != null) {
				var use:st.skill.Skill = unit.getReplacedSkill(skill);
				if (use == null) use = skill;
				base = use;
				step = base.getStepByType(AIM_STEP);
				var script = base.script;
				allow = script != null && script.allowAiming();
			}
			var skip = AimInstantPolicy.skipReason(true, local, aiming, step != null, allow);
			if (skip != null) {
				why = skip;
			} else {
				id = solarflare.EngineText.cleanId(base.kind);
				var range:Float = step.inf.range == null ? 0 : step.inf.range;
				var cam = pc.get_gameCamera();
				var ctl = Const.Controls;
				var band = ctl.Skill_PointTarget_RangeSensibility_Pitch;
				var pos = unit.position;
				if (!(range > 0)) why = "aim range " + range;
				else if (cam == null || pos == null) why = "no camera or position";
				else if (band == null || band.min == null || band.max == null) why = "pitch band unavailable";
				else {
					var yaw:Float = cam.direction;
					var pitch:Float = cam.pitch;
					var dist = AimCastMath.distance(pitch, range, ctl.Skill_PointTarget_RangeSensibility_PitchMin,
						ctl.Skill_PointTarget_RangeSensibility_PitchPow, band.min, band.max);
					var px = AimCastMath.x(pos.x, dist, yaw);
					var py = AimCastMath.y(pos.y, dist, yaw);
					// Height: the unit's. Ground-target steps snap to the ground themselves (position flag GroundSnap).
					var pz:Float = pos.z;
					if (!AimCastMath.finite([yaw, pitch, dist, px, py, pz])) why = "non-finite aim values";
					else {
						var use2:st.skill.Skill = unit.getReplacedSkill(skill);
						if (use2 == null) use2 = skill;
						unit.rotateTo(Math.atan2(py - pos.y, px - pos.x));
						pc.tryUseSkill(use2, st.skill.SkillTarget.Point({x: px, y: py, z: pz}));
						pc.setJob(client.JobKind.Stop, null, null);
						ok = true;
					}
				}
			}
		} catch (e:Dynamic) {
			why = "exception: " + Std.string(e).substr(0, 80);
		}
		busy = false;
	}
}
