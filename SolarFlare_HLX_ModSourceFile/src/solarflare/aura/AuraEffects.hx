package solarflare.aura;

/**
 * Evaluates AuraEffect list after the trigger computes hit/known/progress.
 */
class AuraEffects {
	public static inline var MAX:Int = 8;

	public static function ensure(a:AuraDef):Void {
		if (a == null)
			return;
		if (a.effects == null)
			a.effects = [];
		if (a.effects.length == 0) {
			if (a.dormant.get())
				a.effects.push(AuraEffect.dormantWindow(a.duration > 0.05 ? a.duration : 3));
			else if (a.visual.get())
				a.effects.push(AuraEffect.defaultWindow());
		}
		if (a.effects.length > MAX) {
			while (a.effects.length > MAX)
				a.effects.pop();
		}
	}

	public static function apply(a:AuraDef, hit:Bool, known:Bool, now:Float, prog:Float):Void {
		if (a == null)
			return;
		ensure(a);
		if (prog < 0)
			prog = 0;
		if (prog > 1)
			prog = 1;

		var showWin = false;
		var showAlert = false;
		var alertText = "";
		var iconGlow = false;
		var fxAlpha:Float = 1;
		var anyWin = false;

		var i = 0;
		while (i < a.effects.length) {
			var e = a.effects[i];
			i++;
			if (e == null || !e.enabled.get())
				continue;
			var active = evalWhen(e, hit, known, now, a);
			if (!active)
				continue;
			var kind = e.kind;
			if (kind == AuraEffect.KIND_WINDOW) {
				anyWin = true;
				showWin = true;
				fxAlpha = blendAlpha(e, now, fxAlpha);
			} else if (kind == AuraEffect.KIND_ALERT) {
				showAlert = true;
				if (e.text != null && e.text.length > 0)
					alertText = e.text;
				else if (a.announce != null && a.announce.length > 0)
					alertText = a.announce;
				else
					alertText = a.displayLabel();
			} else if (kind == AuraEffect.KIND_ICON) {
				anyWin = true;
				showWin = true;
				if (e.glow.get())
					iconGlow = true;
				fxAlpha = blendAlpha(e, now, fxAlpha);
			} else if (kind == AuraEffect.KIND_AUDIO) {
				// Stored for DRM export; HudMod does not play cues.
			}
		}

		// Legacy visual gate: if there is a window/icon effect, still honor visual=false.
		if (anyWin && !a.visual.get())
			showWin = false;

		a.show = showWin;
		a.alertShow = showAlert;
		a.alertText = alertText;
		a.iconGlow = iconGlow;
		a.fxAlpha = fxAlpha;
		a.progress = prog;
		var rise = hit && !a.condWas;
		if (rise && a.isCounter != null && a.isCounter.get()) {
			a.counterValue++;
			a.stacks = a.counterValue;
		}

		if (hit)
			a.lastHitAt = now;
		a.condWas = hit;
	}

	static function evalWhen(e:AuraEffect, hit:Bool, known:Bool, now:Float, a:AuraDef):Bool {
		if (!known && e.when != AuraEffect.WHEN_ON_RISE_HOLD && e.when != AuraEffect.WHEN_ON_FALL_HOLD
			&& e.when != AuraEffect.WHEN_STICKY) {
			if (e.when == AuraEffect.WHEN_WHILE_TRUE || e.when == AuraEffect.WHEN_WHILE_FALSE)
				return false;
		}
		var rise = hit && !a.condWas;
		var fall = !hit && a.condWas;
		var hold = e.hold > 0.05 ? e.hold : catalogHold(a, 1.5);

		switch (e.when) {
			case AuraEffect.WHEN_WHILE_TRUE:
				return known && hit;
			case AuraEffect.WHEN_WHILE_FALSE:
				return known && !hit;
			case AuraEffect.WHEN_ON_RISE:
				if (rise) {
					e.until = now + hold;
					return true;
				}
				return e.until > now;
			case AuraEffect.WHEN_ON_FALL:
				if (fall) {
					e.until = now + hold;
					return true;
				}
				return e.until > now;
			case AuraEffect.WHEN_ON_RISE_HOLD:
				if (rise) {
					e.until = now + hold;
					return true;
				}
				if (e.until > now)
					return true;
				return false;
			case AuraEffect.WHEN_ON_FALL_HOLD:
				if (fall) {
					e.until = now + hold;
					return true;
				}
				if (e.until > now)
					return true;
				return false;
			case AuraEffect.WHEN_STICKY:
				if (rise)
					e.stickyArmed = true;
				if (!hit)
					e.stickyArmed = false;
				return e.stickyArmed;
			default:
				return known && hit;
		}
	}

	static function catalogHold(a:AuraDef, fallback:Float):Float {
		if (a.duration > 0.05)
			return a.duration;
		var c = solarflare.cdb.CdbAuraTable.duration(a.skillId);
		if (c > 0.2)
			return c;
		return fallback;
	}

	static function blendAlpha(e:AuraEffect, now:Float, cur:Float):Float {
		var a = e.alpha != null ? e.alpha.get() : 1;
		if (a < 0.05)
			a = 0.05;
		if (a > 1)
			a = 1;
		if (e.until > now && e.hold > 0.05 && e.fadeOut > 0.01) {
			var left = e.until - now;
			if (left < e.fadeOut)
				a *= left / e.fadeOut;
		}
		return a < cur ? a : cur;
	}

	public static function syncDormantFlag(a:AuraDef):Void {
		if (a == null || a.effects == null)
			return;
		var dormant = false;
		for (e in a.effects) {
			if (e != null && e.enabled.get() && e.kind == AuraEffect.KIND_WINDOW
				&& e.when == AuraEffect.WHEN_ON_RISE_HOLD) {
				dormant = true;
				break;
			}
		}
		a.dormant.set(dormant);
	}

	public static function applyPresetCdReady(a:AuraDef, alertText:String):Void {
		if (a == null)
			return;
		a.effects = AuraEffect.presetCdReady(alertText);
		a.dormant.set(false);
		a.visual.set(true);
	}

	public static function applyPresetDormant(a:AuraDef):Void {
		if (a == null)
			return;
		a.effects = [AuraEffect.dormantWindow(a.duration > 0.05 ? a.duration : 3)];
		a.dormant.set(true);
		a.visual.set(true);
	}

	public static function applyPresetOnCd(a:AuraDef):Void {
		if (a == null)
			return;
		var e = new AuraEffect("win", AuraEffect.KIND_WINDOW, AuraEffect.WHEN_WHILE_FALSE);
		a.effects = [e];
		a.dormant.set(false);
		a.visual.set(true);
	}

	public static function applyPresetContinuous(a:AuraDef):Void {
		if (a == null)
			return;
		a.effects = [AuraEffect.defaultWindow()];
		a.dormant.set(false);
		a.visual.set(true);
	}
}
