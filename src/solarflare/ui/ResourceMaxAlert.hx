package solarflare.ui;

import imgui.ImGui;

/**
 * Splat toast when combo / rage / chaincast hits cap. Not used for HP or mana.
 */
class ResourceMaxAlert {
	public static inline var ART:String = "resource-max";
	public static inline var ALERT_SEC:Float = 2;
	public static inline var TOAST_H:Single = 36;

	public static function nowSec():Float {
		try
			return haxe.Timer.stamp()
		catch (_:Dynamic)
			return Date.now().getTime() / 1000.0;
	}

	public static function risingMax(prev:Float, now:Float, cap:Float, until:Float):Float {
		if (cap <= 0.05)
			return until;
		var was = prev >= cap - 0.05;
		var isMax = now >= cap - 0.05;
		if (isMax && !was)
			return nowSec() + ALERT_SEC;
		return until;
	}

	public static function active(until:Float):Bool {
		return nowSec() < until;
	}

	public static function drawToast(rowW:Single, toastH:Single):Void {
		if (rowW < 8)
			rowW = 8;
		if (toastH < 12)
			toastH = TOAST_H;
		var origin = ImGui.getCursorScreenPos();
		var dl = ImGui.getWindowDrawList();
		var tex = GameIcons.get(ART);
		if (tex == (0 : hl.I64))
			tex = GameIcons.get(GameIcons.COMBO_MAX);
		var side:Single = toastH;
		if (side > rowW)
			side = rowW;
		var x:Single = origin.x + (rowW - side) * 0.5;
		if (tex != (0 : hl.I64) && GameIcons.drawRect(dl, tex, x, origin.y, side, toastH)) {
			ImGui.dummy(ImGui.vec2(rowW, toastH));
			return;
		}
		ImGui.dummy(ImGui.vec2(rowW, toastH));
	}

	/** Overlay the splat on an already-drawn bar (vitals rage). */
	public static function drawOver(x:Single, y:Single, w:Single, h:Single):Void {
		if (w < 8 || h < 8)
			return;
		var dl = ImGui.getWindowDrawList();
		var tex = GameIcons.get(ART);
		if (tex == (0 : hl.I64))
			tex = GameIcons.get(GameIcons.COMBO_MAX);
		if (tex == (0 : hl.I64))
			return;
		var side:Single = h < w ? h : w;
		if (side > 48)
			side = 48;
		// The bar leaves its cursor after item spacing, beyond its registered bounds.
		// Register that restore point before GameIcons temporarily moves the cursor.
		var saved = ImGui.getCursorScreenPos();
		ImGui.dummy(ImGui.vec2(0, 0));
		ImGui.setCursorScreenPos(saved);
		GameIcons.draw(dl, tex, x + (w - side) * 0.5, y + (h - side) * 0.5, side);
	}
}
