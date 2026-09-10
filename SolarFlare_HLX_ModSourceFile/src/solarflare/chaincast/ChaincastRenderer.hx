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

	/** Badge (N/4 or READY) + icon rail, matching live HUD. */
	public static function drawHead(rowW:Single, rowH:Single, stacks:Int, ready:Bool, showBadge:Bool,
			pulse:Bool = false):Void {
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
			drawBlocks(pipW, rowH, stacks, ready, pulse);
		} else {
			drawBlocks(rowW, rowH, stacks, ready, pulse);
		}
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
