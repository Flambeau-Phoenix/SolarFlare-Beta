package solarflare.chaincast;

import imgui.ImGui;
import solarflare.ui.GameIcons;

/**
 * Shared Chaincast badge + rail. Live overlay and Resource Tracker preview
 * both call this with frozen ints — never reads ChaincastCache.
 */
class ChaincastRenderer {
	static inline var GAP:Single = 6;
	static inline var ACCUM_MAX:Int = 4;
	static inline var SLOT_COUNT:Int = 5;

	/** Style 0: icon rail (original). */
	public static inline var STYLE_RAIL:Int = 0;
	/** Style 1: orbital ring — 4 charge nodes around a core. */
	public static inline var STYLE_ORBIT:Int = 1;
	/** Style 2: slim segmented bar (smallest, no icons). */
	public static inline var STYLE_SEGMENT:Int = 2;
	/** Style 3: tiny linked dots (minimal). */
	public static inline var STYLE_DOTS:Int = 3;
	/** Style 4: linked diamonds (medium). */
	public static inline var STYLE_DIAMOND:Int = 4;
	/** Style 5: half-ring arc gauge (wide/tall). */
	public static inline var STYLE_ARC:Int = 5;
	public static inline var STYLE_REACTOR:Int = 6;
	/** Style 7 (exotic): animated lightning conduit between nodes. */
	public static inline var STYLE_LIGHTNING:Int = 7;
	public static inline var STYLE_ORRERY:Int = 8;
	public static inline var STYLE_PHOENIX:Int = 9;
	public static inline var STYLE_COUNT:Int = 10;
	public static final STYLE_NAMES:Array<String> = ["Rail", "Orbit", "Segment", "Dots", "Diamond", "Arc", "Reactor", "Lightning", "Astral Orrery", "Phoenix Crest"];
	static final COUNT_LABELS = ["0 / 4", "1 / 4", "2 / 4", "3 / 4", "4 / 4"];

	public static inline function isFlagship(style:Int):Bool return style == STYLE_ORRERY || style == STYLE_PHOENIX;

	/** Shared measurement for the HUD and its preview; legacy style IDs remain stable. */
	public static function headHeight(style:Int, width:Single):Single {
		return switch (style) {
			case STYLE_ORRERY, STYLE_PHOENIX: 124;
			case STYLE_REACTOR: 64;
			case STYLE_ORBIT: 54;
			case STYLE_ARC: 74;
			default: 30;
		};
	}

	/** Bounded vector art: four charge lobes plus an independent linked-skill seal. */
	static function drawFlagship(style:Int, w:Single, h:Single, stacks:Int, ready:Bool,
			showCount:Bool, pulse:Bool, skill:ChaincastSkillState):Void {
		var o = ImGui.getCursorScreenPos();
		var dl = ImGui.getWindowDrawList();
		var cx:Single = o.x + w * 0.5;
		var cy:Single = o.y + 49;
		var filled = clampStacks(stacks);
		var t = now();
		var p = pulseVal(ready || pulse);
		var gold = style == STYLE_PHOENIX;
		var accent = gold ? u32(1, 0.68, 0.24, 0.95) : u32(0.48, 0.84, 1, 0.95);
		var bright = gold ? u32(1, 0.92, 0.64, 1) : u32(0.86, 0.96, 1, 1);
		var dim = gold ? u32(0.34, 0.26, 0.18, 0.9) : u32(0.22, 0.29, 0.43, 0.9);
		var glow = gold ? u32(1, 0.48, 0.12, 0.12 + 0.10 * p) : u32(0.25, 0.54, 1, 0.12 + 0.10 * p);
		if (gold) {
			// Each wing has two separate feather blades: four unmistakable charges.
			var span:Single = Math.min(126, w * 0.5 - 7);
			for (i in 0...4) {
				var side = i < 2 ? -1 : 1;
				var tier = i % 2;
				var lit = ready || i < filled;
				var ax:Single = cx + side * 31;
				var ay:Single = cy + tier * 12 - 9;
				var bx:Single = cx + side * (span - tier * 18);
				var by:Single = cy - 35 + tier * 28;
				var dx:Single = cx + side * (span * 0.58 - tier * 10);
				var dy:Single = cy + 14 + tier * 14;
				ImGui.ImDrawList_AddTriangleFilled(dl, ImGui.vec2(ax, ay), ImGui.vec2(bx, by), ImGui.vec2(dx, dy),
					lit ? u32(0.38, 0.19, 0.07, 0.9) : u32(0.08, 0.07, 0.08, 0.92));
				if (lit) ImGui.ImDrawList_AddLine(dl, ImGui.vec2(ax, ay), ImGui.vec2(bx, by), glow, 9);
				ImGui.ImDrawList_AddLine(dl, ImGui.vec2(ax, ay), ImGui.vec2(bx, by), lit ? bright : dim, 2);
				ImGui.ImDrawList_AddLine(dl, ImGui.vec2(bx, by), ImGui.vec2(dx, dy), lit ? accent : dim, 1.5);
				ImGui.ImDrawList_AddLine(dl, ImGui.vec2(dx, dy), ImGui.vec2(ax, ay), lit ? accent : dim, 1);
				ImGui.ImDrawList_AddLine(dl, ImGui.vec2(ax, ay + 4), ImGui.vec2(dx, dy - 5), lit ? accent : dim, 1);
				if (lit) {
					var f:Float = (t * 0.35 + tier * 0.5) % 1;
					ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(ax + (bx - ax) * f, ay + (by - ay) * f), 2, bright, 8);
				}
			}
			// Crown and tail frame the skill seal without competing with the four feathers.
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(cx - 12, cy - 32), ImGui.vec2(cx, cy - 44), accent, 1.5);
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(cx, cy - 44), ImGui.vec2(cx + 12, cy - 32), accent, 1.5);
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(cx - 13, cy + 33), ImGui.vec2(cx, cy + 44), dim, 1.5);
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(cx, cy + 44), ImGui.vec2(cx + 13, cy + 33), dim, 1.5);
		} else {
			// Astrolabe: fixed charge quadrants, counter-rotating broken inner orbit.
			for (i in 0...4) {
				var a = -Math.PI * 0.5 + i * Math.PI * 0.5 + 0.12;
				var b = a + Math.PI * 0.5 - 0.24;
				var lit = ready || i < filled;
				arcPoly(dl, cx, cy, 41, a, b, u32(0.03, 0.04, 0.08, 0.96), 8, 12);
				if (lit) arcPoly(dl, cx, cy, 41, a, b, glow, 10, 12);
				arcPoly(dl, cx, cy, 41, a, b, lit ? accent : dim, 4, 12);
				var mid = (a + b) * 0.5;
				ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx + Math.cos(mid) * 41, cy + Math.sin(mid) * 41), 3, lit ? bright : dim, 4);
				arcPoly(dl, cx, cy, 33, -t * 0.32 + a, -t * 0.32 + a + 0.5, dim, 1, 6);
			}
			// Symmetric constellation arms stay within the available width.
			var span:Single = Math.min(112, w * 0.5 - 6);
			for (i in 0...2) {
				var side = i == 0 ? -1 : 1;
				ImGui.ImDrawList_AddLine(dl, ImGui.vec2(cx + side * 49, cy), ImGui.vec2(cx + side * span, cy), dim, 1);
				ImGui.ImDrawList_AddCircle(dl, ImGui.vec2(cx + side * (span - 12), cy), 5, ready ? bright : accent, 4, 1.5);
				ImGui.ImDrawList_AddLine(dl, ImGui.vec2(cx + side * 60, cy - 7), ImGui.vec2(cx + side * 60, cy + 7), accent, 1);
			}
			var a = t * (ready ? 1.1 : 0.35);
			ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx + Math.cos(a) * 46, cy + Math.sin(a) * 46), 2, bright, 8);
		}
		// Chaincast ready highlights the ornament; it never overrides the skill cooldown.
		if (ready) ImGui.ImDrawList_AddCircle(dl, ImGui.vec2(cx, cy), 29, glow, 40, 7);
		drawSkillSeal(dl, cx, cy, skill);
		var label = skill == null ? "LINK SKILL" : skill.label;
		centerText(dl, cx, o.y + 77, label, bright);
		if (showCount) centerText(dl, cx, o.y + 103, ready ? "CHAIN READY" : COUNT_LABELS[filled], ready ? bright : accent);
		ImGui.dummy(ImGui.vec2(w, h));
	}

	static function centerText(dl:Dynamic, cx:Single, y:Single, text:String, color:Int):Void {
		var ts = ImGui.calcTextSize(text);
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(cx - ts.x * 0.5 + 1, y + 1), u32(0, 0, 0, 0.95), text);
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(cx - ts.x * 0.5, y), color, text);
	}

	/** Geometric glyphs remain legible without checkmark font coverage. */
	static function drawSkillSeal(dl:Dynamic, cx:Single, cy:Single, skill:ChaincastSkillState):Void {
		var state = skill == null ? ChaincastSkillState.UNLINKED : skill.state;
		var col = state == ChaincastSkillState.READY ? u32(0.45, 1, 0.72, 1) :
			(state == ChaincastSkillState.COOLDOWN ? u32(1, 0.43, 0.37, 1) : u32(0.61, 0.66, 0.76, 1));
		ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, cy), 25, u32(0.025, 0.035, 0.065, 0.96), 40);
		ImGui.ImDrawList_AddCircle(dl, ImGui.vec2(cx, cy), 25, u32(0.29, 0.34, 0.44, 0.95), 40, 2);
		if (skill != null && skill.progress > 0)
			arcPoly(dl, cx, cy, 25, -Math.PI * 0.5, -Math.PI * 0.5 + Math.PI * 2 * skill.progress, col, 2.5, 32);
		if (state == ChaincastSkillState.READY) {
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(cx - 10, cy), ImGui.vec2(cx - 3, cy + 7), col, 3);
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(cx - 3, cy + 7), ImGui.vec2(cx + 11, cy - 8), col, 3);
		} else if (state == ChaincastSkillState.COOLDOWN) {
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(cx - 8, cy - 8), ImGui.vec2(cx + 8, cy + 8), col, 3);
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(cx + 8, cy - 8), ImGui.vec2(cx - 8, cy + 8), col, 3);
		} else centerText(dl, cx, cy - ImGui.getTextLineHeight() * 0.5, state == ChaincastSkillState.UNKNOWN ? "?" : "--", col);
	}

	static function drawStyle(style:Int, w:Single, h:Single, stacks:Int, ready:Bool, pulse:Bool):Void {
		switch (style) {
			case STYLE_ORBIT:
				drawOrbit(w, h, stacks, ready, pulse);
			case STYLE_SEGMENT:
				drawSegment(w, h, stacks, ready, pulse);
			case STYLE_DOTS:
				drawChain(w, h, stacks, ready, pulse, 20, 0.22);
			case STYLE_DIAMOND:
				drawChain(w, h, stacks, ready, pulse, 4, 0.34);
			case STYLE_ARC:
				drawArc(w, h, stacks, ready, pulse);
			case STYLE_REACTOR:
				drawReactor(w, h, stacks, ready, pulse);
			case STYLE_LIGHTNING:
				drawLightning(w, h, stacks, ready, pulse);
			default:
				drawBlocks(w, h, stacks, ready, pulse);
		}
	}

	static inline function clampStacks(s:Int):Int {
		return s < 0 ? 0 : (s > ACCUM_MAX ? ACCUM_MAX : s);
	}

	static inline function now():Float {
		try
			return haxe.Timer.stamp()
		catch (_:Dynamic)
			return 0;
	}

	/** Polyline arc from a0 to a1 (radians). */
	static function arcPoly(dl:Dynamic, cx:Single, cy:Single, r:Single, a0:Float, a1:Float, col:Int, th:Single, steps:Int):Void {
		var px:Single = cx + Math.cos(a0) * r;
		var py:Single = cy + Math.sin(a0) * r;
		for (k in 1...steps + 1) {
			var a:Float = a0 + (a1 - a0) * k / steps;
			var x:Single = cx + Math.cos(a) * r;
			var y:Single = cy + Math.sin(a) * r;
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(px, py), ImGui.vec2(x, y), col, th);
			px = x;
			py = y;
		}
	}

	/**
	 * Exotic: rotating reactor. 4 quadrant arcs on the outer ring (lit = stacks), counter-rotating
	 * hexagon, spark orbiting outer ring, core with spinning spokes when READY.
	 */
	static function drawReactor(rowW:Single, rowH:Single, stacks:Int, ready:Bool, pulse:Bool):Void {
		var filled = clampStacks(stacks);
		var h:Single = rowH < 40 ? 40 : rowH;
		var origin = ImGui.getCursorScreenPos();
		var dl = ImGui.getWindowDrawList();
		var p = pulseVal(ready || pulse);
		var t:Float = now();
		var cx:Single = origin.x + rowW * 0.5;
		var cy:Single = origin.y + h * 0.5;
		var R:Single = (rowW < h ? rowW : h) * 0.5 - 3;
		var spin:Float = t * (ready ? 1.6 : 0.5);
		var quad:Float = Math.PI * 0.5;

		// outer ring base
		ImGui.ImDrawList_AddCircle(dl, ImGui.vec2(cx, cy), R + 2, u32(0.04, 0.05, 0.09, 0.9), 48, 3);
		for (i in 0...ACCUM_MAX) {
			var lit = ready || i < filled;
			var a0:Float = spin + i * quad + 0.16;
			var a1:Float = spin + (i + 1) * quad - 0.16;
			if (lit) {
				arcPoly(dl, cx, cy, R, a0, a1, u32(0.30, 0.60, 1.0, 0.28 * (ready ? p : 1)), 7, 10);
				arcPoly(dl, cx, cy, R, a0, a1, u32(0.75, 0.92, 1.0, 0.95), 3, 10);
			} else
				arcPoly(dl, cx, cy, R, a0, a1, u32(0.20, 0.26, 0.36, 0.85), 2, 10);
		}
		// orbiting spark
		if (filled > 0 || ready) {
			var sa:Float = -t * 2.4;
			ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx + Math.cos(sa) * R, cy + Math.sin(sa) * R), 2.6, u32(1, 1, 1, 0.95), 10);
		}
		// inner hexagon, counter-rotating
		var hr:Single = R * 0.62;
		var ha:Float = -spin * 0.8;
		var hexLit = ready;
		for (k in 0...6) {
			var b0:Float = ha + k * Math.PI / 3;
			var b1:Float = ha + (k + 1) * Math.PI / 3;
			ImGui.ImDrawList_AddLine(dl,
				ImGui.vec2(cx + Math.cos(b0) * hr, cy + Math.sin(b0) * hr),
				ImGui.vec2(cx + Math.cos(b1) * hr, cy + Math.sin(b1) * hr),
				hexLit ? u32(0.62, 0.84, 1.0, 0.6 + 0.35 * p) : u32(0.28, 0.36, 0.48, 0.7), 1.5);
		}
		// core
		var coreR:Single = R * 0.30;
		if (ready) {
			ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, cy), coreR + 5, u32(0.45, 0.78, 1.0, 0.22 * p), 24);
			for (k in 0...6) {
				var sa2:Float = spin * 2 + k * Math.PI / 3;
				ImGui.ImDrawList_AddLine(dl, ImGui.vec2(cx, cy),
					ImGui.vec2(cx + Math.cos(sa2) * hr * 0.95, cy + Math.sin(sa2) * hr * 0.95),
					u32(0.55, 0.80, 1.0, 0.30 * p), 1);
			}
		}
		ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, cy), coreR,
			ready ? u32(0.30, 0.62, 1.0, 0.75 + 0.2 * p) : u32(0.05, 0.06, 0.10, 0.94), 20);
		ImGui.ImDrawList_AddCircle(dl, ImGui.vec2(cx, cy), coreR,
			ready ? u32(0.85, 0.95, 1.0, 0.9) : u32(0.28, 0.36, 0.48, 0.8), 20, 1.5);
		ImGui.dummy(ImGui.vec2(rowW, h));
	}

	/** Exotic: jagged animated lightning between nodes; energized between lit pairs, 8-spike burst on READY. */
	static function drawLightning(rowW:Single, rowH:Single, stacks:Int, ready:Bool, pulse:Bool):Void {
		var filled = clampStacks(stacks);
		var h:Single = rowH < 30 ? 30 : rowH;
		var origin = ImGui.getCursorScreenPos();
		var dl = ImGui.getWindowDrawList();
		var p = pulseVal(ready || pulse);
		var t:Float = now();
		var frame:Int = Math.floor(t * 14);
		var step:Single = rowW / SLOT_COUNT;
		var cy:Single = origin.y + h * 0.5;
		var amp:Single = h * 0.26;
		var subs:Int = 7;

		for (i in 0...ACCUM_MAX) {
			var xa:Single = origin.x + step * (i + 0.5);
			var xb:Single = origin.x + step * (i + 1.5);
			var energized = ready || i + 1 < filled;
			if (!energized) {
				ImGui.ImDrawList_AddLine(dl, ImGui.vec2(xa, cy), ImGui.vec2(xb, cy), u32(0.20, 0.26, 0.36, 0.55), 1);
				continue;
			}
			var lx:Single = xa;
			var ly:Single = cy;
			for (k in 1...subs + 1) {
				var fx:Single = xa + (xb - xa) * k / subs;
				var fy:Single = cy;
				if (k < subs) {
					var v:Float = Math.sin(i * 12.9898 + k * 78.233 + frame * 37.719) * 43758.5453;
					v = v - Math.floor(v);
					fy = cy + (v - 0.5) * 2 * amp;
				}
				ImGui.ImDrawList_AddLine(dl, ImGui.vec2(lx, ly), ImGui.vec2(fx, fy), u32(0.30, 0.60, 1.0, 0.25 * (ready ? p : 1)), 6);
				ImGui.ImDrawList_AddLine(dl, ImGui.vec2(lx, ly), ImGui.vec2(fx, fy), u32(0.85, 0.95, 1.0, 0.95), 1.5);
				lx = fx;
				ly = fy;
			}
		}
		// partial arc crackling toward next unlit node
		if (!ready && filled > 0 && filled < SLOT_COUNT) {
			var sx:Single = origin.x + step * (filled - 0.5);
			var v2:Float = Math.sin(filled * 91.7 + frame * 13.1) * 43758.5453;
			v2 = v2 - Math.floor(v2);
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(sx, cy),
				ImGui.vec2(sx + step * 0.35, cy + (v2 - 0.5) * amp * 2), u32(0.70, 0.90, 1.0, 0.7), 1.25);
		}
		var nr:Single = step * 0.2;
		if (nr > h * 0.3)
			nr = h * 0.3;
		for (i in 0...SLOT_COUNT) {
			var isReadySlot = i == ACCUM_MAX;
			var lit = isReadySlot ? ready : (ready || i < filled);
			var c = ImGui.vec2(origin.x + step * (i + 0.5), cy);
			var rr:Single = isReadySlot ? nr * 1.4 : nr;
			if (lit && isReadySlot) {
				for (k in 0...8) {
					var a:Float = k * Math.PI / 4 + t * 1.2;
					var len:Single = rr * (1.7 + 0.8 * Math.sin(t * 9 + k * 2.1));
					ImGui.ImDrawList_AddLine(dl, ImGui.vec2(c.x + Math.cos(a) * rr, c.y + Math.sin(a) * rr),
						ImGui.vec2(c.x + Math.cos(a) * len, c.y + Math.sin(a) * len), u32(0.80, 0.94, 1.0, 0.8), 1.5);
				}
			}
			ImGui.ImDrawList_AddCircleFilled(dl, c, rr,
				lit ? u32(0.30, 0.62, 1.0, 0.95) : u32(0.04, 0.05, 0.08, 0.94), 18);
			ImGui.ImDrawList_AddCircle(dl, c, rr,
				lit ? u32(0.90, 0.97, 1.0, 0.95) : u32(0.20, 0.26, 0.36, 0.90), 18, isReadySlot ? 2 : 1.5);
		}
		ImGui.dummy(ImGui.vec2(rowW, h));
	}

	static inline function pulseVal(on:Bool):Single {
		if (!on)
			return 1;
		try
			return 0.62 + 0.38 * Math.sin(haxe.Timer.stamp() * 7.5)
		catch (_:Dynamic)
			return 1;
	}

	/** Slim 4-segment bar + ready cap. Height ~ 40% of rowH (min 8). */
	static function drawSegment(rowW:Single, rowH:Single, stacks:Int, ready:Bool, pulse:Bool):Void {
		var filled = clampStacks(stacks);
		var h:Single = rowH * 0.4;
		if (h < 8)
			h = 8;
		var origin = ImGui.getCursorScreenPos();
		var dl = ImGui.getWindowDrawList();
		var p = pulseVal(ready || pulse);
		var gap:Single = 3;
		var capW:Single = h * 1.6;
		var segW:Single = (rowW - capW - gap * ACCUM_MAX) / ACCUM_MAX;
		if (segW < 6)
			segW = 6;
		for (i in 0...ACCUM_MAX) {
			var x:Single = origin.x + (segW + gap) * i;
			var lit = ready || i < filled;
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x, origin.y), ImGui.vec2(x + segW, origin.y + h),
				lit ? u32(0.22, 0.48, 0.92, 0.95) : u32(0.04, 0.05, 0.08, 0.94), 3);
			ImGui.ImDrawList_AddRect(dl, ImGui.vec2(x, origin.y), ImGui.vec2(x + segW, origin.y + h),
				lit ? u32(0.78, 0.92, 1.0, 0.80) : u32(0.20, 0.26, 0.36, 0.90), 3, 1);
		}
		var cx:Single = origin.x + (segW + gap) * ACCUM_MAX;
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(cx, origin.y), ImGui.vec2(cx + capW, origin.y + h),
			ready ? u32(0.30, 0.60, 1.0, 0.45 + 0.45 * p) : u32(0.05, 0.06, 0.10, 0.94), h * 0.5);
		ImGui.ImDrawList_AddRect(dl, ImGui.vec2(cx, origin.y), ImGui.vec2(cx + capW, origin.y + h),
			ready ? u32(0.78, 0.92, 1.0, 0.5 + 0.45 * p) : u32(0.28, 0.36, 0.48, 0.80), h * 0.5, ready ? 2 : 1.25);
		ImGui.dummy(ImGui.vec2(rowW, h));
	}

	/** Linked row of shapes. segs=20 -> dots, segs=4 -> diamonds. scale = radius as fraction of rowW/5. */
	static function drawChain(rowW:Single, rowH:Single, stacks:Int, ready:Bool, pulse:Bool, segs:Int, scale:Single):Void {
		var filled = clampStacks(stacks);
		var h:Single = segs == 4 ? (rowH < 22 ? 22 : rowH) : (rowH * 0.5 < 14 ? 14 : rowH * 0.5);
		var origin = ImGui.getCursorScreenPos();
		var dl = ImGui.getWindowDrawList();
		var p = pulseVal(ready || pulse);
		var step:Single = rowW / SLOT_COUNT;
		var r:Single = step * scale;
		if (r > h * 0.5 - 1)
			r = h * 0.5 - 1;
		var cy:Single = origin.y + h * 0.5;
		var x0:Single = origin.x + step * 0.5;
		var x1:Single = origin.x + step * (SLOT_COUNT - 0.5);
		ImGui.ImDrawList_AddLine(dl, ImGui.vec2(x0, cy), ImGui.vec2(x1, cy), u32(0.32, 0.55, 0.92, ready ? 0.5 * p + 0.2 : 0.25), 2);
		for (i in 0...SLOT_COUNT) {
			var isReadySlot = i == ACCUM_MAX;
			var lit = isReadySlot ? ready : (ready || i < filled);
			var c = ImGui.vec2(origin.x + step * (i + 0.5), cy);
			var rr:Single = isReadySlot ? r * 1.35 : r;
			if (lit && isReadySlot)
				ImGui.ImDrawList_AddCircleFilled(dl, c, rr + 3, u32(0.45, 0.78, 1.0, 0.25 * p), segs);
			ImGui.ImDrawList_AddCircleFilled(dl, c, rr,
				lit ? u32(0.22, 0.48, 0.92, 0.95) : u32(0.04, 0.05, 0.08, 0.94), segs);
			ImGui.ImDrawList_AddCircle(dl, c, rr,
				lit ? u32(0.78, 0.92, 1.0, 0.85) : u32(0.20, 0.26, 0.36, 0.90), segs, isReadySlot ? 2 : 1.5);
		}
		ImGui.dummy(ImGui.vec2(rowW, h));
	}

	/** Upper half-ring: 4 nodes along the arc, ready node at the right end. Height = ~half of width. */
	static function drawArc(rowW:Single, rowH:Single, stacks:Int, ready:Bool, pulse:Bool):Void {
		var filled = clampStacks(stacks);
		var R:Single = rowW * 0.5 - 8;
		if (R > 60)
			R = 60;
		if (R < 20)
			R = 20;
		var h:Single = R + 14;
		var origin = ImGui.getCursorScreenPos();
		var dl = ImGui.getWindowDrawList();
		var p = pulseVal(ready || pulse);
		var cx:Single = origin.x + rowW * 0.5;
		var cy:Single = origin.y + R + 6;
		var nodeR:Single = R * 0.14;
		if (nodeR < 4)
			nodeR = 4;
		// 5 points from 180deg to 360deg
		var prevX:Single = 0;
		var prevY:Single = 0;
		for (i in 0...SLOT_COUNT) {
			var a:Float = Math.PI + Math.PI * i / (SLOT_COUNT - 1);
			var x:Single = cx + Math.cos(a) * R;
			var y:Single = cy + Math.sin(a) * R;
			if (i > 0) {
				var linked = ready || i < filled;
				ImGui.ImDrawList_AddLine(dl, ImGui.vec2(prevX, prevY), ImGui.vec2(x, y),
					linked ? u32(0.62, 0.82, 1.0, 0.7) : u32(0.20, 0.26, 0.36, 0.7), linked ? 3 : 2);
			}
			prevX = x;
			prevY = y;
		}
		for (i in 0...SLOT_COUNT) {
			var a:Float = Math.PI + Math.PI * i / (SLOT_COUNT - 1);
			var c = ImGui.vec2(cx + Math.cos(a) * R, cy + Math.sin(a) * R);
			var isReadySlot = i == ACCUM_MAX;
			var lit = isReadySlot ? ready : (ready || i < filled);
			var rr:Single = isReadySlot ? nodeR * 1.5 : nodeR;
			if (lit && isReadySlot)
				ImGui.ImDrawList_AddCircleFilled(dl, c, rr + 4, u32(0.45, 0.78, 1.0, 0.25 * p), 20);
			ImGui.ImDrawList_AddCircleFilled(dl, c, rr,
				lit ? u32(0.22, 0.48, 0.92, 0.95) : u32(0.04, 0.05, 0.08, 0.94), 20);
			ImGui.ImDrawList_AddCircle(dl, c, rr,
				lit ? u32(0.78, 0.92, 1.0, 0.85) : u32(0.20, 0.26, 0.36, 0.90), 20, 1.5);
		}
		ImGui.dummy(ImGui.vec2(rowW, h));
	}

	/** Badge (N/4 or READY) + icon rail, matching live HUD. */
	public static function drawHead(rowW:Single, rowH:Single, stacks:Int, ready:Bool, showBadge:Bool,
			pulse:Bool = false, style:Int = 0, skill:ChaincastSkillState = null):Void {
		if (isFlagship(style)) {
			drawFlagship(style, rowW, Math.max(124, rowH), stacks, ready, showBadge, pulse, skill);
			return;
		}
		if (showBadge) {
			var numW:Single = rowW * 0.28;
			if (ready) {
				if (numW < 64)
					numW = 64;
				if (numW > 100)
					numW = 100;
			} else {
				if (numW < 48)
					numW = 48;
				if (numW > 90)
					numW = 90;
			}
			drawCount(numW, rowH, stacks, ready, pulse);
			ImGui.sameLine(0, 8);
			var pipW:Single = rowW - numW - 8;
			if (pipW < 80)
				pipW = 80;
			drawStyle(style, pipW, rowH, stacks, ready, pulse);
		} else {
			drawStyle(style, rowW, rowH, stacks, ready, pulse);
		}
	}

	/** Orbital ring: 4 nodes clockwise from top, linked arcs between lit nodes, core lights on ready. */
	static function drawOrbit(rowW:Single, rowH:Single, stacks:Int, ready:Bool, pulse:Bool):Void {
		var filled = stacks;
		if (filled < 0)
			filled = 0;
		if (filled > ACCUM_MAX)
			filled = ACCUM_MAX;
		var h:Single = rowH < 28 ? 28 : rowH;
		var origin = ImGui.getCursorScreenPos();
		var dl = ImGui.getWindowDrawList();
		var cx:Single = origin.x + rowW * 0.5;
		var cy:Single = origin.y + h * 0.5;
		var big:Single = (rowW < h ? rowW : h) * 0.5 - 2;
		var ringR:Single = big * 0.74;
		var nodeR:Single = big * 0.20;
		var coreR:Single = big * 0.40;
		var p:Single = 1;
		if (ready || pulse) {
			try
				p = 0.62 + 0.38 * Math.sin(haxe.Timer.stamp() * 7.5)
			catch (_:Dynamic)
				p = 1;
		}

		ImGui.ImDrawList_AddCircle(dl, ImGui.vec2(cx, cy), ringR, u32(0.08, 0.10, 0.16, 0.95), 40, 6);
		ImGui.ImDrawList_AddCircle(dl, ImGui.vec2(cx, cy), ringR, u32(0.32, 0.55, 0.92, ready ? 0.45 + 0.30 * p : 0.22), 40, 2);

		var px:Array<Single> = [];
		var py:Array<Single> = [];
		for (i in 0...ACCUM_MAX) {
			var a:Float = -Math.PI * 0.5 + i * Math.PI * 0.5;
			px.push(cx + Math.cos(a) * ringR);
			py.push(cy + Math.sin(a) * ringR);
		}
		// links between consecutive lit nodes (wraps when ready)
		for (i in 0...ACCUM_MAX) {
			var j = (i + 1) % ACCUM_MAX;
			var linked = ready || (i + 1 < filled);
			if (j == 0 && !ready)
				linked = false;
			if (linked)
				ImGui.ImDrawList_AddLine(dl, ImGui.vec2(px[i], py[i]), ImGui.vec2(px[j], py[j]),
					u32(0.62, 0.82, 1.0, 0.55 + (ready ? 0.25 * p : 0)), 2);
		}
		for (i in 0...ACCUM_MAX) {
			var lit = ready || i < filled;
			var c = ImGui.vec2(px[i], py[i]);
			if (lit)
				ImGui.ImDrawList_AddCircleFilled(dl, c, nodeR + 3, u32(0.45, 0.78, 1.0, 0.20 * (ready ? p : 1)), 16);
			ImGui.ImDrawList_AddCircleFilled(dl, c, nodeR,
				lit ? u32(0.22, 0.48, 0.92, 0.95) : u32(0.04, 0.05, 0.08, 0.94), 16);
			ImGui.ImDrawList_AddCircle(dl, c, nodeR,
				lit ? u32(0.78, 0.92, 1.0, 0.85) : u32(0.20, 0.26, 0.36, 0.90), 16, 1.5);
		}

		var cc = ImGui.vec2(cx, cy);
		if (ready)
			ImGui.ImDrawList_AddCircleFilled(dl, cc, coreR + 3, u32(0.45, 0.78, 1.0, 0.22 * p), 24);
		ImGui.ImDrawList_AddCircleFilled(dl, cc, coreR,
			ready ? u32(0.10, 0.22, 0.48, 0.94) : u32(0.05, 0.06, 0.10, 0.94), 24);
		var icon = GameIcons.get(GameIcons.CHAINCAST_FALLBACK);
		if (icon == 0)
			icon = GameIcons.get(GameIcons.CHAINCAST);
		var side:Single = coreR * 1.5;
		GameIcons.draw(dl, icon, cx - side * 0.5, cy - side * 0.5, side, ready ? 0xFFFFFFFF : u32(1, 1, 1, 0.16));
		ImGui.ImDrawList_AddCircle(dl, cc, coreR,
			ready ? u32(0.78, 0.92, 1.0, 0.50 + 0.45 * p) : u32(0.28, 0.36, 0.48, 0.80), 24, ready ? 2.0 : 1.25);
		ImGui.dummy(ImGui.vec2(rowW, h));
	}

	static function drawCount(w:Single, h:Single, stacks:Int, ready:Bool, pulse:Bool):Void {
		var origin = ImGui.getCursorScreenPos();
		var dl = ImGui.getWindowDrawList();
		var txt:String;
		if (ready)
			txt = "READY";
		else {
			var n = stacks;
			if (n < 0)
				n = 0;
			if (n > ACCUM_MAX)
				n = ACCUM_MAX;
			txt = Std.string(n) + "/" + Std.string(ACCUM_MAX);
		}
		var p:Single = 1;
		if (ready || pulse) {
			try
				p = 0.70 + 0.30 * Math.sin(haxe.Timer.stamp() * 8)
			catch (_:Dynamic)
				p = 1;
		}
		ImGui.ImDrawList_AddRectFilled(dl, origin, ImGui.vec2(origin.x + w, origin.y + h),
			u32(0.04, 0.06, 0.12, 0.92), 6);
		var ts = ImGui.calcTextSize(txt);
		var tx:Single = origin.x + (w - ts.x) * 0.5;
		var ty:Single = origin.y + (h - ts.y) * 0.5;
		if (pulse || ready)
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(tx + 1, ty + 1), u32(0.25, 0.55, 1.0, 0.55 * p), txt);
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(tx, ty),
			ready ? u32(0.82, 0.94, 1.0, 0.70 + 0.30 * p) : u32(0.95, 0.97, 1.0, 1), txt);
		ImGui.dummy(ImGui.vec2(w, h));
	}

	static function drawBlocks(rowW:Single, rowH:Single, stacks:Int, ready:Bool, pulse:Bool):Void {
		var n = SLOT_COUNT;
		var accumMax = ACCUM_MAX;
		var filled = stacks;
		if (filled < 0)
			filled = 0;
		if (filled > accumMax)
			filled = accumMax;

		var gap:Single = GAP;
		var blockW:Single = (rowW - gap * (n - 1)) / n;
		if (blockW < 8)
			blockW = 8;
		var blockH:Single = rowH;
		if (blockH < 16)
			blockH = 16;

		var accumIcon = GameIcons.get(GameIcons.CHAINCAST);
		if (accumIcon == 0)
			accumIcon = GameIcons.get(GameIcons.CHAINCAST_FALLBACK);
		var readyIcon = GameIcons.get(GameIcons.CHAINCAST_FALLBACK);
		if (readyIcon == 0)
			readyIcon = accumIcon;
		var origin = ImGui.getCursorScreenPos();
		var dl = ImGui.getWindowDrawList();
		var midY:Single = origin.y + blockH * 0.5;
		var p:Single = 1;
		if (ready || pulse) {
			try
				p = 0.62 + 0.38 * Math.sin(haxe.Timer.stamp() * 7.5)
			catch (_:Dynamic)
				p = 1;
		}

		var x0:Single = origin.x + blockW * 0.5;
		var x1:Single = origin.x + (blockW + gap) * (n - 1) + blockW * 0.5;
		var railA:Single = ready ? (0.42 + 0.38 * p) : 0.28;
		ImGui.ImDrawList_AddLine(dl, ImGui.vec2(x0, midY), ImGui.vec2(x1, midY), u32(0.08, 0.10, 0.16, 0.95), 7);
		ImGui.ImDrawList_AddLine(dl, ImGui.vec2(x0, midY), ImGui.vec2(x1, midY), u32(0.32, 0.55, 0.92, railA), 3);
		if (ready)
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(x0, midY), ImGui.vec2(x1, midY), u32(0.70, 0.88, 1.0, 0.18 * p), 1.25);

		for (i in 0...n) {
			var x:Single = origin.x + (blockW + gap) * i;
			var cx:Single = x + blockW * 0.5;
			var isReadySlot = i == accumMax;
			var lit = isReadySlot ? ready : (ready || i < filled);
			var well = ImGui.vec2(x, origin.y);
			var well2 = ImGui.vec2(x + blockW, origin.y + blockH);

			if (isReadySlot) {
				var rad:Single = (blockW < blockH ? blockW : blockH) * 0.46;
				if (rad < 10)
					rad = 10;
				ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, midY), rad + 3,
					ready ? u32(0.45, 0.78, 1.0, 0.22 * p) : u32(0.10, 0.14, 0.22, 0.55), 20);
				ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, midY), rad,
					ready ? u32(0.10, 0.22, 0.48, 0.92) : u32(0.05, 0.06, 0.10, 0.94), 20);
				if (ready)
					ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, midY), rad * 0.82,
						u32(0.22, 0.48, 0.88, 0.45 + 0.28 * p), 18);
			} else {
				var rounding:Single = 5;
				ImGui.ImDrawList_AddRectFilled(dl, well, well2, u32(0.04, 0.05, 0.08, 0.94), rounding);
				if (lit) {
					ImGui.ImDrawList_AddRectFilled(dl,
						ImGui.vec2(x + 1, origin.y + 1),
						ImGui.vec2(x + blockW - 1, origin.y + blockH - 1),
						u32(0.14, 0.28, 0.58, 0.55), rounding);
					ImGui.ImDrawList_AddRectFilledMultiColor(dl,
						ImGui.vec2(x + 2, origin.y + 2),
						ImGui.vec2(x + blockW - 2, origin.y + blockH - 2),
						u32(0.38, 0.62, 1.0, 0.22),
						u32(0.22, 0.38, 0.78, 0.10),
						u32(0.12, 0.18, 0.42, 0.28),
						u32(0.18, 0.32, 0.62, 0.16));
				} else {
					ImGui.ImDrawList_AddRect(dl,
						ImGui.vec2(x + 2, origin.y + 2),
						ImGui.vec2(x + blockW - 2, origin.y + blockH - 2),
						u32(1, 1, 1, 0.04), rounding, 1);
				}
			}

			var pad:Single = isReadySlot ? 7 : 5;
			var side:Single = blockW < blockH ? blockW : blockH;
			side = side - pad * 2;
			if (side < 8)
				side = 8;
			var ix:Single = cx - side * 0.5;
			var iy:Single = midY - side * 0.5;
			var icon = isReadySlot ? readyIcon : accumIcon;
			if (lit)
				GameIcons.draw(dl, icon, ix, iy, side, 0xFFFFFFFF);
			else if (!isReadySlot)
				GameIcons.draw(dl, icon, ix, iy, side, u32(1, 1, 1, 0.16));

			if (isReadySlot) {
				var rad:Single = (blockW < blockH ? blockW : blockH) * 0.46;
				if (rad < 10)
					rad = 10;
				ImGui.ImDrawList_AddCircle(dl, ImGui.vec2(cx, midY), rad,
					ready ? u32(0.78, 0.92, 1.0, 0.50 + 0.45 * p) : u32(0.28, 0.36, 0.48, 0.80),
					20, ready ? 2.0 : 1.25);
			} else {
				ImGui.ImDrawList_AddRect(dl, well, well2,
					lit ? u32(0.62, 0.82, 1.0, 0.78) : u32(0.20, 0.26, 0.36, 0.90),
					5, lit ? 1.5 : 1.15);
			}
		}
		ImGui.dummy(ImGui.vec2(rowW, blockH));
	}

	static function u32(r:Float, g:Float, b:Float, a:Float):Int {
		return ImGui.colorConvertFloat4ToU32(ImGui.vec4(r, g, b, a));
	}
}
