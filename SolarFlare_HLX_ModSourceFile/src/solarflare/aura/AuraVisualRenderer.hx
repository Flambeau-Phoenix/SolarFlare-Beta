package solarflare.aura;

import solarflare.ui.GameIcons;
import solarflare.ui.VitalsConfig.RingGauge;
import solarflare.ui.VitalsConfig.VerticalBarGauge;
import imgui.ImGui;
import solarflare.ui.HUDVisualBounds;

/** Shared, presentation-only Aura renderer used by the live HUD and builder preview. */
class AuraVisualRenderer {
	/** Auto-draw seconds when follow-buff left is known and at or below this. */
	public static inline var AUTO_COUNTDOWN_MAX:Float = 30;

	/** Published once per frame by AuraOverlay; 0 = no ceiling. */
	public static var countdownCeiling:Float = 0;
	public static var countdownAll:Bool = true;
	public static var countdownGlobalScale:Float = 1;

	/** Bound for this draw() only — preview may seed remaining/glow without mutating AuraDef. */
	static var faceLeft:Float = Math.NaN;
	static var faceInf:Bool = false;
	static var faceGlow:Bool = false;
	static var faceFx:Bool = true;
	/** Maximum procOverlay reach: icon outset 2 + bloom 10 + stroke/AA 2. */
	public static inline var GLOW_REACH:Float = 14;
	static var badgeLayout = new AuraBadgeLayout();

	/** Measure the same face and plates as draw(), before choosing the host/preview clip. */
	public static function measureBounds(a:AuraDef, w:Single, h:Single, stacks:Int, counterValue:Int,
			out:HUDVisualBounds, vectorScale:Float = 1, previewLeft:Null<Float> = null,
			previewGlow:Null<Bool> = null, editAllCanvas:Bool = false):Void {
		out.reset(w, h);
		bindFace(a, false, previewLeft, previewGlow);
		var fx:Single = 0;
		var fy:Single = 0;
		var fw:Single = w;
		var fh:Single = h;
		var icon = a.region == "icon";
		if (icon) {
			var labelH:Single = a.showLabel.get() ? Math.min(22, h * 0.24) : 0;
			fw = fh = Math.min(w, h - labelH);
			fx = (w - fw) * 0.5;
			fy = (h - labelH - fh) * 0.5;
			if (labelH > 0) {
				var ts = ImGui.calcTextSize(a.displayLabel());
				out.include((w - ts.x) * 0.5, h - labelH + 2, ts.x, ts.y + 1);
			}
		} else if (a.region == "text") {
			var ts = measureTextFace(a, w, vectorScale);
			out.include((w - ts.x) * 0.5, (h - ts.y) * 0.5, ts.x, ts.y);
		} else if (a.region != "canvas" && a.showLabel.get()) {
			var ts = ImGui.calcTextSize(a.displayLabel());
			out.include((w - ts.x) * 0.5, (h - ts.y) * 0.5, ts.x, ts.y);
		}
		if (a.region == "ring") out.includeRing(w * 0.5, h * 0.5, Math.min(w, h) * 0.42, vectorScale);
		if (icon && a.progressRing.get()) out.includeRing(fx + fw * 0.5, fy + fh * 0.5, fw * 0.46, vectorScale);
		if (faceGlow && a.region != "text" && a.glowStrength.get() > 0) {
			var reach:Single = AuraGlowStyle.reach(a.glowStyle, a.glowOuter.get()) + (icon ? 2 : 0);
			out.include(fx - reach, fy - reach, fw + reach * 2, fh + reach * 2);
		}
		if (a.region == "canvas" && !icon) {
			var sid = a.stateForDraw();
			for (el in (a.canvasElements != null ? a.canvasElements : [])) {
				if (el == null || !el.visible(editAllCanvas, sid)) continue;
				if (el.kind == AuraCanvasElement.KIND_ICON || el.kind == AuraCanvasElement.KIND_SHAPE || el.kind == AuraCanvasElement.KIND_PATH) {
					if (el.kind == AuraCanvasElement.KIND_ICON && !a.showIcon.get()) continue;
					var bw:Float = el.wAt(sid) > 1 ? el.wAt(sid) * vectorScale : w, bh:Float = el.hAt(sid) > 1 ? el.hAt(sid) * vectorScale : h;
					var ep:Float = el.edgePad() * vectorScale;
					if ((el.kind == AuraCanvasElement.KIND_SHAPE || el.kind == AuraCanvasElement.KIND_PATH) && el.rotationAt(sid) != 0) {
						var ext = AuraCanvasElement.rotatedHalfExtent(bw, bh, el.rotationAt(sid));
						out.include(el.xAt(sid) * vectorScale + bw * 0.5 - ext.hx - ep, el.yAt(sid) * vectorScale + bh * 0.5 - ext.hy - ep, ext.hx * 2 + ep * 2, ext.hy * 2 + ep * 2);
					} else out.include(el.xAt(sid) * vectorScale - ep, el.yAt(sid) * vectorScale - ep, bw + ep * 2, bh + ep * 2);
				} else {
					var ts = textSize(formatTokens(el.content, a, stacks, counterValue, el.wholeTime),
						(el.fontSize > 4 ? el.fontSize : 16) * vectorScale);
					var pad:Float = el.outline > 0 ? Math.max(1, el.outline * vectorScale) : 0;
					var boxW:Float = el.wAt(sid) > 1 ? el.wAt(sid) * vectorScale : 0;
					out.include(el.xAt(sid) * vectorScale - pad, el.yAt(sid) * vectorScale - pad, Math.max(ts.x, boxW) + pad * 2, ts.y + pad * 2);
				}
			}
		}
		prepareBadges(a, 0, 0, w, h, stacks, counterValue);
		badgeLayout.includeBounds(out);
		if (a.showKey.get()) {
			var key = AuraDef.sanitizeKey(a.keyText);
			if (key.length > 0) {
				var side = Math.min(w, h);
				var ts = textSize(key, keyFontSize(side));
				out.include(1, 0, ts.x + Math.max(4, side * 0.06) + 3, ts.y + Math.max(2, side * 0.04) + 3);
			}
		}
	}

	static function textSize(text:String, size:Single):imgui.Structs.ImVec2 {
		ImGui.pushFont(ImGui.getFont(), size);
		var result:imgui.Structs.ImVec2 = null;
		try { result = ImGui.calcTextSize(text); }
		catch (e:Dynamic) { ImGui.popFont(); throw e; }
		ImGui.popFont();
		return result;
	}

	static function keyFontSize(side:Single):Single {
		return Math.max(12, Math.min(22, Math.max(ImGui.getFontSize() * 1.05, side * 0.28)));
	}
	static function textFace(a:AuraDef, width:Single, vectorScale:Float):String {
		return a.textWrapCache.resolve(a.announce != null ? a.announce : "", width,
			AuraTextLayout.fontSize(a.textSize.get() * vectorScale), ImGui.getFont(),
			function(value:String) return ImGui.calcTextSize(value).x);
	}
	static function measureTextFace(a:AuraDef, width:Single, vectorScale:Float):imgui.Structs.ImVec2 {
		ImGui.pushFont(ImGui.getFont(), AuraTextLayout.fontSize(a.textSize.get() * vectorScale));
		var ts:imgui.Structs.ImVec2 = null;
		try { ts = ImGui.calcTextSize(textFace(a, width, vectorScale)); }
		catch (e:Dynamic) { ImGui.popFont(); throw e; }
		ImGui.popFont();
		return ts;
	}

	/** Same key reminder in preview and live output. */
	public static function drawKeyChip(dl:Dynamic, x:Single, y:Single, w:Single, h:Single, a:AuraDef, ghost:Bool):Void {
		if (!a.showKey.get()) return;
		var key = AuraDef.sanitizeKey(a.keyText);
		if (key.length == 0) return;
		var side = Math.min(w, h);
		ImGui.pushFont(ImGui.getFont(), keyFontSize(side));
		try {
			var ts = ImGui.calcTextSize(key);
			var tx:Single = x + 3;
			var ty:Single = y + 2;
			var alpha:Single = ghost ? 0.55 : 0.88;
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(tx - 1, ty - 1),
				ImGui.vec2(tx + ts.x + Math.max(4, side * 0.06), ty + ts.y + Math.max(2, side * 0.04)),
				ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.02, 0.02, 0.03, alpha)), 4);
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(tx + 1, ty + 1), 0xEE000000, key);
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(tx, ty),
				ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 0.96, 0.78, ghost ? 0.75 : 1)), key);
		} catch (e:Dynamic) { ImGui.popFont(); throw e; }
		ImGui.popFont();
	}

	public static function draw(dl:Dynamic, a:AuraDef, x:Single, y:Single, w:Single, h:Single,
			progress:Float, stacks:Int, counterValue:Int, ghost:Bool, effectAlpha:Float = 1,
			vectorScale:Float = 1, previewLeft:Null<Float> = null, previewGlow:Null<Bool> = null, editAllCanvas:Bool = false):Void {
		if (a == null || w < 1 || h < 1)
			return;
		bindFace(a, ghost, previewLeft, previewGlow);
		var p = clamp01(progress);
		var alpha:Float = a.opacity != null ? clamp01(a.opacity.get()) : 1;
		alpha *= clamp01(effectAlpha);
		if (ghost)
			alpha *= 0.38;
		var label = a.region == "text" ? (a.announce != null ? a.announce : "") : a.displayLabel();
		if (a.region == "canvas") {
			drawCanvas(dl, a, x, y, w, h, p, stacks, counterValue, alpha, vectorScale, editAllCanvas);
			drawBadges(dl, a, x, y, w, h, stacks, counterValue, alpha);
			return;
		}
		if (a.region == "icon") {
			drawIcon(dl, a, x, y, w, h, p, alpha, vectorScale);
			drawBadges(dl, a, x, y, w, h, stacks, counterValue, alpha);
			return;
		}
		var visibleLabel = a.showLabel != null && a.showLabel.get() ? label : "";
		var col = ImGui.vec4(0.35, 0.78, 0.95, alpha);
		if (a.region == "ring") {
			var rad:Single = (w < h ? w : h) * 0.42;
			if (faceFx && faceGlow) drawGlowRect(dl, x, y, w, h, a, alpha);
			RingGauge.draw(dl, ImGui.vec2(x + w * 0.5, y + h * 0.5), rad, p, col, visibleLabel, vectorScale);
			drawBadges(dl, a, x, y, w, h, stacks, counterValue, alpha);
			return;
		}
		if (a.region == "text") {
			ImGui.pushFont(ImGui.getFont(), AuraTextLayout.fontSize(a.textSize.get() * vectorScale));
			var ts:imgui.Structs.ImVec2 = null;
			try {
				var wrapped = textFace(a, w, vectorScale);
				ts = ImGui.calcTextSize(wrapped);
				ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(x + (w - ts.x) * 0.5, y + (h - ts.y) * 0.5),
					ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 1, 1, alpha)), wrapped);
			} catch (e:Dynamic) { ImGui.popFont(); throw e; }
			ImGui.popFont();
			drawBadges(dl, a, x, y, w, h, stacks, counterValue, alpha);
			return;
		}
		if (faceFx && faceGlow) drawGlowRect(dl, x + 4, y + 4, w - 8, h - 8, a, alpha);
		VerticalBarGauge.draw(dl, x + 4, y + 4, w - 8, h - 8, p, col, visibleLabel);
		drawBadges(dl, a, x, y, w, h, stacks, counterValue, alpha);
	}

	/** Both measurement and draw prepare exactly the same plates and face anchor. */
	static function prepareBadges(a:AuraDef, x:Single, y:Single, w:Single, h:Single, stacks:Int, counter:Int):Void {
		if (a.region == "icon") {
			var labelH:Single = a.showLabel.get() ? Math.min(22, h * 0.24) : 0;
			var side:Single = Math.min(w, h - labelH);
			x += (w - side) * 0.5;
			y += (h - labelH - side) * 0.5;
			w = h = side;
		}
		var side = Math.min(w, h);
		var timerText = faceInf ? "\u221E" : formatRemain(faceLeft);
		measureBadge(0, faceFx && wantCountdown(a) && timerText.length > 0 && w >= 8 && h >= 8,
			a.countdownPlace, timerText, HUDVisualBounds.fontSize(side, 0.34, a.countdownScale.get() * countdownGlobalScale));
		measureBadge(1, a.stackCounter.get() && stacks >= 1, a.stackPlace, Std.string(stacks),
			HUDVisualBounds.fontSize(side, 0.28, a.stackScale.get()));
		measureBadge(2, a.isCounter.get(), a.counterPlace, Std.string(counter),
			HUDVisualBounds.fontSize(side, 0.28, a.counterScale.get()));
		badgeLayout.resolve(x, y, w, h);
	}

	static function measureBadge(index:Int, enabled:Bool, place:Int, text:String, size:Single):Void {
		var tw:Float = 0;
		var th:Float = 0;
		if (enabled) {
			var ts = textSize(text, size);
			tw = ts.x;
			th = ts.y;
			if (index == 0) {
				// Stable usual timer width prevents second-by-second host resizing.
				var reserve = textSize("00:00", size);
				tw = Math.max(tw, reserve.x);
				th = Math.max(th, reserve.y);
			}
		}
		badgeLayout.set(index, enabled, place, text, size, tw, th);
	}

	static function drawBadges(dl:Dynamic, a:AuraDef, x:Single, y:Single, w:Single, h:Single,
			stacks:Int, counter:Int, alpha:Float):Void {
		prepareBadges(a, x, y, w, h, stacks, counter);
		for (i in 0...3) {
			var s = badgeLayout.slots[i];
			if (!s.enabled) continue;
			ImGui.pushFont(ImGui.getFont(), s.fontSize);
			try {
				var ts = ImGui.calcTextSize(s.text);
				var tx = s.x + (s.w - ts.x) * 0.5;
				var ty = s.y + AuraBadgeLayout.PAD_Y;
				ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(s.x, s.y), ImGui.vec2(s.x + s.w, s.y + s.h),
					ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.02, 0.03, 0.05, (i == 0 ? 0.72 : 0.82) * alpha)), 6);
				ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(tx + 1, ty + 1),
					ImGui.colorConvertFloat4ToU32(ImGui.vec4(0, 0, 0, 0.95 * alpha)), s.text);
				ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(tx, ty),
					ImGui.colorConvertFloat4ToU32(i == 0 ? ImGui.vec4(1, 0.95, 0.75, alpha) : ImGui.vec4(1, 1, 1, alpha)), s.text);
			} catch (e:Dynamic) { ImGui.popFont(); throw e; }
			ImGui.popFont();
		}
	}

	static function bindFace(a:AuraDef, ghost:Bool, previewLeft:Null<Float>, previewGlow:Null<Bool>):Void {
		faceFx = !ghost;
		faceInf = a.timerInfinite;
		faceLeft = a.timeLeft;
		if (previewLeft != null) {
			faceLeft = previewLeft;
			faceInf = previewLeft < 0;
		}
		faceGlow = previewGlow != null ? previewGlow : a.iconGlow;
	}

	/** When true, pulses also play in the editor and previews (fades only run in game or with Live conditions). */
	public static var animateInEditor:Bool = false;

	/** Freeform element placements + optional glow / fuse / countdown overlays. */
	static function drawCanvas(dl:Dynamic, a:AuraDef, x:Single, y:Single, w:Single, h:Single,
			progress:Float, stacks:Int, counter:Int, alpha:Float, vectorScale:Float, editAllCanvas:Bool):Void {
		// Empty canvas has no portrait until an icon element is explicitly added.
		var els = a.canvasElements != null ? a.canvasElements : [];
		var sid = a.stateForDraw();
		var live = !editAllCanvas;
		var animNow = haxe.Timer.stamp();
		if (faceFx && faceGlow) drawGlowRect(dl, x, y, w, h, a, alpha);

		var i = 0;
		while (i < els.length) {
			var el = els[i];
			i++;
			if (el == null) continue;
			// A layer that is fading out keeps drawing after it stops being visible.
			if (!el.visible(editAllCanvas, sid) && !(live && el.dissolving(animNow)))
				continue;
			var elAlpha = alpha * el.opacityAt(sid);
			var elCol = el.colorAt(sid);
			if (live && el.hasFade()) elAlpha *= el.fadeAlpha(animNow);
			if (el.pulseKind != AuraCanvasElement.PULSE_NONE && (live || animateInEditor)) {
				var wave = el.pulseWave(animNow);
				if (el.pulseKind == AuraCanvasElement.PULSE_FADE) elAlpha *= 1 - el.pulseDepth * wave;
				else elCol = lerpPacked(elCol, el.pulseColor, el.pulseDepth * wave);
			}
			if (elAlpha <= 0.002) continue;
			if (el.kind == AuraCanvasElement.KIND_SHAPE) {
				drawCanvasShape(dl, el.content, x + el.xAt(sid) * vectorScale, y + el.yAt(sid) * vectorScale,
					el.wAt(sid) > 1 ? el.wAt(sid) * vectorScale : w, el.hAt(sid) > 1 ? el.hAt(sid) * vectorScale : h,
					applyAlphaToPacked(elCol, elAlpha), el.stroke * vectorScale, el.rotationAt(sid), el.sides,
					el.color2 != null ? applyAlphaToPacked(el.color2, elAlpha) : null, el.gradDir);
			} else if (el.kind == AuraCanvasElement.KIND_PATH) {
				if (el.path != null)
					drawVectorPath(dl, el.path, x + el.xAt(sid) * vectorScale, y + el.yAt(sid) * vectorScale,
						el.wAt(sid) > 1 ? el.wAt(sid) * vectorScale : w, el.hAt(sid) > 1 ? el.hAt(sid) * vectorScale : h,
						el.fill, applyAlphaToPacked(elCol, elAlpha),
						el.color2 != null ? applyAlphaToPacked(el.color2, elAlpha) : null, el.gradDir,
						el.stroke * vectorScale, applyAlphaToPacked(el.strokeColor != null ? el.strokeColor : elCol, elAlpha), el.rotationAt(sid));
			} else if (el.kind == AuraCanvasElement.KIND_ICON) {
				if (!a.showIcon.get()) continue;
				var iw:Single = el.wAt(sid) > 1 ? el.wAt(sid) * vectorScale : w;
				var ih:Single = el.hAt(sid) > 1 ? el.hAt(sid) * vectorScale : h;
				var ex:Single = x + el.xAt(sid) * vectorScale;
				var ey:Single = y + el.yAt(sid) * vectorScale;
				var id = el.content != null && el.content.length > 0 ? el.content : a.preferredIconId();
				var tint = applyAlphaToPacked(elCol, elAlpha);
				if (!GameIcons.drawKey(dl, id, ex, ey, iw, ih, tint)) {
					ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(ex, ey),
						ImGui.vec2(ex + iw, ey + ih),
						ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.1, 0.12, 0.16, elAlpha * 0.85)), 6);
				}
			} else {
				var raw = el.content != null ? el.content : "";
				var formatted = formatTokens(raw, a, stacks, counter, el.wholeTime);
				var fontSize:Single = (el.fontSize > 4 ? el.fontSize : 16) * vectorScale;
				ImGui.pushFont(ImGui.getFont(), fontSize);
				try {
					var col = applyAlphaToPacked(elCol, elAlpha);
					var tx:Single = x + el.xAt(sid) * vectorScale;
					var ty:Single = y + el.yAt(sid) * vectorScale;
					var boxW:Float = el.wAt(sid) > 1 ? el.wAt(sid) * vectorScale : 0;
					if (boxW > 0 && el.textAlign != 0) {
						var tw = ImGui.calcTextSize(formatted).x;
						tx += el.textAlign == 1 ? (boxW - tw) * 0.5 : boxW - tw;
					}
					if (el.outline > 0) {
						var o:Single = Math.max(1, el.outline * vectorScale);
						var oc = applyAlphaToPacked(0xFF000000, elAlpha);
						for (dx in [-1, 0, 1]) for (dy in [-1, 0, 1]) if (dx != 0 || dy != 0)
							ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(tx + dx * o, ty + dy * o), oc, formatted);
					}
					if (el.shadow) {
						var off:Single = Math.max(1, fontSize / 16);
						ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(tx + off, ty + off), applyAlphaToPacked(0xE0000000, elAlpha), formatted);
					}
					ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(tx, ty), col, formatted);
				} catch (e:Dynamic) { ImGui.popFont(); throw e; }
				ImGui.popFont();
			}
			if (el.edgeOn && el.kind != AuraCanvasElement.KIND_TEXT)
				drawEdge(dl, el, sid, x, y, w, h, vectorScale, applyAlphaToPacked(el.edgeColor, elAlpha), progress, live);
		}

		if (faceFx && wantFuse(a, progress)) {
			if (a.fuseBottom != null && a.fuseBottom.get())
				drawFuseBottom(dl, x, y, w, h, progress, alpha);
			else
				drawFuse(dl, x, y, Math.min(w, h), progress, alpha);
		}

	}

	static var edgePts:hl.Bytes = new hl.Bytes(8 * AuraVectorPath.MAX_FLAT_POINTS);
	static var EDGE_BOX:Array<Float> = [0, 0, 0, 1, 1, 1, 1, 0];

	/**
	 * Coloured outline along a layer's edge: an image's visible shape (found once at load), a shape, or a path.
	 * With a cooldown wipe the outline is clipped to the part of the layer's box the timer has uncovered.
	 */
	static function drawEdge(dl:Dynamic, el:AuraCanvasElement, sid:String, ox:Float, oy:Float, cw:Float, ch:Float,
			vectorScale:Float, col:Int, remaining:Float, live:Bool):Void {
		var ew = Math.max(1, el.edgeWidth * vectorScale);
		var dist = el.edgeSide == AuraCanvasElement.EDGE_OUTER ? ew * 0.5 : (el.edgeSide == AuraCanvasElement.EDGE_INNER ? -ew * 0.5 : 0.0);
		var f = live ? el.edgeVisible(remaining) : 1;
		if (f <= 0.002) return;
		var x = ox + el.xAt(sid) * vectorScale, y = oy + el.yAt(sid) * vectorScale;
		var w = el.wAt(sid) > 1 ? el.wAt(sid) * vectorScale : cw, h = el.hAt(sid) > 1 ? el.hAt(sid) * vectorScale : ch;
		var rot = el.kind == AuraCanvasElement.KIND_ICON ? 0.0 : el.rotationAt(sid);
		var clipped = f < 0.999;
		if (clipped) {
			var e = AuraCanvasElement.rotatedHalfExtent(w, h, rot);
			var mx = x + w * 0.5, my = y + h * 0.5, pad = ew + 2;
			var x0 = mx - e.hx, x1 = mx + e.hx, y0 = my - e.hy, y1 = my + e.hy;
			var pmin:Dynamic, pmax:Dynamic;
			switch (el.edgeDir) {
				case AuraCanvasElement.DIR_DOWN: pmin = ImGui.vec2(x0 - pad, y0 - pad); pmax = ImGui.vec2(x1 + pad, y0 + (y1 - y0) * f);
				case AuraCanvasElement.DIR_LEFT: pmin = ImGui.vec2(x1 - (x1 - x0) * f, y0 - pad); pmax = ImGui.vec2(x1 + pad, y1 + pad);
				case AuraCanvasElement.DIR_RIGHT: pmin = ImGui.vec2(x0 - pad, y0 - pad); pmax = ImGui.vec2(x0 + (x1 - x0) * f, y1 + pad);
				default: pmin = ImGui.vec2(x0 - pad, y1 - (y1 - y0) * f); pmax = ImGui.vec2(x1 + pad, y1 + pad);
			}
			ImGui.ImDrawList_PushClipRect(dl, pmin, pmax, true);
		}
		try drawEdgeBody(dl, el, x, y, w, h, ew, dist, rot, col) catch (err:Dynamic) { if (clipped) ImGui.ImDrawList_PopClipRect(dl); throw err; }
		if (clipped) ImGui.ImDrawList_PopClipRect(dl);
	}

	static function drawEdgeBody(dl:Dynamic, el:AuraCanvasElement, x:Float, y:Float, w:Float, h:Float, ew:Float, dist:Float, rot:Float, col:Int):Void {
		if (el.kind == AuraCanvasElement.KIND_SHAPE) {
			// Shapes already know how to outline themselves: grow or shrink the box by the offset.
			var bw = w + dist * 2, bh = h + dist * 2;
			if (bw >= 2 && bh >= 2) drawCanvasShape(dl, el.content, x - dist, y - dist, bw, bh, col, ew, rot, el.sides);
			return;
		}
		var loops:Array<Array<Float>>;
		var closed = true;
		if (el.kind == AuraCanvasElement.KIND_PATH) {
			if (el.path == null) return;
			loops = [el.path.flatPoints()];
			closed = el.path.closed;
		} else {
			var c = GameIcons.contourFor(el.content);
			loops = c != null && c.length > 0 ? c : [EDGE_BOX];
		}
		var mx = x + w * 0.5, my = y + h * 0.5;
		var r = rot * Math.PI / 180, cr = Math.cos(r), sr = Math.sin(r);
		for (loop in loops) {
			var n = loop.length >> 1;
			if (n < 2) continue;
			var pts:Array<Float> = [];
			for (i in 0...n) { pts.push(x + loop[i * 2] * w); pts.push(y + loop[i * 2 + 1] * h); }
			if (closed && n >= 3 && dist != 0) pts = AuraPolyLoop.offset(AuraPolyLoop.insideLeft(pts), dist);
			var m = Std.int(Math.min(AuraVectorPath.MAX_FLAT_POINTS, pts.length >> 1));
			for (i in 0...m) {
				var px = pts[i * 2], py = pts[i * 2 + 1];
				if (rot != 0) { var dx = px - mx, dy = py - my; px = mx + dx * cr - dy * sr; py = my + dx * sr + dy * cr; }
				edgePts.setF32(i * 8, px);
				edgePts.setF32(i * 8 + 4, py);
			}
			ImGui.ImDrawList_AddPolyline(dl, edgePts, m, col, ew, closed && m >= 3 ? imgui.Enums.ImDrawFlags.Closed : 0);
		}
	}

	/** Largest flattened outline drawn: 512 nodes at 2 curve steps (see AuraVectorPath.flatPoints). */
	static inline var PATH_PT_MAX:Int = AuraVectorPath.MAX_FLAT_POINTS;
	static var pathPts:hl.Bytes = new hl.Bytes(8 * PATH_PT_MAX);
	static inline var PATH_GRAD_STRIPS:Int = 12;

	/**
	 * Vector layer: the cached outline is scaled into the box, rotated about its centre and drawn as a concave
	 * fill plus an optional stroke. A fade (`col2`) clips the fill into strips, as for plain shapes.
	 */
	static function drawVectorPath(dl:Dynamic, path:AuraVectorPath, x:Float, y:Float, w:Float, h:Float, fill:Bool, col:Int,
			col2:Null<Int>, gradDir:Int, strokeW:Float, strokeCol:Int, rotation:Float):Void {
		var flat = path.flatPoints();
		var n = Std.int(Math.min(PATH_PT_MAX, flat.length >> 1));
		if (n < 2) return;
		var cx = x + w * 0.5, cy = y + h * 0.5;
		var r = rotation * Math.PI / 180, cr = Math.cos(r), sr = Math.sin(r);
		for (i in 0...n) {
			var px = x + flat[i * 2] * w, py = y + flat[i * 2 + 1] * h;
			if (rotation != 0) { var dx = px - cx, dy = py - cy; px = cx + dx * cr - dy * sr; py = cy + dx * sr + dy * cr; }
			pathPts.setF32(i * 8, px);
			pathPts.setF32(i * 8 + 4, py);
		}
		if (fill && n >= 3) {
			if (col2 == null) ImGui.ImDrawList_AddConcavePolyFilled(dl, pathPts, n, col);
			else {
				var e = AuraCanvasElement.rotatedHalfExtent(w, h, rotation);
				var x0 = cx - e.hx - 1, y0 = cy - e.hy - 1, x1 = cx + e.hx + 1, y1 = cy + e.hy + 1;
				var end:Int = col2;
				// Every strip re-triangulates the whole outline, so busy outlines get fewer, wider strips.
				var strips = n > 256 ? 5 : (n > 96 ? 8 : PATH_GRAD_STRIPS);
				for (k in 0...strips) {
					var c = lerpPacked(col, end, (k + 0.5) / strips);
					var a0 = k / strips, a1 = (k + 1) / strips, over = k < strips - 1 ? 1 : 0;
					var pmin = gradDir == 1 ? ImGui.vec2(x0 + (x1 - x0) * a0, y0) : ImGui.vec2(x0, y0 + (y1 - y0) * a0);
					var pmax = gradDir == 1 ? ImGui.vec2(x0 + (x1 - x0) * a1 + over, y1) : ImGui.vec2(x1, y0 + (y1 - y0) * a1 + over);
					ImGui.ImDrawList_PushClipRect(dl, pmin, pmax, true);
					ImGui.ImDrawList_AddConcavePolyFilled(dl, pathPts, n, c);
					ImGui.ImDrawList_PopClipRect(dl);
				}
			}
		}
		if (strokeW > 0) ImGui.ImDrawList_AddPolyline(dl, pathPts, n, strokeCol, Math.max(1, strokeW), path.closed ? imgui.Enums.ImDrawFlags.Closed : 0);
	}

	/** Scratch polygon for shapes: 8 bytes per point, sized for a rotated rounded rectangle, ellipse or 12-point star. */
	static inline var POLY_MAX:Int = 96;
	static var polyPts:hl.Bytes = new hl.Bytes(8 * POLY_MAX);
	static var polySub:hl.Bytes = new hl.Bytes(8 * 8);
	static var polyN:Int = 0;
	static inline var GRAD_STRIPS:Int = 24;
	static var CHEVRON_UPPER:Array<Int> = [0, 1, 2, 5];
	static var CHEVRON_LOWER:Array<Int> = [5, 2, 3, 4];

	static inline function polyPoint(px:Single, py:Single):Void {
		if (polyN >= POLY_MAX) return;
		polyPts.setF32(polyN * 8, px);
		polyPts.setF32(polyN * 8 + 4, py);
		polyN++;
	}

	/** Rotate the buffered polygon about (cx, cy) by `deg` degrees clockwise (screen y points down). */
	static function polyRotate(cx:Float, cy:Float, deg:Float):Void {
		var r = deg * Math.PI / 180, c = Math.cos(r), sn = Math.sin(r);
		for (i in 0...polyN) {
			var dx = polyPts.getF32(i * 8) - cx, dy = polyPts.getF32(i * 8 + 4) - cy;
			polyPts.setF32(i * 8, cx + dx * c - dy * sn);
			polyPts.setF32(i * 8 + 4, cy + dx * sn + dy * c);
		}
	}

	static function polyRoundedRect(x:Float, y:Float, w:Float, h:Float, rad:Float):Void {
		var corners = [[x + w - rad, y + rad, -90.0], [x + w - rad, y + h - rad, 0.0], [x + rad, y + h - rad, 90.0], [x + rad, y + rad, 180.0]];
		for (cn in corners) for (k in 0...6) {
			var t = (cn[2] + k * 15) * Math.PI / 180;
			polyPoint(cn[0] + Math.cos(t) * rad, cn[1] + Math.sin(t) * rad);
		}
	}

	/** Convex fill of a subset of the buffered points (chevron halves). */
	static function fillSubset(dl:Dynamic, idx:Array<Int>, col:Int):Void {
		for (k in 0...idx.length) {
			polySub.setF32(k * 8, polyPts.getF32(idx[k] * 8));
			polySub.setF32(k * 8 + 4, polyPts.getF32(idx[k] * 8 + 4));
		}
		ImGui.ImDrawList_AddConvexPolyFilled(dl, polySub, idx.length, col);
	}

	static inline function lerpChannel(a:Int, b:Int, t:Float):Int return Std.int(a + (b - a) * t + 0.5);

	/** Component-wise blend of two packed colours; channel order does not matter. */
	static function lerpPacked(a:Int, b:Int, t:Float):Int {
		return (lerpChannel((a >>> 24) & 0xFF, (b >>> 24) & 0xFF, t) << 24) | (lerpChannel((a >>> 16) & 0xFF, (b >>> 16) & 0xFF, t) << 16)
			| (lerpChannel((a >>> 8) & 0xFF, (b >>> 8) & 0xFF, t) << 8) | lerpChannel(a & 0xFF, b & 0xFF, t);
	}

	/**
	 * Canvas plate in the element box. stroke 0 fills, otherwise outlines at that thickness (rings use it as their
	 * thickness). rotation is degrees. `col2` blends a fill from `col` to `col2` along the screen axis `gradDir`
	 * (0 down, 1 across) by clipping the shape into thin strips.
	 */
	public static function drawCanvasShape(dl:Dynamic, shape:String, x:Single, y:Single, w:Single, h:Single,
			col:Int, stroke:Float, rotation:Float = 0, sides:Int = 5, col2:Null<Int> = null, gradDir:Int = 0):Void {
		var gradient = col2 != null && shape != "line" && (stroke <= 0 || shape == "ring");
		if (!gradient) {
			drawShapeBody(dl, shape, x, y, w, h, col, stroke, rotation, sides);
			return;
		}
		var e = AuraCanvasElement.rotatedHalfExtent(w, h, rotation);
		var cx = x + w * 0.5, cy = y + h * 0.5;
		var x0 = cx - e.hx - 1, y0 = cy - e.hy - 1, x1 = cx + e.hx + 1, y1 = cy + e.hy + 1;
		var end:Int = col2;
		for (k in 0...GRAD_STRIPS) {
			var c = lerpPacked(col, end, (k + 0.5) / GRAD_STRIPS);
			var a0 = k / GRAD_STRIPS, a1 = (k + 1) / GRAD_STRIPS;
			// One pixel of overlap hides seams between neighbouring strips.
			var pmin = gradDir == 1 ? ImGui.vec2(x0 + (x1 - x0) * a0, y0) : ImGui.vec2(x0, y0 + (y1 - y0) * a0);
			var pmax = gradDir == 1 ? ImGui.vec2(x0 + (x1 - x0) * a1 + (k < GRAD_STRIPS - 1 ? 1 : 0), y1) : ImGui.vec2(x1, y0 + (y1 - y0) * a1 + (k < GRAD_STRIPS - 1 ? 1 : 0));
			ImGui.ImDrawList_PushClipRect(dl, pmin, pmax, true);
			try drawShapeBody(dl, shape, x, y, w, h, c, stroke, rotation, sides) catch (err:Dynamic) { ImGui.ImDrawList_PopClipRect(dl); throw err; }
			ImGui.ImDrawList_PopClipRect(dl);
		}
	}

	static function drawShapeBody(dl:Dynamic, shape:String, x:Single, y:Single, w:Single, h:Single,
			col:Int, stroke:Float, rotation:Float, sides:Int):Void {
		var outline = stroke > 0;
		var t:Single = outline ? stroke : 1;
		var cx:Single = x + w * 0.5;
		var cy:Single = y + h * 0.5;
		var rotated = rotation != 0;
		var radians = rotation * Math.PI / 180;
		var star = false;
		var chevron = false;
		switch (shape) {
			case "circle":
				if (!rotated) {
					var r = ImGui.vec2(w * 0.5, h * 0.5);
					if (outline) ImGui.ImDrawList_AddEllipse(dl, ImGui.vec2(cx, cy), r, col, 0, 0, t);
					else ImGui.ImDrawList_AddEllipseFilled(dl, ImGui.vec2(cx, cy), r, col);
					return;
				}
				polyN = 0;
				for (k in 0...48) { var a = k * Math.PI * 2 / 48; polyPoint(cx + Math.cos(a) * w * 0.5, cy + Math.sin(a) * h * 0.5); }
			case "ring":
				var thick:Single = outline ? stroke : Math.max(1, Math.min(w, h) * 0.18);
				ImGui.ImDrawList_AddEllipse(dl, ImGui.vec2(cx, cy), ImGui.vec2(Math.max(1, w * 0.5 - thick * 0.5), Math.max(1, h * 0.5 - thick * 0.5)), col, radians, 0, thick);
				return;
			case "rounded":
				var rr:Single = Math.min(w, h) * 0.22;
				if (!rotated) {
					if (outline) ImGui.ImDrawList_AddRect(dl, ImGui.vec2(x, y), ImGui.vec2(x + w, y + h), col, rr, t);
					else ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x, y), ImGui.vec2(x + w, y + h), col, rr);
					return;
				}
				polyN = 0;
				polyRoundedRect(x, y, w, h, rr);
			case "line":
				var lineW:Single = Math.max(1, outline ? t : h);
				if (!rotated) {
					ImGui.ImDrawList_AddLine(dl, ImGui.vec2(x, cy), ImGui.vec2(x + w, cy), col, lineW);
					return;
				}
				polyN = 0;
				polyPoint(x, cy); polyPoint(x + w, cy);
				polyRotate(cx, cy, rotation);
				ImGui.ImDrawList_AddLine(dl, ImGui.vec2(polyPts.getF32(0), polyPts.getF32(4)), ImGui.vec2(polyPts.getF32(8), polyPts.getF32(12)), col, lineW);
				return;
			case "diamond":
				polyN = 0;
				polyPoint(cx, y); polyPoint(x + w, cy); polyPoint(cx, y + h); polyPoint(x, cy);
			case "hex":
				polyN = 0;
				var q:Single = w * 0.25;
				polyPoint(x + q, y); polyPoint(x + w - q, y); polyPoint(x + w, cy);
				polyPoint(x + w - q, y + h); polyPoint(x + q, y + h); polyPoint(x, cy);
			case "triangle":
				polyN = 0;
				polyPoint(cx, y); polyPoint(x + w, y + h); polyPoint(x, y + h);
			case "polygon":
				polyN = 0;
				var n = AuraCanvasElement.clampSides(sides);
				for (k in 0...n) { var a = -Math.PI * 0.5 + k * Math.PI * 2 / n; polyPoint(cx + Math.cos(a) * w * 0.5, cy + Math.sin(a) * h * 0.5); }
			case "star":
				polyN = 0;
				star = true;
				var pts = AuraCanvasElement.clampSides(sides);
				for (k in 0...pts * 2) {
					var a = -Math.PI * 0.5 + k * Math.PI / pts, rad = k % 2 == 0 ? 0.5 : 0.22;
					polyPoint(cx + Math.cos(a) * w * rad, cy + Math.sin(a) * h * rad * (k % 2 == 0 ? 1 : 1));
				}
			case "chevron":
				polyN = 0;
				chevron = true;
				polyPoint(x, y); polyPoint(x + w * 0.6, y); polyPoint(x + w, cy);
				polyPoint(x + w * 0.6, y + h); polyPoint(x, y + h); polyPoint(x + w * 0.4, cy);
			default:
				if (!rotated) {
					if (outline) ImGui.ImDrawList_AddRect(dl, ImGui.vec2(x, y), ImGui.vec2(x + w, y + h), col, 0, t);
					else ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x, y), ImGui.vec2(x + w, y + h), col);
					return;
				}
				polyN = 0;
				polyPoint(x, y); polyPoint(x + w, y); polyPoint(x + w, y + h); polyPoint(x, y + h);
		}
		if (rotated) polyRotate(cx, cy, rotation);
		if (outline) {
			ImGui.ImDrawList_AddPolyline(dl, polyPts, polyN, col, t, imgui.Enums.ImDrawFlags.Closed);
		} else if (star) {
			// Star-shaped around its centre, so a triangle fan fills it without a concave tessellator.
			var c = ImGui.vec2(cx, cy);
			for (k in 0...polyN) {
				var j = (k + 1) % polyN;
				ImGui.ImDrawList_AddTriangleFilled(dl, ImGui.vec2(polyPts.getF32(k * 8), polyPts.getF32(k * 8 + 4)),
					ImGui.vec2(polyPts.getF32(j * 8), polyPts.getF32(j * 8 + 4)), c, col);
			}
		} else if (chevron) {
			fillSubset(dl, CHEVRON_UPPER, col);
			fillSubset(dl, CHEVRON_LOWER, col);
		} else ImGui.ImDrawList_AddConvexPolyFilled(dl, polyPts, polyN, col);
	}

	static function drawIcon(dl:Dynamic, a:AuraDef, x:Single, y:Single, w:Single, h:Single,
			progress:Float, alpha:Float, vectorScale:Float):Void {
		var labelH:Single = a.showLabel != null && a.showLabel.get() ? Math.min(22, h * 0.24) : 0;
		var iconH:Single = h - labelH;
		var side:Single = w < iconH ? w : iconH;
		var ix = x + (w - side) * 0.5;
		var iy = y + (iconH - side) * 0.5;
		if (a.showIcon.get()) {
		var stem = a.preferredIconId();
		var tex = GameIcons.get(stem);
		var tint = ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 1, 1, alpha));
		if (!GameIcons.draw(dl, tex, ix, iy, side, tint)) {
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(ix, iy), ImGui.vec2(ix + side, iy + side),
				ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.1, 0.12, 0.16, alpha * 0.85)), 6);
			var missing = stem.length > 0 ? "?" : "+";
			var mts = ImGui.calcTextSize(missing);
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(ix + (side - mts.x) * 0.5, iy + (side - mts.y) * 0.5),
				ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.7, 0.75, 0.82, alpha)), missing);
		}
		}
		if (faceFx && faceGlow) {
			drawGlowRect(dl, ix - 2, iy - 2, side + 4, side + 4, a, alpha);
		}
		if (a.progressRing != null && a.progressRing.get() && progress > 0.001
			&& (progress < 0.999 || a.gaugeFillMode == AuraGaugePolicy.FILL || a.timerMode == AuraTimer.MODE_UP)) {
			var rad:Single = side * 0.46;
			RingGauge.draw(dl, ImGui.vec2(ix + side * 0.5, iy + side * 0.5), rad, progress,
				ImGui.vec4(0.95, 0.82, 0.28, 0.9 * alpha), "", vectorScale);
		}
		if (faceFx && wantFuse(a, progress)) {
			if (a.fuseBottom != null && a.fuseBottom.get())
				drawFuseBottom(dl, ix, iy, side, side, progress, alpha);
			else
				drawFuse(dl, ix, iy, side, progress, alpha);
		}

		if (labelH > 0) {
			var label = a.displayLabel();
			var ts = ImGui.calcTextSize(label);
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(x + (w - ts.x) * 0.5, y + h - labelH + 2),
				ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 1, 1, alpha)), label);
		}
	}

	static function drawGlowRect(dl:Dynamic, x:Single, y:Single, w:Single, h:Single, a:AuraDef, alpha:Float):Void {
		if (alpha <= 0.02)
			return;
		AuraGlowRenderer.draw(dl, a, x, y, w, h, alpha);
	}

	/** Vertical fuse on the right edge: filled height = remaining ratio, drains top→bottom. */
	static function drawFuse(dl:Dynamic, ix:Single, iy:Single, side:Single, progress:Float, alpha:Float):Void {
		var p = clamp01(progress);
		var fw:Single = Math.max(3, side * 0.08);
		var pad:Single = 2;
		var x0 = ix + side - fw - pad;
		var y0 = iy + pad;
		var y1 = iy + side - pad;
		var fullH = y1 - y0;
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x0, y0), ImGui.vec2(x0 + fw, y1),
			ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.05, 0.06, 0.08, 0.75 * alpha)), 2);
		if (p > 0.001) {
			var fillH = fullH * p;
			var fy0 = y1 - fillH;
			var hot = p < 0.25;
			var col = hot
				? ImGui.vec4(0.95, 0.35, 0.2, 0.95 * alpha)
				: ImGui.vec4(0.95, 0.78, 0.28, 0.92 * alpha);
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x0, fy0), ImGui.vec2(x0 + fw, y1),
				ImGui.colorConvertFloat4ToU32(col), 2);
		}
	}

	/** Bottom strip fuse: remaining ratio fills left→right. */
	static function drawFuseBottom(dl:Dynamic, x:Single, y:Single, w:Single, h:Single, progress:Float, alpha:Float):Void {
		var p = clamp01(progress);
		var barH:Single = Math.max(4, h * 0.08);
		var y0 = y + h - barH;
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x, y0), ImGui.vec2(x + w, y0 + barH),
			ImGui.colorConvertFloat4ToU32(ImGui.vec4(0, 0, 0, 0.45 * alpha)), 0);
		if (p > 0.001) {
			var hot = p < 0.25;
			var col = hot
				? ImGui.vec4(0.95, 0.35, 0.2, 0.95 * alpha)
				: ImGui.vec4(0.0, 1.0, 0.8, 0.92 * alpha);
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x, y0), ImGui.vec2(x + w * p, y0 + barH),
				ImGui.colorConvertFloat4ToU32(col), 0);
		}
	}

	/** mm:ss above 60s, whole seconds 10-60s, one decimal below 10s. Empty when unknown. */
	public static function formatRemain(secs:Float):String {
		if (!Math.isFinite(secs) || secs < 0)
			return "";
		if (secs >= 60) {
			var m = Std.int(secs / 60);
			var s = Std.int(secs % 60);
			return m + ":" + (s < 10 ? "0" + s : Std.string(s));
		}
		if (secs >= 10)
			return Std.string(Math.ceil(secs - 0.001));
		return Std.string(Math.round(secs * 10) / 10);
	}

	/**
	 * Explicit toggle, or auto for any known remaining under the published ceiling.
	 *
	 * A visible status always earns a mark: non-expiring ones draw the infinity glyph
	 * rather than nothing, since anything past SkillRemain's hour-long leftover cap is
	 * permanent in practice. A user-set ceiling asks for short timers only, and an
	 * infinite span has no seconds to compare against it, so the ceiling suppresses the glyph.
	 */
	static function wantCountdown(a:AuraDef):Bool {
		return AuraPresentationPolicy.countdown(a.showCountdown.get(),a.useGlobalCountdown.get(),countdownAll,faceLeft,faceInf,countdownCeiling);
	}

	/** A fuse is artwork only when one of its explicit display options is enabled. */
	static function wantFuse(a:AuraDef, progress:Float):Bool {
		return (a.showFuse != null && a.showFuse.get()) || (a.fuseBottom != null && a.fuseBottom.get());
	}

	/** Substitute independent live stack and activation count values. */
	public static function formatTokens(content:String, a:AuraDef, stacks:Int = 0, counter:Int = 0, wholeTime:Bool = false):String {
		if (content == null || content.length == 0)
			return "";
		var s = content;
		if (s.indexOf("{name}") >= 0)
			s = s.split("{name}").join(a != null ? a.displayLabel() : "");
		if (s.indexOf("{time}") >= 0) {
			var t = "";
			if (faceInf)
				t = "inf";
			else if (Math.isFinite(faceLeft) && faceLeft >= 0)
				t = AuraTimeText.token(faceLeft, false, wholeTime);
			s = s.split("{time}").join(t);
		}
		return AuraBadgePolicy.countTokens(s, stacks, counter);
	}

	/** Apply opacity to 0xAARRGGBB packed color → ImGui U32. */
	static function applyAlphaToPacked(packed:Int, alpha:Float):Int {
		var a = ((packed >>> 24) & 0xFF) / 255.0;
		var r = ((packed >>> 16) & 0xFF) / 255.0;
		var g = ((packed >>> 8) & 0xFF) / 255.0;
		var b = (packed & 0xFF) / 255.0;
		a *= clamp01(alpha);
		return ImGui.colorConvertFloat4ToU32(ImGui.vec4(r, g, b, a));
	}

	static inline function clamp01(v:Float):Float {
		return v < 0 ? 0 : (v > 1 ? 1 : v);
	}
}
