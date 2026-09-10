package solarflare.geaux;

import solarflare.HealthCache;
import solarflare.FieldWalk;

/**
 * Capture Heaps skill-book drag so Geaux cells can call Hero.setSkillSlot.
 * Sole SolarFlare postfix on Skill.onTriggerCD / reduceCooldown / resetCooldown —
 * do not add a second hook class (docs/SkillCdHooks.hx is a draft only).
 */
class GeauxHooks {
	public static var dragging:Dynamic = null;

	public static function keep():Void {}

	@:hlx.postfix(ui.BaseUI.startDrag)
	static function onStartDrag(self:Dynamic, el:Dynamic, result:Void):Void {
		dragging = el;
	}

	@:hlx.postfix(st.skill.Skill.onTriggerCD)
	static function onTriggerCD(skill:Dynamic, result:Void):Void {
		if (!isLocalSkill(skill))
			return;
		GeauxCache.noteTriggerCd(skill);
	}

	@:hlx.postfix(st.skill.Skill.reduceCooldown)
	static function onReduceCooldown(skill:Dynamic, seconds:Float, result:Void):Void {
		if (!isLocalSkill(skill))
			return;
		GeauxCache.noteReduceCd(skill, seconds);
	}

	@:hlx.postfix(st.skill.Skill.resetCooldown)
	static function onResetCooldown(skill:Dynamic, result:Void):Void {
		if (!isLocalSkill(skill))
			return;
		GeauxCache.noteResetCd(skill);
	}

	static function isLocalSkill(skill:Dynamic):Bool {
		if (skill == null)
			return false;
		// solarflare.debug.PayloadProbe.capture("cast", skill); // once: confirm owner/parent in payload-probe.jsonl
		try {
			var bs:st.skill.BaseSkill = skill;
			var unit = bs.get_ownerUnit();
			if (unit != null)
				return HealthCache.isLocalHero(unit);
			var hero = bs.get_ownerHero();
			if (hero != null)
				return HealthCache.isLocalHero(hero);
			var foe = bs.get_ownerFoe();
			if (foe != null)
				return HealthCache.isLocalHero(foe);
			if (bs.owner != null)
				return HealthCache.isLocalHero(bs.owner);
		} catch (_:Dynamic) {}
		var owner = FieldWalk.extractObject(skill, "owner");
		if (owner != null)
			return HealthCache.isLocalHero(owner);
		var parent = FieldWalk.extractObject(skill, "parent");
		if (parent != null && HealthCache.isLocalHero(parent))
			return true;
		owner = FieldWalk.extractObject(parent, "owner");
		if (owner != null)
			return HealthCache.isLocalHero(owner);
		return false;
	}

	public static function pollGuiDrag():Void {
		if (dragging != null)
			return;
		try {
			var app = GameApp.get();
			if (app == null || app.gui == null)
				return;
			var el = app.gui.draggingComponent;
			if (el != null)
				dragging = el;
		} catch (_:Dynamic) {}
	}

	public static function skillIdFromDrag(el:Dynamic):String {
		if (el == null)
			return "";
		try {
			var btn:ui.hud.SkillPickButton = el;
			if (btn.inf != null && btn.inf.id != null && btn.inf.id.length > 0) {
				var a = GeauxCache.sanitizeSkillId(btn.inf.id);
				if (a.length > 0) {
					ledgerDrag(a, "typed", "SkillPickButton.inf.id");
					return a;
				}
			}
			if (btn.skill != null) {
				var k = GeauxCache.sanitizeSkillId(btn.skill.kind);
				if (k.length > 0)
					return k;
			}
		} catch (_:Dynamic) {}
		try {
			var heroBtn:ui.win.HeroSkillButton = el;
			if (heroBtn.unlockInf != null && heroBtn.unlockInf.skill != null && heroBtn.unlockInf.skill.length > 0) {
				var u = GeauxCache.sanitizeSkillId(heroBtn.unlockInf.skill);
				if (u.length > 0)
					return u;
			}
		} catch (_:Dynamic) {}
		var inf = FieldWalk.extractObject(el, "inf");
		var id = GeauxCache.sanitizeSkillId(dynDragString(FieldWalk.extractObject(inf, "id")));
		if (id.length > 0) {
			ledgerDrag(id, "fieldwalk", "inf.id");
			return id;
		}
		try {
			var unlock = FieldWalk.extractObject(el, "unlockInf");
			var sk = GeauxCache.sanitizeSkillId(dynDragString(FieldWalk.extractObject(unlock, "skill")));
			if (sk.length > 0)
				return sk;
		} catch (_:Dynamic) {}
		try {
			var skill = FieldWalk.extractObject(el, "skill");
			if (skill != null) {
				var k = GeauxCache.sanitizeSkillId(dynDragString(FieldWalk.extractObject(skill, "kind")));
				if (k.length > 0)
					return k;
				k = GeauxCache.getSkillId(skill);
				if (k.length > 0)
					return k;
			}
		} catch (_:Dynamic) {}
		return "";
	}

	static function ledgerDrag(id:String, method:String, name:String):Void {
		if (!solarflare.debug.ResolutionLedger.armed())
			return;
		solarflare.debug.ResolutionLedger.note("geaux.drag.skillId")
			.withMethod(method)
			.withSrc("GeauxHooks.skillIdFromDrag")
			.withName(name)
			.withHook("ui.BaseUI.startDrag")
			.withPayload("ui.hud.SkillPickButton", "hook.el")
			.tryRoute("typed", "SkillPickButton.inf.id")
			.tryRoute("fieldwalk", "inf.id")
			.str(id)
			.emit();
	}

	/** Never Std.string Dynamic fields — Bytes become `{bytes :…}`. */
	static function dynDragString(v:Dynamic):String {
		if (v == null)
			return "";
		try {
			if (Std.isOfType(v, String)) {
				var s:String = v;
				return s != null ? s : "";
			}
		} catch (_:Dynamic) {}
		return "";
	}

	public static function assignSlot(index:Int, skillId:String):Void {
		if (skillId == null || skillId.length == 0 || index < 0)
			return;
		var heroDyn = HealthCache.localHero;
		if (heroDyn == null)
			return;
		try {
			var hero:ent.Hero = cast heroDyn;
			hero.setSkillSlot(skillId, index);
			GeauxCache.markLayoutDirty();
		} catch (_:Dynamic) {}
	}
}
