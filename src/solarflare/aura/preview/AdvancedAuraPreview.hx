package solarflare.aura.preview;

import imgui.ImGui;
import imgui.ref.FloatRef;
import imgui.ref.IntRef;
import solarflare.aura.AuraDef;
import solarflare.aura.AuraTimer;
import solarflare.aura.AuraEffects;
import solarflare.aura.AuraVisualRenderer;
import solarflare.ui.HUDVisualBounds;
import solarflare.ui.UiLayout;

/** A contained preview of configured Aura artwork. Simulation never edits the Aura. */
class AdvancedAuraPreview {
	public var progress = new FloatRef(0.65);
	public var stacks = new IntRef(3);
	public var counter = new IntRef(7);
	public var autoPlay:Bool = false;
	public var animSpeed = new FloatRef(0.8);
	public var lastDrawX:Float = 0;
	public var lastDrawY:Float = 0;
	public var lastDrawW:Float = 0;
	public var lastDrawH:Float = 0;
	var bounds = new HUDVisualBounds();
	var lastAuraId:String = "";
	var lastStamp:Float = 0;

	public function new() {}
	public function reset():Void {
		autoPlay = false;
		lastStamp = 0;
		lastAuraId = "";
		progress.set(0.65);
		stacks.set(3);
		counter.set(7);
	}

	public function draw(a:AuraDef, width:Float, height:Float, withControls:Bool = true, compactFit:Bool = false):Void {
		if (a == null) return;
		if (lastAuraId != a.id) {
			reset();
			lastAuraId = a.id;
		}
		var now = haxe.Timer.stamp();
		var dt = lastStamp > 0 ? Math.max(0, Math.min(0.1, now - lastStamp)) : 0;
		lastStamp = now;
		if (autoPlay) progress.set((progress.get() - dt * animSpeed.get() + 1) % 1);
		var pos = ImGui.getCursorScreenPos();
		ImGui.dummy(ImGui.vec2(width, height));
		var sc:Single = Math.max(0.4, Math.min(2.5, a.scale.get()));
		var baseW:Single = Math.max(24, a.w.get() * sc);
		var baseH:Single = Math.max(24, a.h.get() * sc);
		var simLeft:Null<Float> = -1;
		var fixedTimer = a.timerMode != AuraTimer.MODE_OFF && a.timerSource == AuraTimer.SRC_FIXED;
		if (fixedTimer || !a.timerInfinite) {
			var span = a.timerSource == AuraTimer.SRC_FIXED ? a.timerSeconds.get()
				: solarflare.cdb.CdbAuraTable.listedSpan(a.timingSubjectId());
			if (!(span > 0.05)) span = 12;
			simLeft = span * (a.timerMode == AuraTimer.MODE_UP ? 1 - progress.get() : progress.get());
		}
		var glow = AuraEffects.hasIconGlow(a);
		var fit:Single = 1;
		var drawW:Single = baseW;
		var drawH:Single = baseH;
		// Remeasure after fitting: text has a readable minimum size, unlike face pixels.
		for (_ in 0...5) {
			drawW = baseW * fit;
			drawH = baseH * fit;
			AuraVisualRenderer.measureBounds(a, drawW, drawH, stacks.get(), counter.get(), bounds, sc * fit, simLeft, glow);
			var next = Math.min(1, Math.min(Math.max(1, width - 8) / bounds.width(), Math.max(1, height - 8) / bounds.height()));
			if (next >= 0.999) break;
			if (_ < 4) fit *= next;
		}
		var cx:Single = pos.x + (width - bounds.width()) * 0.5 - bounds.minX;
		var cy:Single = pos.y + (height - bounds.height()) * 0.5 - bounds.minY;
		var dl = ImGui.getWindowDrawList();
		ImGui.ImDrawList_PushClipRect(dl, pos, ImGui.vec2(pos.x + width, pos.y + height), true);
		try {
			AuraVisualRenderer.draw(dl, a, cx, cy, drawW, drawH, a.timerMode == AuraTimer.MODE_UP ? 1 - progress.get() : progress.get(), stacks.get(), counter.get(),
				false, 1, sc * fit, simLeft, glow);
			AuraVisualRenderer.drawKeyChip(dl, cx, cy, drawW, drawH, a, false);
		} catch (e:Dynamic) { ImGui.ImDrawList_PopClipRect(dl); throw e; }
		ImGui.ImDrawList_PopClipRect(dl);
		lastDrawX = cx;
		lastDrawY = cy;
		lastDrawW = drawW;
		lastDrawH = drawH;
		if (withControls) drawControls();
	}

	/** Only supported preview state, no unrelated prefab Pulse/Expire/Ready artwork. */
	public function drawControls():Void {
		UiLayout.propertyGrid("##ab_preview_simulation", function() {
			UiLayout.propertyRow("Playback", function() {
				if (ImGui.button(autoPlay ? "Pause##apv" : "Play##apv")) autoPlay = !autoPlay;
				ImGui.sameLine();
				if (ImGui.button("Reset##apv_reset")) {
					progress.set(0.65);
					stacks.set(3);
					counter.set(7);
					autoPlay = false;
				}
			});
			UiLayout.propertyRow("Remaining", function() {
				if (ImGui.sliderFloat("##apv_progress", progress, 0, 1, "%.2f")) autoPlay = false;
			});
			UiLayout.propertyRow("Stacks", function() {
				if (ImGui.inputInt("##apv_stacks", stacks, 0, 0)) stacks.set(Std.int(Math.max(0, stacks.get())));
			});
			UiLayout.propertyRow("Counter", function() {
				if (ImGui.inputInt("##apv_counter", counter, 0, 0)) counter.set(Std.int(Math.max(0, counter.get())));
			});
			UiLayout.propertyRow("Playback speed", function() {
				ImGui.sliderFloat("##apv_speed", animSpeed, 0.1, 2, "%.2fx");
			});
		});
		ImGui.textDisabled("Preview only. Shows the display options enabled for this aura.");
	}
}
