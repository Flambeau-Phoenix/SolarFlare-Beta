package solarflare.aura.preview;

import imgui.ImGui;
import imgui.ref.FloatRef;
import imgui.ref.IntRef;
import solarflare.aura.AuraDef;
import solarflare.aura.AuraVisualRenderer;
import solarflare.ui.effects.EffectHelpers;

/**
 * Advanced live interactive preview with play/pause animations and vector effects.
 */
class AdvancedAuraPreview {
	public var progress = new FloatRef(0.65);
	public var stacks = new IntRef(3);
	public var autoPlay:Bool = false;
	public var animSpeed = new FloatRef(0.8);
	var animTime:Float = 0.0;

	public function new() {}

	public function draw(a:AuraDef, width:Float, height:Float):Void {
		if (a == null) return;

		// Reserve canvas space first — prevents SetCursorScreenPos boundary warnings.
		var canvasPos = ImGui.getCursorScreenPos();
		ImGui.dummy(ImGui.vec2(width, height));
		var drawList = ImGui.getWindowDrawList();

		ImGui.ImDrawList_AddRectFilled(drawList, canvasPos, ImGui.vec2(canvasPos.x + width, canvasPos.y + height), 0xEE121722, 6.0);
		ImGui.ImDrawList_AddRect(drawList, canvasPos, ImGui.vec2(canvasPos.x + width, canvasPos.y + height), 0x444A5568, 6.0, 1.0);

		if (autoPlay) {
			animTime += 0.016 * animSpeed.get();
			if (animTime > 1.0) animTime = 0.0;
			progress.set(animTime);
		}

		var drawW = a.w.get() * a.scale.get();
		var drawH = a.h.get() * a.scale.get();
		var fit = Math.min(1, Math.min((width - 20) / drawW, (height - 48) / drawH));
		drawW *= fit;
		drawH *= fit;
		var size = Math.min(drawW, drawH);
		var cx = canvasPos.x + (width - drawW) * 0.5;
		var cy = canvasPos.y + (height - 48 - drawH) * 0.5;

		AuraVisualRenderer.draw(drawList, a, cx, cy, drawW, drawH, progress.get(), stacks.get(), stacks.get(), false);

		var barW = width - 40;
		var barH = 6;
		var barX = canvasPos.x + 20;
		var barY = canvasPos.y + height - 36;
		ImGui.ImDrawList_AddRectFilled(drawList, ImGui.vec2(barX, barY), ImGui.vec2(barX + barW, barY + barH), 0x44FFFFFF, 3.0);
		ImGui.ImDrawList_AddRectFilled(drawList, ImGui.vec2(barX, barY), ImGui.vec2(barX + barW * progress.get(), barY + barH), 0xFF4FD1C5, 3.0);

		// Controls stay inside the reserved canvas (relative layout after dummy).
		var after = ImGui.getCursorScreenPos();
		ImGui.setCursorScreenPos(ImGui.vec2(canvasPos.x + 8, canvasPos.y + height - 28));
		if (ImGui.smallButton(autoPlay ? "Pause##apv" : "Play##apv"))
			autoPlay = !autoPlay;
		ImGui.sameLine();
		if (ImGui.smallButton("Pulse FX##apv")) {
			if (a.fxPulse != null) a.fxPulse.set(true);
			EffectHelpers.auraHit(cx + size * 0.5, cy + size * 0.5);
		}
		ImGui.sameLine();
		if (ImGui.smallButton("Expire FX##apv")) {
			if (a.fxExpire != null) a.fxExpire.set(true);
			EffectHelpers.auraExpire(cx + size * 0.5, cy + size * 0.5);
		}
		ImGui.sameLine();
		if (ImGui.smallButton("Ready FX##apv")) {
			if (a.fxReady != null) a.fxReady.set(true);
			EffectHelpers.skillReady(cx + size * 0.5, cy + size * 0.5);
		}
		ImGui.setCursorScreenPos(after);
	}
}
