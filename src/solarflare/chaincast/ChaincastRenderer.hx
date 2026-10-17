package solarflare.chaincast;

import imgui.ImGui;
import solarflare.ui.GameIcons;
import solarflare.chaincast.Chaincast.ChaincastConfig;

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
			// One width for every state: READY and N/4 must not reflow the rail.
			var numW:Single = rowW * 0.28;
			if (numW < 64)
				numW = 64;
			if (numW > 100)
				numW = 100;
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

	// ------------------------------------------------------------------------------------------
	// Module art. Everything below draws into an absolute rectangle (x, y, w, h) with the window
	// draw list: no cursor flow, so a module can never push or be pushed by anything else, and the
	// same functions serve the live window and the hub preview.
	// ------------------------------------------------------------------------------------------

	public static inline var STYLE_PRISM:Int = 10;
	public static inline var STYLE_RUNES:Int = 11;
	public static inline var STYLE_CROWN:Int = 12;
	public static inline var STYLE_PENDULUM:Int = 13;
	public static inline var STYLE_HEXRING:Int = 14;
	public static inline var STYLE_SPARKLINE:Int = 15;
	/** Chain Counter styles: the ten original graphics plus the module-only originals. */
	public static final COUNTER_NAMES:Array<String> = ["Rail", "Orbit", "Segment", "Dots", "Diamond", "Arc", "Reactor", "Lightning",
		"Astral Orrery", "Phoenix Crest", "Prism", "Runes", "Crown", "Pendulum", "Hex Ring", "Spark Line"];
	public static final TIMER_NAMES:Array<String> = ["Bar", "Fuse", "Ring", "Hourglass", "Digital"];
	public static final GEM_NAMES:Array<String> = ["Gem", "Burst", "Crest", "Banner"];
	public static final WATCH_NAMES:Array<String> = ["Row", "Column", "Pill", "Orbit", "Compact"];
	public static final TRAIL_NAMES:Array<String> = ["Chain", "Tiles", "Ladder"];
	public static final BANNER_NAMES:Array<String> = ["Ribbon", "Flare", "Marquee"];

	// ---- Graphic list of the combined window ----
	// One flat id space, persisted as an int. Ids 0..15 are the Chain Counter styles (0..9 are the original
	// graphics, ids never move); every other module's styles follow in module order (counter, timer, gem,
	// watch, trail, banner = ChaincastModule kind). Append only.
	public static final GRAPHIC_GROUPS:Array<String> = ["Chain Counter", "Chain Timer", "Free Cast Gem", "Skill Watch", "Cast Trail", "Free Cast Banner"];
	public static final GRAPHIC_FIRST:Array<Int> = [0, 16, 21, 25, 30, 33];
	public static inline var GRAPHIC_COUNT:Int = 36;
	/** Closed-combo text: counters keep their plain name, other modules read "Module: Style". */
	public static final GRAPHIC_LABELS:Array<String> = buildGraphicLabels(true);
	/** Item text inside the open combo (the module name is the group header above it). */
	public static final GRAPHIC_ITEMS:Array<String> = buildGraphicLabels(false);

	static function graphicStyleNames(kind:Int):Array<String> {
		return switch (kind) {
			case 0: COUNTER_NAMES;
			case 1: TIMER_NAMES;
			case 2: GEM_NAMES;
			case 3: WATCH_NAMES;
			case 4: TRAIL_NAMES;
			default: BANNER_NAMES;
		};
	}

	static function buildGraphicLabels(closed:Bool):Array<String> {
		var out:Array<String> = [];
		for (k in 0...GRAPHIC_GROUPS.length) {
			var names = graphicStyleNames(k);
			for (i in 0...names.length)
				out.push(closed ? (k == 0 ? names[i] : GRAPHIC_GROUPS[k] + ": " + names[i]) : names[i] + "##chain_g_" + (GRAPHIC_FIRST[k] + i));
		}
		return out;
	}

	/** Module (ChaincastModule kind) a Graphic id belongs to. */
	public static function graphicKind(g:Int):Int {
		var k = GRAPHIC_FIRST.length - 1;
		while (k > 0 && g < GRAPHIC_FIRST[k])
			k--;
		return k;
	}

	/** Style index inside that module. */
	public static function graphicStyle(g:Int):Int return g - GRAPHIC_FIRST[graphicKind(g)];

	/** Saved ids outside the list fall back to the original rail. */
	public static inline function clampGraphic(g:Int):Int return g < 0 || g >= GRAPHIC_COUNT ? STYLE_RAIL : g;

	/** Seconds a Free Cast Banner stays up after the ready edge. */
	public static inline var BANNER_SECONDS:Float = 3.0;
	/** The chain timer turns urgent below this many seconds. */
	public static inline var URGENT_SECONDS:Float = 1.5;

	// Retained countdown labels: no strings are built in a draw path.
	static final SEC_TENTHS:Array<String> = [for (i in 0...100) Std.string(Std.int(i / 10)) + "." + Std.string(i % 10) + "s"];
	static final SEC_WHOLE:Array<String> = [for (i in 0...601) Std.string(i) + "s"];
	static final SEC_BARE_TENTHS:Array<String> = [for (i in 0...100) Std.string(Std.int(i / 10)) + "." + Std.string(i % 10)];
	static final SEC_BARE_WHOLE:Array<String> = [for (i in 0...601) Std.string(i)];

	/** "2.1s" below ten seconds, "14s" above; table lookup. */
	public static function fmtSec(sec:Float):String {
		var n = Math.isFinite(sec) && sec > 0 ? sec : 0;
		if (n < 9.95)
			return SEC_TENTHS[Std.int(n * 10 + 0.5)];
		var w = Std.int(Math.ceil(n));
		return SEC_WHOLE[w > 600 ? 600 : w];
	}

	/** Same without the unit, for large numerals. */
	public static function fmtBare(sec:Float):String {
		var n = Math.isFinite(sec) && sec > 0 ? sec : 0;
		if (n < 9.95)
			return SEC_BARE_TENTHS[Std.int(n * 10 + 0.5)];
		var w = Std.int(Math.ceil(n));
		return SEC_BARE_WHOLE[w > 600 ? 600 : w];
	}

	public static inline function nowStamp():Float return now();

	/** ABGR packing identical to colorConvertFloat4ToU32, usable in static tables (no native call). */
	static function pack(r:Float, g:Float, b:Float, a:Float):Int {
		return (Std.int(clamp01(a) * 255 + 0.5) << 24) | (Std.int(clamp01(b) * 255 + 0.5) << 16)
			| (Std.int(clamp01(g) * 255 + 0.5) << 8) | Std.int(clamp01(r) * 255 + 0.5);
	}

	static final DIGITS:Array<String> = ["0", "1", "2", "3", "4", "5"];
	static final PRISM_TINTS:Array<Int> = [pack(0.50, 0.80, 1.0, 0.95), pack(0.30, 0.62, 1.0, 0.95), pack(0.20, 0.42, 0.88, 0.95), pack(0.40, 0.70, 1.0, 0.95)];
	static final GEM_BLUE:Array<Int> = [pack(0.42, 0.74, 1.0, 0.96), pack(0.62, 0.86, 1.0, 0.96), pack(0.30, 0.58, 1.0, 0.96), pack(0.20, 0.42, 0.90, 0.96)];
	static final GEM_GOLD:Array<Int> = [pack(1.0, 0.86, 0.45, 0.96), pack(1.0, 0.94, 0.66, 0.96), pack(0.95, 0.72, 0.28, 0.96), pack(0.85, 0.58, 0.18, 0.96)];
	// Scratch vertices for polygons (single-threaded draw; reused, never allocated per frame).
	static final polyX:Array<Float> = [0, 0, 0, 0, 0, 0];
	static final polyY:Array<Float> = [0, 0, 0, 0, 0, 0];

	static inline function minF(a:Float, b:Float):Float return a < b ? a : b;

	static inline function maxF(a:Float, b:Float):Float return a > b ? a : b;

	static inline function clamp01(v:Float):Float return v < 0 ? 0 : (v > 1 ? 1 : v);

	/** Centered text (both axes) with a drop shadow; `size` is the font pixel size. */
	static function txt(dl:Dynamic, cx:Float, cy:Float, size:Float, color:Int, s:String):Void {
		ImGui.pushFont(ImGui.getFont(), size < 8 ? 8 : size);
		var ts = ImGui.calcTextSize(s);
		var tx = cx - ts.x * 0.5;
		var ty = cy - ts.y * 0.5;
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(tx + 1, ty + 1), u32(0, 0, 0, 0.9), s);
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(tx, ty), color, s);
		ImGui.popFont();
	}

	/** Left-aligned, vertically centered text. */
	static function txtL(dl:Dynamic, x:Float, cy:Float, size:Float, color:Int, s:String):Void {
		ImGui.pushFont(ImGui.getFont(), size < 8 ? 8 : size);
		var ts = ImGui.calcTextSize(s);
		var ty = cy - ts.y * 0.5;
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(x + 1, ty + 1), u32(0, 0, 0, 0.9), s);
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(x, ty), color, s);
		ImGui.popFont();
	}

	static function fitSize(s:String, size:Float, maxW:Float):Float {
		ImGui.pushFont(ImGui.getFont(), size < 8 ? 8 : size);
		var w = ImGui.calcTextSize(s).x;
		ImGui.popFont();
		return w > maxW && w > 1 ? maxF(8, size * maxW / w) : size;
	}

	static function goldCol(a:Float = 1):Int return u32(1.0, 0.78, 0.28, a);

	static function ln(dl:Dynamic, x0:Float, y0:Float, x1:Float, y1:Float, col:Int, th:Float):Void {
		ImGui.ImDrawList_AddLine(dl, ImGui.vec2(x0, y0), ImGui.vec2(x1, y1), col, th);
	}

	static function disc(dl:Dynamic, cx:Float, cy:Float, r:Float, fill:Int, edge:Int, th:Float = 1.5):Void {
		ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, cy), r, fill, 24);
		if (th > 0)
			ImGui.ImDrawList_AddCircle(dl, ImGui.vec2(cx, cy), r, edge, 24, th);
	}

	static function litFill():Int return u32(0.22, 0.48, 0.92, 0.95);

	static function litEdge():Int return u32(0.78, 0.92, 1.0, 0.88);

	static function darkFill():Int return u32(0.04, 0.05, 0.08, 0.94);

	static function darkEdge():Int return u32(0.20, 0.26, 0.36, 0.90);

	static function checkGlyph(dl:Dynamic, cx:Float, cy:Float, s:Float, col:Int, th:Float):Void {
		ln(dl, cx - s, cy, cx - s * 0.3, cy + s * 0.75, col, th);
		ln(dl, cx - s * 0.3, cy + s * 0.75, cx + s, cy - s * 0.7, col, th);
	}

	static function crossGlyph(dl:Dynamic, cx:Float, cy:Float, s:Float, col:Int, th:Float):Void {
		ln(dl, cx - s, cy - s, cx + s, cy + s, col, th);
		ln(dl, cx + s, cy - s, cx - s, cy + s, col, th);
	}

	/** Cheap per-frame noise in 0..1 for sparks and flicker. */
	static function noise(a:Float, b:Float):Float {
		var v = Math.sin(a * 12.9898 + b * 78.233) * 43758.5453;
		return v - Math.floor(v);
	}

	static function circleArc(dl:Dynamic, cx:Float, cy:Float, r:Float, prog:Float, col:Int, th:Float):Void {
		if (prog <= 0.001)
			return;
		arcPoly(dl, cx, cy, r, -Math.PI * 0.5, -Math.PI * 0.5 + Math.PI * 2 * minF(1, prog), col, th, 28);
	}

	// ------------------------------------------------------------------ Chain Counter

	/** Standalone counter: the original graphics through drawHead, the new ones in their own rectangle. */
	public static function drawCounter(style:Int, x:Float, y:Float, w:Float, h:Float, f:ChaincastFrame, showCount:Bool):Void {
		if (w < 12 || h < 12)
			return;
		if (style < STYLE_COUNT) {
			// Original graphics flow from the cursor; centre them vertically so a tall window stays tidy.
			var natural = headHeight(style, w);
			var top = y + maxF(0, (h - natural) * 0.5);
			ImGui.setCursorScreenPos(ImGui.vec2(x, top));
			drawHead(w, minF(natural, h), f.stacks, f.ready, showCount, f.pulse, style, f.skill);
			return;
		}
		var dl = ImGui.getWindowDrawList();
		switch (style) {
			case STYLE_PRISM:
				drawPrism(dl, x, y, w, h, f, showCount);
			case STYLE_RUNES:
				drawRunes(dl, x, y, w, h, f, showCount);
			case STYLE_CROWN:
				drawCrown(dl, x, y, w, h, f, showCount);
			case STYLE_PENDULUM:
				drawPendulum(dl, x, y, w, h, f, showCount);
			case STYLE_HEXRING:
				drawHexRing(dl, x, y, w, h, f, showCount);
			default:
				drawSparkLine(dl, x, y, w, h, f, showCount);
		}
	}

	static function countText(dl:Dynamic, cx:Float, cy:Float, size:Float, f:ChaincastFrame):Void {
		if (f.ready)
			txt(dl, cx, cy, size, goldCol(0.75 + 0.25 * pulseVal(true)), "FREE");
		else
			txt(dl, cx, cy, size, u32(0.92, 0.96, 1, 1), COUNT_LABELS[clampStacks(f.stacks)]);
	}

	/** Faceted crystal: four facets light in turn; a glint sweeps it when the free cast is ready. */
	static function drawPrism(dl:Dynamic, x:Float, y:Float, w:Float, h:Float, f:ChaincastFrame, showCount:Bool):Void {
		var cx = x + w * 0.5;
		var cy = y + h * 0.5;
		var r = minF(h * 0.5 - 2, w * 0.5 / 0.72 - 2);
		if (r < 8)
			return;
		var hw = r * 0.72;
		var p = pulseVal(f.ready || f.pulse);
		polyX[0] = cx;
		polyY[0] = cy - r;
		polyX[1] = cx + hw;
		polyY[1] = cy;
		polyX[2] = cx;
		polyY[2] = cy + r;
		polyX[3] = cx - hw;
		polyY[3] = cy;
		for (i in 0...ACCUM_MAX) {
			var j = (i + 1) % ACCUM_MAX;
			var lit = f.ready || i < f.stacks;
			ImGui.ImDrawList_AddTriangleFilled(dl, ImGui.vec2(polyX[i], polyY[i]), ImGui.vec2(polyX[j], polyY[j]), ImGui.vec2(cx, cy),
				lit ? (f.ready ? u32(1.0, 0.82, 0.38, 0.55 + 0.4 * p) : PRISM_TINTS[i]) : darkFill());
		}
		for (i in 0...ACCUM_MAX) {
			var j = (i + 1) % ACCUM_MAX;
			var lit = f.ready || i < f.stacks;
			ln(dl, polyX[i], polyY[i], polyX[j], polyY[j], lit ? (f.ready ? goldCol(0.95) : litEdge()) : darkEdge(), 1.6);
			ln(dl, polyX[i], polyY[i], cx, cy, lit ? u32(1, 1, 1, 0.35) : u32(1, 1, 1, 0.06), 1);
		}
		if (f.ready) {
			var g = (f.t * 0.9) % 1;
			var gx = cx - hw + 2 * hw * g;
			ln(dl, gx - r * 0.12, cy - r * 0.55, gx + r * 0.12, cy + r * 0.55, u32(1, 1, 1, 0.55 * (1 - Math.abs(g - 0.5) * 2)), 2);
		}
		if (showCount)
			countText(dl, cx, cy, clampF(r * 0.5, 9, 16), f);
	}

	static inline function clampF(v:Float, lo:Float, hi:Float):Float return v < lo ? lo : (v > hi ? hi : v);

	/** Five rune tiles: four charge runes and a ring socket that burns gold when the free cast is ready. */
	static function drawRunes(dl:Dynamic, x:Float, y:Float, w:Float, h:Float, f:ChaincastFrame, showCount:Bool):Void {
		var gap = 4.0;
		var cell = minF((w - gap * 4) / 5, h - (showCount ? 16 : 0));
		if (cell < 10)
			return;
		var total = cell * 5 + gap * 4;
		var x0 = x + (w - total) * 0.5;
		var top = y + (h - cell - (showCount ? 16 : 0)) * 0.5;
		var p = pulseVal(f.ready || f.pulse);
		for (i in 0...SLOT_COUNT) {
			var bx = x0 + i * (cell + gap);
			var free = i == ACCUM_MAX;
			var lit = free ? f.ready : (f.ready || i < f.stacks);
			var col = free ? goldCol(0.95) : litEdge();
			var mx = bx + cell * 0.5;
			var my = top + cell * 0.5;
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(bx, top), ImGui.vec2(bx + cell, top + cell),
				lit ? (free ? u32(0.30, 0.20, 0.05, 0.92) : u32(0.08, 0.16, 0.34, 0.92)) : darkFill(), 5);
			if (lit)
				ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(bx - 1, top - 1), ImGui.vec2(bx + cell + 1, top + cell + 1),
					free ? goldCol(0.12 * p) : u32(0.45, 0.78, 1.0, 0.12), 6);
			ImGui.ImDrawList_AddRect(dl, ImGui.vec2(bx, top), ImGui.vec2(bx + cell, top + cell), lit ? col : darkEdge(), 5, lit ? 1.6 : 1.1);
			var rc = lit ? col : u32(0.28, 0.34, 0.44, 0.8);
			var a = cell * 0.26;
			switch (i) {
				case 0: // fehu: stem with two branches
					ln(dl, mx - a * 0.5, my - a, mx - a * 0.5, my + a, rc, 2);
					ln(dl, mx - a * 0.5, my - a * 0.4, mx + a * 0.7, my - a, rc, 2);
					ln(dl, mx - a * 0.5, my + a * 0.1, mx + a * 0.7, my - a * 0.5, rc, 2);
				case 1: // up-arrow over a bar
					ln(dl, mx, my - a, mx, my + a, rc, 2);
					ln(dl, mx - a * 0.8, my - a * 0.1, mx, my - a, rc, 2);
					ln(dl, mx + a * 0.8, my - a * 0.1, mx, my - a, rc, 2);
					ln(dl, mx - a * 0.6, my + a, mx + a * 0.6, my + a, rc, 2);
				case 2: // diamond with a cross
					ImGui.ImDrawList_AddQuad(dl, ImGui.vec2(mx, my - a), ImGui.vec2(mx + a * 0.8, my), ImGui.vec2(mx, my + a), ImGui.vec2(mx - a * 0.8, my), rc, 2);
					ln(dl, mx - a * 0.8, my, mx + a * 0.8, my, rc, 1.5);
				case 3: // bound X
					crossGlyph(dl, mx, my, a * 0.8, rc, 2);
					ln(dl, mx, my - a, mx, my + a, rc, 1.5);
				default: // socket ring
					ImGui.ImDrawList_AddCircle(dl, ImGui.vec2(mx, my), a, rc, 20, 2);
					if (lit)
						ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(mx, my), a * 0.45, goldCol(0.6 + 0.4 * p), 14);
			}
		}
		if (showCount)
			countText(dl, x + w * 0.5, top + cell + 9, 13, f);
	}

	/** A crown: four peak jewels charge left to right, the band jewel is the free cast. */
	static function drawCrown(dl:Dynamic, x:Float, y:Float, w:Float, h:Float, f:ChaincastFrame, showCount:Bool):Void {
		var cw = minF(w - 6, h * 2.0);
		var ch = minF(h - (showCount ? 14 : 2), cw * 0.62);
		if (cw < 30 || ch < 16)
			return;
		var x0 = x + (w - cw) * 0.5;
		var top = y + (h - ch - (showCount ? 14 : 0)) * 0.5;
		var bandH = ch * 0.32;
		var base = top + ch;
		var p = pulseVal(f.ready || f.pulse);
		var body = f.ready ? u32(0.40, 0.28, 0.07, 0.95) : u32(0.08, 0.10, 0.17, 0.95);
		var edge = f.ready ? goldCol(0.95) : u32(0.45, 0.58, 0.80, 0.9);
		// Four peaks as triangles over the band.
		for (i in 0...ACCUM_MAX) {
			var px0 = x0 + cw * i / 4;
			var px1 = x0 + cw * (i + 1) / 4;
			var tipX = (px0 + px1) * 0.5;
			var tipY = top + (i == 1 || i == 2 ? 0 : ch * 0.14);
			ImGui.ImDrawList_AddTriangleFilled(dl, ImGui.vec2(px0, base - bandH), ImGui.vec2(tipX, tipY), ImGui.vec2(px1, base - bandH), body);
			ln(dl, px0, base - bandH, tipX, tipY, edge, 1.5);
			ln(dl, tipX, tipY, px1, base - bandH, edge, 1.5);
			var lit = f.ready || i < f.stacks;
			var jr = clampF(cw * 0.032, 3, 7);
			if (lit)
				ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(tipX, tipY), jr + 3, f.ready ? goldCol(0.2 * p) : u32(0.45, 0.78, 1.0, 0.22), 16);
			disc(dl, tipX, tipY, jr, lit ? (f.ready ? goldCol(1) : litFill()) : darkFill(), lit ? litEdge() : darkEdge(), 1.2);
		}
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x0, base - bandH), ImGui.vec2(x0 + cw, base), body, 3);
		ImGui.ImDrawList_AddRect(dl, ImGui.vec2(x0, base - bandH), ImGui.vec2(x0 + cw, base), edge, 3, 1.5);
		var fr = bandH * 0.34;
		var fcx = x0 + cw * 0.5;
		var fcy = base - bandH * 0.5;
		if (f.ready)
			ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(fcx, fcy), fr + 5, goldCol(0.25 * p), 18);
		disc(dl, fcx, fcy, fr, f.ready ? goldCol(0.95) : u32(0.1, 0.09, 0.07, 0.95), f.ready ? u32(1, 0.95, 0.7, 1) : goldCol(0.45), 1.5);
		if (showCount)
			countText(dl, x + w * 0.5, base + 8, 12, f);
	}

	/** Newton's cradle: charged balls rest against the bar; when free the last one swings out. */
	static function drawPendulum(dl:Dynamic, x:Float, y:Float, w:Float, h:Float, f:ChaincastFrame, showCount:Bool):Void {
		var n = SLOT_COUNT;
		var bar = y + 4;
		var step = minF((w - 10) / n, h * 0.55);
		var rr = clampF(step * 0.4, 4, 16);
		var len = minF(h - 12 - rr - (showCount ? 12 : 0), step * 2.2);
		if (len < rr)
			return;
		var x0 = x + (w - step * n) * 0.5 + step * 0.5;
		ln(dl, x0 - step * 0.6, bar, x0 + step * (n - 1) + step * 0.6, bar, u32(0.45, 0.55, 0.72, 0.9), 3);
		var swing = f.ready ? 0.55 * Math.sin(f.t * 3.6) : 0;
		for (i in 0...n) {
			var free = i == ACCUM_MAX;
			var lit = free ? f.ready : (f.ready || i < f.stacks);
			var ang = free ? (swing > 0 ? swing : 0) : 0;
			var px = x0 + step * i;
			var bx = px + Math.sin(ang) * len;
			var by = bar + Math.cos(ang) * len;
			ln(dl, px, bar, bx, by, u32(0.60, 0.68, 0.82, lit ? 0.8 : 0.4), 1.2);
			if (lit)
				ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(bx, by), rr + 3, free ? goldCol(0.2) : u32(0.45, 0.78, 1.0, 0.18), 18);
			disc(dl, bx, by, rr, lit ? (free ? goldCol(0.95) : litFill()) : darkFill(), lit ? (free ? u32(1, 0.95, 0.7, 1) : litEdge()) : (free ? goldCol(0.45) : darkEdge()), 1.5);
		}
		if (showCount)
			countText(dl, x + w * 0.5, y + h - 7, 12, f);
	}

	/** Hexagon outline: four charge edges, then the two gold edges light together as the free cast. */
	static function drawHexRing(dl:Dynamic, x:Float, y:Float, w:Float, h:Float, f:ChaincastFrame, showCount:Bool):Void {
		var cx = x + w * 0.5;
		var cy = y + h * 0.5;
		var r = minF(w, h) * 0.5 - 4;
		if (r < 10)
			return;
		var p = pulseVal(f.ready || f.pulse);
		var vx = polyX;
		var vy = polyY;
		for (k in 0...6) {
			vx[k] = cx + Math.cos(-Math.PI * 0.5 + k * Math.PI / 3) * r;
			vy[k] = cy + Math.sin(-Math.PI * 0.5 + k * Math.PI / 3) * r;
		}
		for (k in 0...6) {
			var j = (k + 1) % 6;
			var free = k >= ACCUM_MAX;
			var lit = free ? f.ready : (f.ready || k < f.stacks);
			ln(dl, vx[k], vy[k], vx[j], vy[j], darkFill(), 7);
			if (lit)
				ln(dl, vx[k], vy[k], vx[j], vy[j], free ? goldCol(0.22 * p) : u32(0.45, 0.78, 1.0, 0.25), 9);
			ln(dl, vx[k], vy[k], vx[j], vy[j], lit ? (free ? goldCol(0.95) : litEdge()) : darkEdge(), lit ? 3.5 : 2.5);
		}
		for (k in 0...6)
			ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(vx[k], vy[k]), 2.5, f.ready ? goldCol(0.95) : (k <= f.stacks && f.stacks > 0 ? litEdge() : darkEdge()), 8);
		if (f.stacks > 0 || f.ready) {
			var a = -Math.PI * 0.5 + f.t * (f.ready ? 1.4 : 0.6);
			ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx + Math.cos(a) * r * 0.62, cy + Math.sin(a) * r * 0.62), 2, u32(1, 1, 1, 0.8), 8);
		}
		if (showCount)
			countText(dl, cx, cy, clampF(r * 0.5, 9, 18), f);
	}

	/** A slim spark line: the filled length is the charge, a spark rides its tip, a star waits at the end. */
	static function drawSparkLine(dl:Dynamic, x:Float, y:Float, w:Float, h:Float, f:ChaincastFrame, showCount:Bool):Void {
		var pad = clampF(h * 0.3, 8, 16);
		var x0 = x + pad;
		var x1 = x + w - pad - clampF(h * 0.35, 8, 14);
		var cy = y + h * 0.5 - (showCount ? 5 : 0);
		if (x1 - x0 < 20)
			return;
		var p = pulseVal(f.ready || f.pulse);
		ln(dl, x0, cy, x1, cy, u32(0.10, 0.13, 0.20, 0.95), 5);
		for (i in 0...ACCUM_MAX + 1)
			ln(dl, x0 + (x1 - x0) * i / ACCUM_MAX, cy - 5, x0 + (x1 - x0) * i / ACCUM_MAX, cy + 5, darkEdge(), 1.2);
		var frac = f.ready ? 1.0 : clamp01(f.stacks / ACCUM_MAX);
		var tipX = x0 + (x1 - x0) * frac;
		if (frac > 0) {
			ln(dl, x0, cy, tipX, cy, f.ready ? goldCol(0.3 * p) : u32(0.45, 0.78, 1.0, 0.28), 9);
			ln(dl, x0, cy, tipX, cy, f.ready ? goldCol(0.95) : litEdge(), 3);
			var fl = 1.0 + 0.5 * Math.sin(f.t * 22);
			ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(tipX, cy), 3.5 * fl, u32(1, 1, 1, 0.9), 10);
			for (k in 0...3) {
				var a = noise(k, Math.floor(f.t * 12)) * Math.PI * 2;
				ln(dl, tipX, cy, tipX + Math.cos(a) * 7, cy + Math.sin(a) * 7, u32(0.8, 0.95, 1, 0.55), 1);
			}
		}
		// Free-cast star at the end of the line.
		var sx = x1 + (x + w - pad - x1) * 0.55 + 4;
		var sr = clampF(h * 0.22, 5, 10);
		for (k in 0...4) {
			var a = k * Math.PI / 4 + (f.ready ? f.t * 1.5 : 0);
			ln(dl, sx - Math.cos(a) * sr, cy - Math.sin(a) * sr, sx + Math.cos(a) * sr, cy + Math.sin(a) * sr, f.ready ? goldCol(0.95) : goldCol(0.35), 1.6);
		}
		if (showCount)
			countText(dl, x + w * 0.5, y + h - 8, 12, f);
	}

	// ------------------------------------------------------------------ Chain Timer

	/** Time left in the chain window. Idle (no timer running) draws a dim empty gauge in the same box. */
	public static function drawTimerModule(style:Int, x:Float, y:Float, w:Float, h:Float, f:ChaincastFrame, showLabel:Bool):Void {
		if (w < 16 || h < 12)
			return;
		var dl = ImGui.getWindowDrawList();
		var live = f.remainValid;
		var prog = live ? clamp01(f.remainProg) : 0;
		var urgent = live && f.remainLeft < URGENT_SECONDS;
		var flash = urgent ? 0.5 + 0.5 * Math.sin(f.t * 14) : 0;
		var base = live ? u32(0.45, 0.85, 1.0, 0.95) : u32(0.35, 0.42, 0.55, 0.6);
		var hot = u32(1.0, 0.45 + 0.2 * flash, 0.25, 1.0);
		var col = urgent ? hot : base;
		var value = live ? fmtSec(f.remainLeft) : "--";
		switch (style) {
			case 1:
				drawFuse(dl, x, y, w, h, f, prog, live, urgent, flash, col, value, showLabel);
			case 2:
				drawTimerRing(dl, x, y, w, h, prog, live, col, value, showLabel);
			case 3:
				drawHourglass(dl, x, y, w, h, f, prog, live, col, value, showLabel);
			case 4:
				drawDigital(dl, x, y, w, h, live, urgent, flash, col, value, showLabel);
			default:
				drawTimerBar(dl, x, y, w, h, prog, live, urgent, flash, col, value, showLabel);
		}
	}

	static function drawTimerBar(dl:Dynamic, x:Float, y:Float, w:Float, h:Float, prog:Float, live:Bool, urgent:Bool, flash:Float, col:Int,
			value:String, showLabel:Bool):Void {
		var textH = showLabel ? clampF(h * 0.42, 9, 17) : 0;
		var barH = clampF(h - textH - 6, 6, 40);
		var by = y + (h - barH - textH) * 0.5 + textH;
		if (showLabel) {
			txtL(dl, x + 2, by - textH * 0.5 - 1, textH, u32(0.75, 0.88, 1.0, live ? 0.95 : 0.4), "CHAIN TIME");
			ImGui.pushFont(ImGui.getFont(), textH);
			var vw = ImGui.calcTextSize(value).x;
			ImGui.popFont();
			txtL(dl, x + w - vw - 3, by - textH * 0.5 - 1, textH, col, value);
		}
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x, by), ImGui.vec2(x + w, by + barH), u32(0.06, 0.08, 0.12, 0.95), 4);
		var fw = w * prog;
		if (fw > 1) {
			if (urgent)
				ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x, by), ImGui.vec2(x + fw, by + barH), u32(1, 0.40 + 0.2 * flash, 0.2, 0.9), 4);
			else
				ImGui.ImDrawList_AddRectFilledMultiColor(dl, ImGui.vec2(x, by), ImGui.vec2(x + fw, by + barH), u32(0.15, 0.45, 0.95, 0.9),
					u32(0.45, 0.85, 1.0, 0.9), u32(0.20, 0.40, 0.85, 0.75), u32(0.10, 0.25, 0.55, 0.75));
		}
		ImGui.ImDrawList_AddRect(dl, ImGui.vec2(x, by), ImGui.vec2(x + w, by + barH), live ? u32(0.7, 0.85, 1, 0.45) : darkEdge(), 4, 1.2);
		if (!showLabel)
			txt(dl, x + w * 0.5, by + barH * 0.5, clampF(barH * 0.8, 9, 18), u32(1, 1, 1, live ? 0.95 : 0.4), value);
	}

	/** A burning fuse: the spark runs toward the bomb at the right as the chain window closes. */
	static function drawFuse(dl:Dynamic, x:Float, y:Float, w:Float, h:Float, f:ChaincastFrame, prog:Float, live:Bool, urgent:Bool, flash:Float,
			col:Int, value:String, showLabel:Bool):Void {
		var br = clampF(h * 0.28, 7, 18);
		var cy = y + h * (showLabel ? 0.4 : 0.5);
		var bx = x + w - br - 2;
		var x0 = x + 4;
		var sx = bx - br * 0.6 - (bx - br * 0.6 - x0) * prog;
		ln(dl, x0, cy, sx, cy, u32(0.14, 0.14, 0.16, 0.8), 2);
		ln(dl, sx, cy, bx - br * 0.6, cy, u32(0.78, 0.66, 0.42, 0.95), 2.5);
		disc(dl, bx, cy, br, u32(0.06, 0.07, 0.10, 0.98), urgent ? u32(1, 0.5, 0.3, 1) : u32(0.45, 0.55, 0.72, 0.9), 2);
		if (live) {
			var fl = 0.7 + 0.5 * noise(Math.floor(f.t * 20), 3);
			ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(sx, cy), 6 * fl, u32(1, 0.6, 0.15, 0.30), 12);
			ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(sx, cy), 3 * fl, u32(1, 0.95, 0.6, 0.95), 10);
			for (k in 0...5) {
				var a = noise(k, Math.floor(f.t * 14)) * Math.PI * 2;
				var d = 5 + 7 * noise(k + 9, Math.floor(f.t * 14));
				ln(dl, sx, cy, sx + Math.cos(a) * d, cy + Math.sin(a) * d, u32(1, 0.8, 0.3, 0.7), 1);
			}
		}
		if (showLabel)
			txt(dl, x + w * 0.5, y + h - clampF(h * 0.2, 6, 10), clampF(h * 0.34, 9, 16), col, value);
		else
			txt(dl, bx, cy, br * 0.9, col, value);
	}

	static function drawTimerRing(dl:Dynamic, x:Float, y:Float, w:Float, h:Float, prog:Float, live:Bool, col:Int, value:String, showLabel:Bool):Void {
		var r = minF(w, h) * 0.5 - 4;
		if (r < 8)
			return;
		var cx = x + w * 0.5;
		var cy = y + h * 0.5;
		ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, cy), r, u32(0.04, 0.06, 0.10, 0.85), 32);
		ImGui.ImDrawList_AddCircle(dl, ImGui.vec2(cx, cy), r - 3, u32(0.20, 0.26, 0.36, 0.8), 32, 5);
		circleArc(dl, cx, cy, r - 3, prog, col, 5);
		txt(dl, cx, cy - (showLabel ? r * 0.12 : 0), clampF(r * 0.55, 9, 26), u32(1, 1, 1, live ? 0.95 : 0.4), value);
		if (showLabel)
			txt(dl, cx, cy + r * 0.42, clampF(r * 0.2, 8, 11), u32(0.75, 0.88, 1, live ? 0.8 : 0.35), "CHAIN");
	}

	static function drawHourglass(dl:Dynamic, x:Float, y:Float, w:Float, h:Float, f:ChaincastFrame, prog:Float, live:Bool, col:Int, value:String,
			showLabel:Bool):Void {
		var gh = h - (showLabel ? 14 : 4);
		var gw = minF(gh * 0.62, w * 0.5);
		if (gh < 18)
			return;
		var cx = x + w * 0.5;
		var top = y + 2;
		var mid = top + gh * 0.5;
		var bot = top + gh;
		var hw = gw * 0.5;
		var neck = 2.0;
		var half = gh * 0.5;
		var sand = u32(0.95, 0.80, 0.42, live ? 0.9 : 0.25);
		var frame = live ? u32(0.7, 0.85, 1, 0.9) : darkEdge();
		// Upper bulb holds `prog` of the sand, the lower bulb the rest.
		var up = clamp01(prog) * 0.92;
		if (up > 0.01) {
			var ly = mid - half * up;
			var wl = neck + (hw - neck) * up;
			ImGui.ImDrawList_AddQuadFilled(dl, ImGui.vec2(cx - wl, ly), ImGui.vec2(cx + wl, ly), ImGui.vec2(cx + neck, mid), ImGui.vec2(cx - neck, mid), sand);
		}
		var low = clamp01(1 - prog) * 0.92;
		if (low > 0.01) {
			var ly2 = bot - half * low;
			var wl2 = neck + (hw - neck) * (1 - low);
			ImGui.ImDrawList_AddQuadFilled(dl, ImGui.vec2(cx - wl2, ly2), ImGui.vec2(cx + wl2, ly2), ImGui.vec2(cx + hw, bot), ImGui.vec2(cx - hw, bot), sand);
		}
		ln(dl, cx - hw, top, cx + hw, top, frame, 2.5);
		ln(dl, cx - hw, bot, cx + hw, bot, frame, 2.5);
		ln(dl, cx - hw, top, cx - neck, mid, frame, 1.8);
		ln(dl, cx + hw, top, cx + neck, mid, frame, 1.8);
		ln(dl, cx - neck, mid, cx - hw, bot, frame, 1.8);
		ln(dl, cx + neck, mid, cx + hw, bot, frame, 1.8);
		if (live && prog > 0.02)
			ln(dl, cx, mid, cx, bot - half * low, u32(0.95, 0.80, 0.42, 0.55 + 0.1 * (Math.floor(f.t * 18) % 3)), 1.2);
		var tx = cx + hw + 6;
		if (tx + 24 < x + w)
			txtL(dl, tx, mid, clampF(gh * 0.28, 9, 18), col, value);
		else if (showLabel)
			txt(dl, cx, y + h - 6, 11, col, value);
	}

	static function drawDigital(dl:Dynamic, x:Float, y:Float, w:Float, h:Float, live:Bool, urgent:Bool, flash:Float, col:Int, value:String,
			showLabel:Bool):Void {
		var size = fitSize(value, clampF(h * (showLabel ? 0.62 : 0.8), 12, 56), w - 8);
		var cy = y + h * (showLabel ? 0.42 : 0.5);
		if (live && !urgent)
			txt(dl, x + w * 0.5 + 2, cy + 2, size, u32(0.2, 0.45, 0.9, 0.35), value);
		txt(dl, x + w * 0.5, cy, size, urgent ? u32(1, 0.45 + 0.25 * flash, 0.25, 1) : col, value);
		if (showLabel)
			txt(dl, x + w * 0.5, y + h - clampF(h * 0.16, 6, 9), clampF(h * 0.2, 8, 11), u32(0.75, 0.88, 1, live ? 0.8 : 0.35), "CHAIN TIME");
	}

	// ------------------------------------------------------------------ Free Cast Gem

	static final GEM_BANNER_LABELS:Array<String> = ["0/4 TO FREE CAST", "1/4 TO FREE CAST", "2/4 TO FREE CAST", "3/4 TO FREE CAST", "4/4 TO FREE CAST"];

	static function iconAt(dl:Dynamic, key:String, cx:Float, cy:Float, size:Float, tint:Int):Bool {
		if (key == null || key.length == 0 || size < 4)
			return false;
		return GameIcons.drawKey(dl, key, cx - size * 0.5, cy - size * 0.5, size, size, tint);
	}

	/** "Your 5th cast is free": n/4 while charging, a glowing FREE state (with the linked skill icon) when ready. */
	public static function drawGemModule(style:Int, x:Float, y:Float, w:Float, h:Float, f:ChaincastFrame, showIcon:Bool):Void {
		if (w < 16 || h < 16)
			return;
		var dl = ImGui.getWindowDrawList();
		var p = pulseVal(f.ready || f.pulse);
		var labelH = h >= 64 ? 18.0 : 0.0;
		var cx = x + w * 0.5;
		var area = h - labelH;
		var cy = y + area * 0.5;
		var s = minF(w - 4, area - 2);
		if (s < 12)
			return;
		var linkTint = f.ready ? 0xFFFFFFFF : u32(1, 1, 1, 0.32);
		switch (style) {
			case 1: // Burst: a core with eight rays; two rays light per charge
				var core = s * 0.27;
				for (k in 0...8) {
					var a = k * Math.PI / 4 + (f.ready ? f.t * 0.8 : 0);
					var lit = f.ready || k < f.stacks * 2;
					var inner = core + 3;
					var outer = core + s * (lit ? (f.ready ? 0.22 + 0.06 * Math.sin(f.t * 8 + k) : 0.18) : 0.1);
					ln(dl, cx + Math.cos(a) * inner, cy + Math.sin(a) * inner, cx + Math.cos(a) * outer, cy + Math.sin(a) * outer,
						lit ? (f.ready ? goldCol(0.95) : litEdge()) : darkEdge(), lit ? 3 : 2);
				}
				if (f.ready)
					ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, cy), core + 6, goldCol(0.22 * p), 28);
				disc(dl, cx, cy, core, f.ready ? u32(0.30, 0.20, 0.05, 0.96) : u32(0.05, 0.07, 0.12, 0.96), f.ready ? goldCol(0.95) : litEdge(), 2);
				if (!(showIcon && iconAt(dl, f.linkIcon, cx, cy, core * 1.35, linkTint)))
					txt(dl, cx, cy, core * 0.8, f.ready ? goldCol(1) : u32(0.9, 0.95, 1, 1), f.ready ? "5" : DIGITS[clampStacks(f.stacks)]);
			case 2: // Crest: a shield; four pips along the top, the skill in the middle
				var sw = minF(s * 0.86, w - 6);
				var top = cy - s * 0.5;
				var sh = s;
				var body = f.ready ? u32(0.34, 0.22, 0.05, 0.96) : u32(0.06, 0.08, 0.14, 0.96);
				var edge = f.ready ? goldCol(0.95) : u32(0.45, 0.58, 0.80, 0.9);
				ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(cx - sw * 0.5, top), ImGui.vec2(cx + sw * 0.5, top + sh * 0.55), body, 4);
				ImGui.ImDrawList_AddTriangleFilled(dl, ImGui.vec2(cx - sw * 0.5, top + sh * 0.55), ImGui.vec2(cx + sw * 0.5, top + sh * 0.55), ImGui.vec2(cx, top + sh), body);
				ln(dl, cx - sw * 0.5, top, cx - sw * 0.5, top + sh * 0.55, edge, 2);
				ln(dl, cx + sw * 0.5, top, cx + sw * 0.5, top + sh * 0.55, edge, 2);
				ln(dl, cx - sw * 0.5, top, cx + sw * 0.5, top, edge, 2);
				ln(dl, cx - sw * 0.5, top + sh * 0.55, cx, top + sh, edge, 2);
				ln(dl, cx + sw * 0.5, top + sh * 0.55, cx, top + sh, edge, 2);
				if (f.ready)
					ln(dl, cx - sw * 0.5 - 2, top - 2, cx + sw * 0.5 + 2, top - 2, goldCol(0.3 * p), 5);
				var pr = clampF(sw * 0.05, 2.5, 6);
				for (k in 0...ACCUM_MAX) {
					var px = cx - sw * 0.3 + sw * 0.6 * k / 3;
					var lit = f.ready || k < f.stacks;
					disc(dl, px, top + sh * 0.13, pr, lit ? (f.ready ? goldCol(1) : litFill()) : darkFill(), lit ? litEdge() : darkEdge(), 1);
				}
				var isz = sw * 0.5;
				if (!(showIcon && iconAt(dl, f.linkIcon, cx, top + sh * 0.43, isz, linkTint)))
					txt(dl, cx, top + sh * 0.43, isz * 0.7, f.ready ? goldCol(1) : u32(0.7, 0.8, 0.95, 0.9), f.ready ? "FREE" : COUNT_LABELS[clampStacks(f.stacks)]);
			case 3: // Banner: icon plate with a one-line message and a charge strip
				var bh = minF(h - 4, 64);
				var bw = w - 4;
				var bx = x + 2;
				var by = y + (h - bh) * 0.5;
				ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(bx, by), ImGui.vec2(bx + bw, by + bh),
					f.ready ? u32(0.22, 0.15, 0.04, 0.94) : u32(0.05, 0.07, 0.12, 0.94), 6);
				if (f.ready)
					ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(bx - 1, by - 1), ImGui.vec2(bx + bw + 1, by + bh + 1), goldCol(0.12 * p), 7);
				ImGui.ImDrawList_AddRect(dl, ImGui.vec2(bx, by), ImGui.vec2(bx + bw, by + bh), f.ready ? goldCol(0.6 + 0.35 * p) : darkEdge(), 6, 1.6);
				var plate = bh - 8;
				var iconCx = bx + 4 + plate * 0.5;
				disc(dl, iconCx, by + bh * 0.5, plate * 0.5, f.ready ? u32(0.30, 0.20, 0.05, 0.96) : darkFill(), f.ready ? goldCol(0.9) : darkEdge(), 1.5);
				if (!(showIcon && iconAt(dl, f.linkIcon, iconCx, by + bh * 0.5, plate * 0.7, linkTint)))
					crossGlyph(dl, iconCx, by + bh * 0.5, plate * 0.15, u32(1, 1, 1, 0.2), 1.5);
				var tx = bx + plate + 14;
				var tw = bx + bw - 6 - tx;
				var msg = f.ready ? "FREE CAST" : GEM_BANNER_LABELS[clampStacks(f.stacks)];
				var ts = fitSize(msg, clampF(bh * 0.34, 9, 22), tw);
				txtL(dl, tx, by + bh * (bh >= 36 ? 0.34 : 0.5), ts, f.ready ? goldCol(0.8 + 0.2 * p) : u32(0.85, 0.93, 1, 1), msg);
				if (bh >= 36) {
					var sgw = (tw - 9) / 4;
					for (k in 0...ACCUM_MAX) {
						var sx = tx + k * (sgw + 3);
						var lit = f.ready || k < f.stacks;
						ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(sx, by + bh * 0.68), ImGui.vec2(sx + sgw, by + bh * 0.68 + 6),
							lit ? (f.ready ? goldCol(0.95) : litFill()) : darkFill(), 2);
					}
				}
			default: // Gem: a cut stone whose facets light in turn
				var hw = s * 0.5;
				var ty = cy - s * 0.42;
				var gy = cy - s * 0.12;
				var by2 = cy + s * 0.5;
				var ax = cx - hw;
				var bx2 = cx + hw;
				var cxl = cx - hw * 0.5;
				var cxr = cx + hw * 0.5;
				var dark = darkFill();
				if (f.ready)
					ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, cy), s * 0.62, goldCol(0.16 * p), 32);
				var pal = f.ready ? GEM_GOLD : GEM_BLUE;
				ImGui.ImDrawList_AddTriangleFilled(dl, ImGui.vec2(ax, gy), ImGui.vec2(cxl, ty), ImGui.vec2(cx, gy), f.ready || f.stacks >= 1 ? pal[0] : dark);
				ImGui.ImDrawList_AddTriangleFilled(dl, ImGui.vec2(cxl, ty), ImGui.vec2(cxr, ty), ImGui.vec2(cx, gy), f.ready || f.stacks >= 2 ? pal[1] : dark);
				ImGui.ImDrawList_AddTriangleFilled(dl, ImGui.vec2(cxr, ty), ImGui.vec2(bx2, gy), ImGui.vec2(cx, gy), f.ready || f.stacks >= 3 ? pal[2] : dark);
				ImGui.ImDrawList_AddTriangleFilled(dl, ImGui.vec2(ax, gy), ImGui.vec2(bx2, gy), ImGui.vec2(cx, by2), f.ready || f.stacks >= 4 ? pal[3] : dark);
				var ec = f.ready ? goldCol(0.95) : litEdge();
				var oc = f.ready ? ec : darkEdge();
				ln(dl, ax, gy, cxl, ty, f.stacks >= 1 || f.ready ? ec : oc, 1.6);
				ln(dl, cxl, ty, cxr, ty, f.stacks >= 2 || f.ready ? ec : oc, 1.6);
				ln(dl, cxr, ty, bx2, gy, f.stacks >= 3 || f.ready ? ec : oc, 1.6);
				ln(dl, bx2, gy, cx, by2, f.stacks >= 4 || f.ready ? ec : oc, 1.6);
				ln(dl, cx, by2, ax, gy, f.stacks >= 4 || f.ready ? ec : oc, 1.6);
				ln(dl, ax, gy, bx2, gy, oc, 1.2);
				if (f.ready) {
					var g = (f.t * 0.8) % 1;
					ln(dl, cx - hw + 2 * hw * g - 4, ty, cx - hw + 2 * hw * g + 4, by2 - 2, u32(1, 1, 1, 0.5 * (1 - Math.abs(g - 0.5) * 2)), 2);
				}
				var isz = s * 0.4;
				if (!(showIcon && iconAt(dl, f.linkIcon, cx, gy - s * 0.04, isz, linkTint)))
					txt(dl, cx, gy, isz * 0.7, u32(1, 1, 1, 0.9), f.ready ? "5" : DIGITS[clampStacks(f.stacks)]);
		}
		if (labelH > 0) {
			if (f.ready)
				txt(dl, cx, y + h - labelH * 0.5, 14, goldCol(0.8 + 0.2 * p), "FREE");
			else
				txt(dl, cx, y + h - labelH * 0.5, 13, u32(0.9, 0.95, 1, 1), COUNT_LABELS[clampStacks(f.stacks)]);
		}
	}

	// ------------------------------------------------------------------ Skill Watch

	static inline function verdictColor(v:Int, a:Float = 1):Int {
		return switch (v) {
			case ChaincastWatchRow.V_NOW: u32(0.45, 1.0, 0.72, a);
			case ChaincastWatchRow.V_FITS: u32(1.0, 0.80, 0.35, a);
			case ChaincastWatchRow.V_LATE: u32(1.0, 0.43, 0.37, a);
			case ChaincastWatchRow.V_WAIT: u32(0.62, 0.78, 1.0, a);
			default: u32(0.61, 0.66, 0.76, a);
		};
	}

	/** A round skill cell: icon, cooldown-recovery ring, and a check / X badge. */
	static function skillCell(dl:Dynamic, r:ChaincastWatchRow, cx:Float, cy:Float, size:Float, badge:Bool):Void {
		var half = size * 0.5;
		var col = verdictColor(r.verdict);
		var onCd = r.state == ChaincastSkillState.COOLDOWN;
		ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, cy), half, u32(0.03, 0.04, 0.07, 0.95), 28);
		var isz = size * 0.66;
		if (!iconAt(dl, r.icon, cx, cy, isz, onCd ? u32(1, 1, 1, 0.5) : 0xFFFFFFFF))
			txt(dl, cx, cy, size * 0.4, u32(0.6, 0.66, 0.78, 0.9), "?");
		ImGui.ImDrawList_AddCircle(dl, ImGui.vec2(cx, cy), half, u32(0.22, 0.27, 0.36, 0.95), 28, 2.5);
		if (r.state == ChaincastSkillState.READY)
			ImGui.ImDrawList_AddCircle(dl, ImGui.vec2(cx, cy), half, col, 28, 2.5);
		else if (r.progress > 0)
			circleArc(dl, cx, cy, half, r.progress, col, 2.5);
		if (!badge)
			return;
		var br = clampF(size * 0.22, 5, 11);
		var bx = cx + half * 0.72;
		var by = cy + half * 0.72;
		disc(dl, bx, by, br, u32(0.03, 0.04, 0.07, 0.97), col, 1.3);
		if (r.state == ChaincastSkillState.READY)
			checkGlyph(dl, bx, by, br * 0.5, col, 1.8);
		else if (onCd)
			crossGlyph(dl, bx, by, br * 0.42, col, 1.8);
		else
			ln(dl, bx - br * 0.4, by, bx + br * 0.4, by, col, 1.6);
	}

	/** Skills the player assigned, each with a check / X, a cooldown ring and a "fits in the chain" verdict. */
	public static function drawWatchModule(style:Int, x:Float, y:Float, w:Float, h:Float, f:ChaincastFrame, showVerdict:Bool):Void {
		if (w < 20 || h < 16)
			return;
		var dl = ImGui.getWindowDrawList();
		var n = f.rowCount;
		if (n <= 0) {
			txt(dl, x + w * 0.5, y + h * 0.5, fitSize("Assign skills: F6 > Chaincast > Modules", 12, w - 8), u32(0.7, 0.78, 0.9, 0.6),
				"Assign skills: F6 > Chaincast > Modules");
			return;
		}
		switch (style) {
			case 1: // Column
				var lineH = clampF(h / n, 20, 46);
				var top = y + minF(2, maxF(0, (h - lineH * n) * 0.5));
				for (i in 0...n) {
					var r = f.rows[i];
					var cy = top + lineH * (i + 0.5);
					var cs = lineH - 4;
					skillCell(dl, r, x + 2 + cs * 0.5, cy, cs, true);
					var tx = x + cs + 10;
					var tw = x + w - 4 - tx;
					if (!showVerdict)
						txtL(dl, tx, cy, clampF(lineH * 0.4, 9, 14), verdictColor(r.verdict), r.name);
					else if (lineH >= 30) {
						txtL(dl, tx, cy - lineH * 0.2, fitSize(r.name, clampF(lineH * 0.3, 9, 13), tw), u32(0.82, 0.88, 0.97, 0.95), r.name);
						txtL(dl, tx, cy + lineH * 0.2, fitSize(r.longText, clampF(lineH * 0.3, 9, 13), tw), verdictColor(r.verdict), r.longText);
					} else
						txtL(dl, tx, cy, fitSize(r.longText, clampF(lineH * 0.4, 9, 13), tw), verdictColor(r.verdict), r.longText);
				}
			case 2: // Pill
				var ph = clampF(h / n - 3, 20, 36);
				var top2 = y + minF(2, maxF(0, (h - (ph + 3) * n) * 0.5));
				for (i in 0...n) {
					var r = f.rows[i];
					var py = top2 + (ph + 3) * i;
					ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x + 1, py), ImGui.vec2(x + w - 1, py + ph), verdictColor(r.verdict, 0.14), ph * 0.5);
					ImGui.ImDrawList_AddRect(dl, ImGui.vec2(x + 1, py), ImGui.vec2(x + w - 1, py + ph), verdictColor(r.verdict, 0.75), ph * 0.5, 1.4);
					skillCell(dl, r, x + 3 + (ph - 4) * 0.5 + 1, py + ph * 0.5, ph - 4, true);
					var tx = x + ph + 6;
					var tw = x + w - 10 - tx;
					var msg = showVerdict ? r.pillText : r.name;
					txtL(dl, tx, py + ph * 0.5, fitSize(msg, clampF(ph * 0.42, 9, 14), tw), verdictColor(r.verdict), msg);
				}
			case 3: // Orbit: skills circle the chain timer
				var dim = minF(w, h);
				var cell = clampF(dim * 0.28, 16, 44);
				var R = dim * 0.5 - cell * 0.5 - 2;
				if (R < cell * 0.6)
					return;
				var cx = x + w * 0.5;
				var cy = y + h * 0.5;
				ImGui.ImDrawList_AddCircle(dl, ImGui.vec2(cx, cy), R, u32(0.2, 0.27, 0.4, 0.45), 40, 1.2);
				var cr = R * 0.5;
				ImGui.ImDrawList_AddCircle(dl, ImGui.vec2(cx, cy), cr, u32(0.20, 0.26, 0.36, 0.8), 28, 3.5);
				circleArc(dl, cx, cy, cr, f.remainValid ? clamp01(f.remainProg) : 0, f.remainLeft < URGENT_SECONDS && f.remainValid ? u32(1, 0.5, 0.3, 1) : u32(0.45, 0.85, 1, 0.95), 3.5);
				txt(dl, cx, cy, clampF(cr * 0.62, 8, 16), u32(1, 1, 1, f.remainValid ? 0.95 : 0.4), f.remainValid ? fmtSec(f.remainLeft) : "--");
				for (i in 0...n) {
					var a = -Math.PI * 0.5 + Math.PI * 2 * i / n;
					skillCell(dl, f.rows[i], cx + Math.cos(a) * R, cy + Math.sin(a) * R, cell, true);
				}
			case 4: // Compact: glyphs only
				var cell = clampF(minF(w / n - 3, h - 2), 14, 40);
				var total = (cell + 3) * n - 3;
				var x0 = x + (w - total) * 0.5;
				for (i in 0...n)
					skillCell(dl, f.rows[i], x0 + (cell + 3) * i + cell * 0.5, y + h * 0.5, cell, true);
			default: // Row
				var cellW = w / n;
				var textH = showVerdict ? 14.0 : 0.0;
				var cell = clampF(minF(cellW - 6, h - textH - 4), 14, 64);
				var top = y + (h - cell - textH) * 0.5;
				for (i in 0...n) {
					var r = f.rows[i];
					var cx = x + cellW * (i + 0.5);
					skillCell(dl, r, cx, top + cell * 0.5, cell, true);
					if (showVerdict)
						txt(dl, cx, top + cell + 8, fitSize(r.shortText, clampF(cell * 0.3, 9, 12), cellW - 2), verdictColor(r.verdict), r.shortText);
				}
		}
	}

	// ------------------------------------------------------------------ Cast Trail

	static final SLOT_NUMS:Array<String> = ["1", "2", "3", "4", "5"];

	/** One trail slot. `filled` slots show the cast icon (the charge icon when the cast is unknown). */
	static function trailSlot(dl:Dynamic, f:ChaincastFrame, i:Int, cx:Float, cy:Float, size:Float, square:Bool):Void {
		var free = i == ACCUM_MAX;
		var filled = free ? f.freeIcon.length > 0 : i < f.trailCount;
		var open = free && !filled;
		var half = size * 0.5;
		var p = pulseVal(free && f.ready);
		var edge = free ? goldCol(open ? (f.ready ? 0.7 + 0.3 * p : 0.55) : 0.95) : (filled ? litEdge() : darkEdge());
		if (free && f.ready)
			ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, cy), half + 4, goldCol(0.2 * p), 24);
		if (square)
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(cx - half, cy - half), ImGui.vec2(cx + half, cy + half), darkFill(), 5);
		else
			ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, cy), half, darkFill(), 24);
		if (filled) {
			var key = free ? f.freeIcon : f.trail[i];
			if (key.length == 0)
				key = GameIcons.CHAINCAST;
			if (!iconAt(dl, key, cx, cy, size * (square ? 0.84 : 0.7), 0xFFFFFFFF))
				txt(dl, cx, cy, size * 0.4, u32(0.8, 0.9, 1, 0.8), SLOT_NUMS[i]);
		} else
			txt(dl, cx, cy, size * 0.36, free ? goldCol(0.45) : u32(0.5, 0.58, 0.7, 0.45), free ? "FREE" : SLOT_NUMS[i]);
		if (square)
			ImGui.ImDrawList_AddRect(dl, ImGui.vec2(cx - half, cy - half), ImGui.vec2(cx + half, cy + half), edge, 5, free ? 2 : 1.5);
		else
			ImGui.ImDrawList_AddCircle(dl, ImGui.vec2(cx, cy), half, edge, 24, free ? 2.5 : 1.8);
	}

	/** The casts that charged the chain, plus an open gold slot for the free cast. */
	public static function drawTrailModule(style:Int, x:Float, y:Float, w:Float, h:Float, f:ChaincastFrame, showFree:Bool):Void {
		if (w < 20 || h < 16)
			return;
		var dl = ImGui.getWindowDrawList();
		var n = showFree ? SLOT_COUNT : ACCUM_MAX;
		if (style == 2) { // Ladder: first cast at the bottom, the free slot on top
			var cell = clampF(minF(w - 4, (h - 3 * (n - 1)) / n), 14, 48);
			var total = cell * n + 3 * (n - 1);
			var top = y + (h - total) * 0.5;
			var cx = x + w * 0.5;
			ln(dl, cx, top + cell * 0.5, cx, top + total - cell * 0.5, u32(0.32, 0.55, 0.92, 0.3), 2);
			for (i in 0...n)
				trailSlot(dl, f, i, cx, top + total - cell * (i + 0.5) - 3 * i, cell, false);
			return;
		}
		var gap = 4.0;
		var cell = clampF(minF((w - gap * (n - 1)) / n, h - 2), 14, 56);
		var total = cell * n + gap * (n - 1);
		var x0 = x + (w - total) * 0.5;
		var cy = y + h * 0.5;
		if (style == 0)
			ln(dl, x0 + cell * 0.5, cy, x0 + total - cell * 0.5, cy, u32(0.32, 0.55, 0.92, 0.35), 3);
		for (i in 0...n)
			trailSlot(dl, f, i, x0 + (cell + gap) * i + cell * 0.5, cy, cell, style == 1);
	}

	// ------------------------------------------------------------------ Free Cast Banner

	static var edgeX:Float = 0;
	static var edgeY:Float = 0;

	/** Point at parameter `u` (0..1) around a rectangle's perimeter, into edgeX / edgeY. */
	static function perimeter(x:Float, y:Float, w:Float, h:Float, u:Float):Void {
		var per = 2 * (w + h);
		var d = (u - Math.floor(u)) * per;
		if (d < w) {
			edgeX = x + d;
			edgeY = y;
		} else if (d < w + h) {
			edgeX = x + w;
			edgeY = y + d - w;
		} else if (d < 2 * w + h) {
			edgeX = x + w - (d - w - h);
			edgeY = y + h;
		} else {
			edgeX = x;
			edgeY = y + h - (d - 2 * w - h);
		}
	}

	/**
	 * A short "FREE CAST" announcement for the ready edge. `f.readyAge` is seconds since the edge;
	 * a ghost frame (unlocked, nothing to announce) previews the shape at low alpha.
	 */
	public static function drawBannerModule(style:Int, x:Float, y:Float, w:Float, h:Float, f:ChaincastFrame):Void {
		if (w < 40 || h < 16)
			return;
		var dl = ImGui.getWindowDrawList();
		var age = f.bannerGhost ? 0.8 : f.readyAge;
		var grow = clamp01(age / 0.25);
		var fade = 1 - clamp01((age - (BANNER_SECONDS - 0.6)) / 0.6);
		var a = grow * fade * (f.bannerGhost ? 0.4 : 1.0);
		if (a <= 0.01)
			return;
		var cx = x + w * 0.5;
		var cy = y + h * 0.5;
		var pw = (w - 4) * (0.35 + 0.65 * grow);
		var ph = minF(h - 4, 56);
		var pulse = 0.75 + 0.25 * Math.sin(f.t * 9);
		var msg = "FREE CAST";
		switch (style) {
			case 1: // Flare: a rotating starburst behind the words
				var rays = 14;
				var reach = minF(w, h * 3) * 0.5 * (0.5 + 0.5 * grow);
				for (k in 0...rays) {
					var ang = k * Math.PI * 2 / rays + f.t * 0.5;
					var len = reach * (k % 2 == 0 ? 1.0 : 0.62);
					ln(dl, cx + Math.cos(ang) * ph * 0.3, cy + Math.sin(ang) * ph * 0.3, cx + Math.cos(ang) * len, cy + Math.sin(ang) * len * 0.5,
						goldCol(0.45 * a), k % 2 == 0 ? 2.5 : 1.5);
				}
				ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, cy), ph * 0.9, goldCol(0.16 * a * pulse), 32);
				txt(dl, cx, cy, fitSize(msg, ph * 0.62, w - 12), goldCol(a), msg);
			case 2: // Marquee: lights chase around a plate
				var bx = cx - pw * 0.5;
				var by = cy - ph * 0.5;
				ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(bx, by), ImGui.vec2(bx + pw, by + ph), u32(0.12, 0.08, 0.02, 0.92 * a), 6);
				ImGui.ImDrawList_AddRect(dl, ImGui.vec2(bx, by), ImGui.vec2(bx + pw, by + ph), goldCol(0.9 * a), 6, 2);
				var bulbs = 22;
				var step = Math.floor(f.t * 9);
				for (k in 0...bulbs) {
					perimeter(bx + 3, by + 3, pw - 6, ph - 6, k / bulbs);
					ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(edgeX, edgeY), 2.2, (k + step) % 3 == 0 ? u32(1, 0.95, 0.6, a) : goldCol(0.3 * a), 8);
				}
				txt(dl, cx, cy, fitSize(msg, ph * 0.5, pw - 20), goldCol(a), msg);
			default: // Ribbon: a gold band with swallow-tail ends
				var bx = cx - pw * 0.5;
				var by = cy - ph * 0.5;
				var tail = ph * 0.35;
				ImGui.ImDrawList_AddRectFilledMultiColor(dl, ImGui.vec2(bx + tail, by), ImGui.vec2(bx + pw - tail, by + ph),
					u32(0.95, 0.70, 0.22, 0.95 * a), u32(1.0, 0.86, 0.45, 0.95 * a), u32(0.80, 0.52, 0.12, 0.95 * a), u32(0.70, 0.44, 0.10, 0.95 * a));
				ImGui.ImDrawList_AddTriangleFilled(dl, ImGui.vec2(bx + tail, by), ImGui.vec2(bx, by), ImGui.vec2(bx + tail, by + ph * 0.5), u32(0.65, 0.40, 0.08, 0.95 * a));
				ImGui.ImDrawList_AddTriangleFilled(dl, ImGui.vec2(bx + tail, by + ph), ImGui.vec2(bx, by + ph), ImGui.vec2(bx + tail, by + ph * 0.5), u32(0.65, 0.40, 0.08, 0.95 * a));
				ImGui.ImDrawList_AddTriangleFilled(dl, ImGui.vec2(bx + pw - tail, by), ImGui.vec2(bx + pw, by), ImGui.vec2(bx + pw - tail, by + ph * 0.5), u32(0.65, 0.40, 0.08, 0.95 * a));
				ImGui.ImDrawList_AddTriangleFilled(dl, ImGui.vec2(bx + pw - tail, by + ph), ImGui.vec2(bx + pw, by + ph), ImGui.vec2(bx + pw - tail, by + ph * 0.5), u32(0.65, 0.40, 0.08, 0.95 * a));
				ImGui.ImDrawList_AddRect(dl, ImGui.vec2(bx + tail, by), ImGui.vec2(bx + pw - tail, by + ph), u32(1, 0.95, 0.7, 0.8 * a), 0, 1.5);
				txt(dl, cx, cy, fitSize(msg, ph * 0.55, pw - tail * 2 - 12), u32(0.18, 0.10, 0.02, a), msg);
		}
	}
}

/**
 * Everything a module draws from, as plain values. The live windows fill one per frame from the frozen
 * caches; the hub fills a synthetic one. Renderers never read a cache themselves.
 */
class ChaincastFrame {
	public var stacks:Int = 0;
	public var ready:Bool = false;
	public var pulse:Bool = false;
	public var remainValid:Bool = false;
	public var remainLeft:Float = 0;
	public var remainProg:Float = 0;
	public var t:Float = 0;
	/** Seconds since the not-ready -> ready edge. */
	public var readyAge:Float = 999;
	public var bannerGhost:Bool = false;
	public var linkIcon:String = "";
	public var skill:ChaincastSkillState = new ChaincastSkillState();
	public var rows:Array<ChaincastWatchRow> = [for (_ in 0...ChaincastConfig.MAX_ROT) new ChaincastWatchRow()];
	public var rowCount:Int = 0;
	public var trail:Array<String> = ["", "", "", ""];
	public var trailCount:Int = 0;
	public var freeIcon:String = "";

	public function new() {}
}

/** One assigned Skill Watch skill, ready to draw. Strings are rebuilt only when their key changes. */
class ChaincastWatchRow {
	public static inline var V_NONE:Int = 0;
	/** Off cooldown. */
	public static inline var V_NOW:Int = 1;
	/** On cooldown but back before the chain ends. */
	public static inline var V_FITS:Int = 2;
	/** On cooldown past the end of the chain. */
	public static inline var V_LATE:Int = 3;
	/** On cooldown and no chain timer is running to compare against. */
	public static inline var V_WAIT:Int = 4;

	public var icon:String = "";
	public var name:String = "";
	public var state:Int = ChaincastSkillState.UNLINKED;
	public var progress:Float = 0;
	public var cdLeft:Float = 0;
	public var verdict:Int = V_NONE;
	public var longText:String = "";
	public var pillText:String = "";
	public var shortText:String = "";
	public var textKey:Int = -1;

	public function new() {}
}
