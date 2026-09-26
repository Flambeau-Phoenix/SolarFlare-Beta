package solarflare.geaux;

import solarflare.ui.CursorCaptureFix;
import solarflare.ui.HudChrome;
import solarflare.ui.SettingsStore;
import solarflare.ui.FeatureProfiles;
import solarflare.HealthCache;
import imgui.ImGui;
import imgui.Structs.ImVec4;
import imgui.Enums.ImGuiColorEditFlags;
import imgui.Enums.ImGuiCond;
import imgui.Enums.ImGuiWindowFlags;
import imgui.ref.BoolRef;
import imgui.ref.FloatRef;
import imgui.ref.IntRef;

/**
 * F6 â†’ Geaux layout only. Slots come from hero.skillSlots / skill-book drag.
 */
class GeauxConfig {
	public static inline var MIN_DIM:Int = 1;
	public static inline var MAX_DIM:Int = 6;
	public static inline var MIN_W:Single = 96;
	public static inline var MAX_W:Single = 900;
	public static inline var MIN_H:Single = 72;
	public static inline var MAX_H:Single = 720;



	public var open:BoolRef;
	/** When true the Geaux bar overlay is drawn. Independent of GetRifty / Local Time. */
	public var enabled:BoolRef;
	public var rows = new IntRef(2);
	public var cols = new IntRef(3);
	public var width = new FloatRef(240);
	public var height = new FloatRef(168);
	public var sizeDirty = true;
	public var slotIds:Array<String> = [];
	public var slotGlyphs:Array<String> = [];
	/** User-typed keybind labels (not resolved from the game). */
	public var slotHotkeys:Array<String> = [];
	var hotkeyBytes:Array<haxe.io.Bytes> = [];
	static inline var HOTKEY_BUF:Int = 16;
	public var chrome:HudChrome;
	public var style:GeauxStyle;
	/** Manual Server Region when the engine does not expose one. */
	public var regionOverride:String = "";
	var regionBytes:haxe.io.Bytes;
	static inline var REGION_BUF:Int = 64;

	public function new() {
		open = new BoolRef(false);
		enabled = new BoolRef(true);
		chrome = new HudChrome(80, 280);
		style = new GeauxStyle();
	}

	public function ensureSlots():Void {
		var beforeIds = slotIds.copy();
		var beforeGlyphs = slotGlyphs.copy();
		var beforeHotkeys = slotHotkeys.copy();
		var n = visibleCount();
		while (slotIds.length < n)
			slotIds.push("");
		while (slotGlyphs.length < n)
			slotGlyphs.push("");
		while (slotHotkeys.length < n)
			slotHotkeys.push("");
		while (hotkeyBytes.length < n) {
			var b = haxe.io.Bytes.alloc(HOTKEY_BUF);
			hotkeyBytes.push(b);
		}
		var changed = beforeIds.length != slotIds.length || beforeGlyphs.length != slotGlyphs.length || beforeHotkeys.length != slotHotkeys.length;
		if (changed)
			syncHotkeyBuffers();
		if (changed)
			GeauxLog.log("ENSURE_SLOTS", "GeauxConfig.ensureSlots", {
				activeKey: FeatureProfiles.activeKey,
				rows: rows.get(),
				cols: cols.get(),
				before: {slotIds: beforeIds, slotGlyphs: beforeGlyphs, slotHotkeys: beforeHotkeys},
				after: {slotIds: slotIds.copy(), slotGlyphs: slotGlyphs.copy(), slotHotkeys: slotHotkeys.copy()}
			});
	}

	/** Rebuild persistent input buffers only after a layout mutation or load. */
	public function syncHotkeyBuffers():Void {
		var n = slotHotkeys.length;
		while (hotkeyBytes.length < n)
			hotkeyBytes.push(haxe.io.Bytes.alloc(HOTKEY_BUF));
		for (i in 0...n)
			writeHotkeyBuf(i, slotHotkeys[i]);
	}

	public function visibleCount():Int {
		var r = rows.get();
		var c = cols.get();
		if (r < MIN_DIM)
			r = MIN_DIM;
		if (c < MIN_DIM)
			c = MIN_DIM;
		if (r > MAX_DIM)
			r = MAX_DIM;
		if (c > MAX_DIM)
			c = MAX_DIM;
		return r * c;
	}

	public function dumpLayout():Dynamic {
		ensureSlots();
		var slots:Array<String> = [];
		for (s in slotIds)
			slots.push(GeauxCache.coerceSkillId(s));
		var glyphs:Array<String> = [];
		for (s in slotGlyphs)
			glyphs.push(GeauxCache.coerceSkillId(s));
		var hotkeys:Array<String> = [];
		for (s in slotHotkeys)
			hotkeys.push(sanitizeHotkey(s));
		return {
			on: enabled.get(),
			rows: rows.get(),
			cols: cols.get(),
			w: width.get(),
			h: height.get(),
			slots: slots,
			glyphs: glyphs,
			hotkeys: hotkeys,
			chrome: chrome != null ? {
				hudLayoutVersion: chrome.hudLayoutVersion,
				lock: chrome.locked.get(),
				trans: chrome.transparent.get(),
				collapsed: chrome.collapsed.get(),
				sun: chrome.showGrip.get(),
				x: chrome.x.get(),
				y: chrome.y.get()
			} : {},
			style: style != null ? style.dump() : {}
		};
	}

	public function applyLayout(data:Dynamic):Void {
		if (data == null) {
			GeauxLog.log("APPLY_LAYOUT_NULL", "GeauxConfig.applyLayout", {
				activeKey: FeatureProfiles.activeKey,
				rows: rows.get(),
				cols: cols.get(),
				slotIds: slotIds.copy()
			});
			return;
		}
		var old = {
			on: enabled.get(),
			rows: rows.get(),
			cols: cols.get(),
			w: width.get(),
			h: height.get(),
			slotIds: slotIds.copy(),
			slotGlyphs: slotGlyphs.copy(),
			slotHotkeys: slotHotkeys.copy()
		};
		if (data.on != null)
			enabled.set(data.on == true || data.on == 1 || data.on == "true");
		else if (data.hidden != null)
			enabled.set(!(data.hidden == true || data.hidden == 1 || data.hidden == "true"));
		try {
			if (data.rows != null)
				rows.set(Std.int(data.rows));
			if (data.cols != null)
				cols.set(Std.int(data.cols));
			if (data.w != null)
				width.set(data.w);
			if (data.h != null)
				height.set(data.h);
		} catch (_:Dynamic) {}
		try {
			slotIds = [];
			if (data.slots != null) {
				var arr:Array<Dynamic> = data.slots;
				for (i in 0...arr.length)
					slotIds.push(SettingsStore.cleanJsonString(arr[i]));
			}
		} catch (_:Dynamic) {}
		try {
			slotGlyphs = [];
			if (data.glyphs != null) {
				var arr:Array<Dynamic> = data.glyphs;
				for (i in 0...arr.length)
					slotGlyphs.push(SettingsStore.cleanJsonString(arr[i]));
			}
		} catch (_:Dynamic) {}
		try {
			slotHotkeys = [];
			if (data.hotkeys != null) {
				var arr:Array<Dynamic> = data.hotkeys;
				for (i in 0...arr.length)
					slotHotkeys.push(SettingsStore.cleanJsonString(arr[i]));
			}
		} catch (_:Dynamic) {}
		try {
			if (chrome != null && data.chrome != null) {
				var ch:Dynamic = data.chrome;
				chrome.hudLayoutVersion = ch.hudLayoutVersion != null ? Std.int(ch.hudLayoutVersion) : 0;
				if (ch.lock != null)
					chrome.locked.set(ch.lock == true);
				if (ch.trans != null)
					chrome.transparent.set(ch.trans == true);
				if (ch.collapsed != null)
					chrome.collapsed.set(ch.collapsed == true);
				if (ch.sun != null)
					chrome.showGrip.set(ch.sun == true);
				if (ch.x != null)
					chrome.x.set(ch.x);
				if (ch.y != null)
					chrome.y.set(ch.y);
				chrome.posDirty = true;
				chrome.expandSizeDirty = true;
			}
		} catch (_:Dynamic) {}
		if (style == null)
			style = new GeauxStyle();
		try
			style.apply(data.style)
		catch (_:Dynamic) {}
		var count = visibleCount();
		while (slotIds.length > count) slotIds.pop();
		while (slotGlyphs.length > count) slotGlyphs.pop();
		while (slotHotkeys.length > count) slotHotkeys.pop();
		ensureSlots();
		syncHotkeyBuffers();
		sizeDirty = true;
		if (chrome != null)
			chrome.posDirty = true;
		GeauxCache.markLayoutDirty();
		GeauxLog.log("APPLY_LAYOUT", "GeauxConfig.applyLayout", {
			activeKey: FeatureProfiles.activeKey,
			incoming: data,
			before: old,
			after: {
				on: enabled.get(),
				rows: rows.get(),
				cols: cols.get(),
				w: width.get(),
				h: height.get(),
				slotIds: slotIds.copy(),
				slotGlyphs: slotGlyphs.copy(),
				slotHotkeys: slotHotkeys.copy()
			}
		});
	}

	/**
	 * Assigns a skill to a cell, clearing any obsolete icon override.
	 */
	public function assignCell(index:Int, skillId:Dynamic):Void {
		ensureSlots();
		if (index < 0 || index >= visibleCount())
			return;
		var normalized = GeauxCache.coerceSkillId(skillId);
		if (normalized.length == 0) {
			GeauxLog.log("ASSIGN_CELL_REJECT", "GeauxConfig.assignCell", {
				activeKey: FeatureProfiles.activeKey, rows: rows.get(), cols: cols.get(),
				index: index, rejected: skillId, slotIds: slotIds.copy()
			});
			return;
		}
		slotIds[index] = normalized;
		if (index < slotGlyphs.length)
			slotGlyphs[index] = "";
		GeauxCache.markLayoutDirty();
		SettingsStore.markDirty();
		GeauxLog.log("ASSIGN_CELL", "GeauxConfig.assignCell", {activeKey: FeatureProfiles.activeKey, rows: rows.get(), cols: cols.get(), slotIds: slotIds.copy(), slotGlyphs: slotGlyphs.copy(), slotHotkeys: slotHotkeys.copy(), index: index, skillId: normalized});
	}

	/**
	 * Clears the assigned skill and icon override while strictly preserving key assignment.
	 */
	public function clearCell(index:Int):Void {
		ensureSlots();
		if (index < 0 || index >= visibleCount())
			return;
		slotIds[index] = "";
		if (index < slotGlyphs.length)
			slotGlyphs[index] = "";
		GeauxCache.markLayoutDirty();
		SettingsStore.markDirty();
		GeauxLog.log("CLEAR_CELL", "GeauxConfig.clearCell", {activeKey: FeatureProfiles.activeKey, rows: rows.get(), cols: cols.get(), slotIds: slotIds.copy(), slotGlyphs: slotGlyphs.copy(), slotHotkeys: slotHotkeys.copy(), index: index});
	}

	/**
	 * Swaps skills and icon overrides between two cells.
	 * Key labels remain attached to physical grid positions.
	 */
	public function swapCells(indexA:Int, indexB:Int):Void {
		ensureSlots();
		var n = visibleCount();
		if (indexA < 0 || indexA >= n || indexB < 0 || indexB >= n || indexA == indexB)
			return;
		var tmpId = slotIds[indexA];
		slotIds[indexA] = slotIds[indexB];
		slotIds[indexB] = tmpId;

		var tmpGlyph = indexA < slotGlyphs.length ? slotGlyphs[indexA] : "";
		var targetGlyph = indexB < slotGlyphs.length ? slotGlyphs[indexB] : "";
		slotGlyphs[indexA] = targetGlyph;
		slotGlyphs[indexB] = tmpGlyph;

		GeauxCache.markLayoutDirty();
		SettingsStore.markDirty();
		GeauxLog.log("SWAP_CELLS", "GeauxConfig.swapCells", {activeKey: FeatureProfiles.activeKey, rows: rows.get(), cols: cols.get(), slotIds: slotIds.copy(), slotGlyphs: slotGlyphs.copy(), slotHotkeys: slotHotkeys.copy(), indexA: indexA, indexB: indexB});
	}

	/** New character: empty skill pins so the live action bar fills this profile. */
	public function applyEmptySlots():Void {
		var before = {slotIds: slotIds.copy(), slotGlyphs: slotGlyphs.copy(), slotHotkeys: slotHotkeys.copy()};
		ensureSlots();
		var n = slotIds.length;
		var i = 0;
		while (i < n) {
			slotIds[i] = "";
			i++;
		}
		i = 0;
		while (i < slotGlyphs.length) {
			slotGlyphs[i] = "";
			i++;
		}
		i = 0;
		while (i < slotHotkeys.length) {
			slotHotkeys[i] = "";
			writeHotkeyBuf(i, "");
			i++;
		}
		GeauxLog.log("APPLY_EMPTY_SLOTS", "GeauxConfig.applyEmptySlots", {
			activeKey: FeatureProfiles.activeKey, rows: rows.get(), cols: cols.get(), before: before,
			after: {slotIds: slotIds.copy(), slotGlyphs: slotGlyphs.copy(), slotHotkeys: slotHotkeys.copy()}
		});
	}

	public static function sanitizeHotkey(v:Dynamic):String {
		if (v == null)
			return "";
		var s = "";
		try {
			if (Std.isOfType(v, String))
				s = v;
			else
				s = Std.string(v);
		} catch (_:Dynamic)
			return "";
		if (s == null)
			return "";
		s = StringTools.trim(s);
		if (s.length == 0 || s == "null")
			return "";
		if (s.indexOf("{") >= 0 || s.indexOf("}") >= 0)
			return "";
		if (s.toLowerCase().indexOf("bytes") >= 0)
			return "";
		s = StringTools.replace(s, "\n", "");
		s = StringTools.replace(s, "\r", "");
		if (s.length > 12)
			s = s.substr(0, 12);
		return s;
	}

	function writeHotkeyBuf(i:Int, s:String):Void {
		if (i < 0 || i >= hotkeyBytes.length)
			return;
		var b = hotkeyBytes[i];
		if (b == null)
			return;
		if (s == null)
			s = "";
		var n = 0;
		while (n < HOTKEY_BUF - 1 && n < s.length) {
			b.set(n, s.charCodeAt(n));
			n++;
		}
		while (n < HOTKEY_BUF) {
			b.set(n, 0);
			n++;
		}
	}

	function readHotkeyBuf(i:Int):String {
		if (i < 0 || i >= hotkeyBytes.length)
			return "";
		var b = hotkeyBytes[i];
		if (b == null)
			return "";
		var buf = new StringBuf();
		var n = 0;
		while (n < HOTKEY_BUF - 1) {
			var c = b.get(n);
			if (c == 0)
				break;
			if (c >= 32 && c < 127)
				buf.addChar(c);
			n++;
		}
		return sanitizeHotkey(buf.toString());
	}

	public function setRegionOverride(s:String):Void {
		regionOverride = s != null ? StringTools.trim(s) : "";
		ensureRegionBuf();
		writeRegionBuf(regionOverride);
	}

	function ensureRegionBuf():Void {
		if (regionBytes != null)
			return;
		regionBytes = haxe.io.Bytes.alloc(REGION_BUF);
		writeRegionBuf(regionOverride);
	}

	function writeRegionBuf(s:String):Void {
		if (regionBytes == null)
			return;
		if (s == null)
			s = "";
		var i = 0;
		while (i < REGION_BUF - 1 && i < s.length) {
			regionBytes.set(i, s.charCodeAt(i));
			i++;
		}
		while (i < REGION_BUF) {
			regionBytes.set(i, 0);
			i++;
		}
	}

	function readRegionBuf():String {
		if (regionBytes == null)
			return "";
		var b = new StringBuf();
		var i = 0;
		while (i < REGION_BUF - 1) {
			var c = regionBytes.get(i);
			if (c == 0)
				break;
			b.addChar(c);
			i++;
		}
		return StringTools.trim(b.toString());
	}

	static function bookLabel(id:String):String {
		for (i in 0...GeauxCache.bookIds.length) {
			if (GeauxCache.bookIds[i] == id)
				return GeauxCache.bookLabels[i];
		}
		return id;
	}

	public function draw():Void {
		if (!open.get())
			return;
		ImGui.setNextWindowSize(ImGui.vec2(380, 140), ImGuiCond.FirstUseEver);
		if (HudChrome.beginPanel("Geaux##solarflare_cfg", open, "Geaux")) {
			ImGui.textWrapped("Use the Geaux Builder for grid, catalog drag-and-drop, and visuals.");
			ImGui.textDisabled("Legacy editor retired - F6 -> Geaux -> Open Geaux Builder.");
			if (ImGui.checkbox("Show Geaux bar##geaux_enabled", enabled)) {
				if (enabled.get()) {
					sizeDirty = true;
					if (chrome != null)
						chrome.posDirty = true;
				}
				SettingsStore.markDirty();
			}
			chrome.drawToggles("geaux");
		}
		HudChrome.endPanel();
	}

	/** Slot-local presentation controls reused by the consolidated Geaux Builder. */
	public function drawSlotExtras(i:Int):Void {
		drawGlyphAssignment(i);
		drawHotkeyAssignment(i);
	}

	public function hotkeyLabel(i:Int):String {
		ensureSlots();
		if (i < 0 || i >= slotHotkeys.length || slotHotkeys[i] == null)
			return "";
		return slotHotkeys[i];
	}

	public function drawGlyphAssignment(i:Int):Void {
		ensureSlots();
		if (i < 0 || i >= visibleCount())
			return;
		ImGui.setNextItemWidth(150);
		var glyph = i < slotGlyphs.length && slotGlyphs[i] != null ? slotGlyphs[i] : "";
		if (ImGui.beginCombo("Icon##gb_g" + i, GeauxGlyphs.labelOf(glyph))) {
			for (gi in 0...GeauxGlyphs.ids.length) {
				var gid = GeauxGlyphs.ids[gi];
				if (ImGui.selectable(GeauxGlyphs.labels[gi] + "##gb_gi" + i + gid, glyph == gid)) {
					slotGlyphs[i] = gid;
					SettingsStore.markDirty();
					GeauxLog.log("GLYPH_CHANGE", "GeauxConfig.drawGlyphAssignment", {
						activeKey: FeatureProfiles.activeKey, index: i, glyph: gid,
						rows: rows.get(), cols: cols.get(), slotIds: slotIds.copy(), slotGlyphs: slotGlyphs.copy()
					});
				}
			}
			ImGui.endCombo();
		}
	}

	public function drawHotkeyAssignment(i:Int):Void {
		ensureSlots();
		if (i < 0 || i >= visibleCount())
			return;
		var clearW:Single = 48;
		var avail:Single = ImGui.getContentRegionAvail().x;
		ImGui.setNextItemWidth(Math.max(40, avail - clearW - 6));
		if (ImGui.inputText("##gb_hk" + i, hotkeyBytes[i].getData(), HOTKEY_BUF)) {
			slotHotkeys[i] = readHotkeyBuf(i);
			SettingsStore.markDirty();
			GeauxLog.log("HOTKEY_CHANGE", "GeauxConfig.drawHotkeyAssignment", {
				activeKey: FeatureProfiles.activeKey, index: i, hotkey: slotHotkeys[i],
				rows: rows.get(), cols: cols.get(), slotIds: slotIds.copy(), slotHotkeys: slotHotkeys.copy()
			});
		}
		ImGui.sameLine(0, 6);
		if (ImGui.button("Clear##gb_hk_clear" + i, ImGui.vec2(clearW, 0))) {
			slotHotkeys[i] = "";
			writeHotkeyBuf(i, "");
			SettingsStore.markDirty();
			GeauxLog.log("HOTKEY_CLEAR", "GeauxConfig.drawHotkeyAssignment", {
				activeKey: FeatureProfiles.activeKey, index: i,
				rows: rows.get(), cols: cols.get(), slotIds: slotIds.copy(), slotHotkeys: slotHotkeys.copy()
			});
		}
	}
}

/**
 * Visual knobs for Geaux cells. Colors are persistent hl.Bytes for colorEdit4.
 */
class GeauxStyle {
	public static inline var CD_SHOW_DIM:Int = 0;
	public static inline var CD_HIDE:Int = 1;
	public static inline var CD_SHOW_FULL:Int = 2;

	public static inline var ATTN_NONE:Int = 0;
	public static inline var ATTN_PULSE:Int = 1;
	public static inline var ATTN_BRIGHT:Int = 2;
	/** The aura Glow tile's effect: bright core with sparks travelling the border. */
	public static inline var ATTN_PROC:Int = 3;

	public static inline var CD_ATTN_NONE:Int = 0;
	public static inline var CD_ATTN_DIM:Int = 1;
	public static inline var CD_ATTN_OUTLINE:Int = 2;

	public var gap = new FloatRef(4);
	public var padding = new FloatRef(8);
	public var rounding = new FloatRef(5);
	public var border = new FloatRef(1.5);
	public var bgAlpha = new FloatRef(0.82);
	public var glyphScale = new FloatRef(1.0);

	public var readyAttention = new IntRef(ATTN_PULSE);
	public var readyGlowColor:hl.Bytes;
	public var cooldownAttention = new IntRef(CD_ATTN_DIM);

	public var showLabels = new BoolRef(false);
	public var showGroupTags = new BoolRef(true);
	public var showCdText = new BoolRef(true);
	public var showPinwheel = new BoolRef(true);
	public var showHotkeys = new BoolRef(true);
	public var showCharges = new BoolRef(true);
	public var dimOnCd = new BoolRef(true);
	public var cdDisplay = new IntRef(CD_SHOW_DIM);
	public var dimOnNoResource = new BoolRef(true);

	public var emptyFill:hl.Bytes;
	public var readyWep:hl.Bytes;
	public var readyCls:hl.Bytes;
	public var readySig:hl.Bytes;
	public var readyDefault:hl.Bytes;
	public var borderReady:hl.Bytes;
	public var borderIdle:hl.Bytes;
	public var cdText:hl.Bytes;
	public var windowBg:hl.Bytes;

	public function new() {
		emptyFill = ImGui.v4(0.12, 0.13, 0.15, 1);
		readyWep = ImGui.v4(0.72, 0.48, 0.18, 1);
		readyCls = ImGui.v4(0.22, 0.48, 0.78, 1);
		readySig = ImGui.v4(0.92, 0.72, 0.18, 1);
		readyDefault = ImGui.v4(0.35, 0.40, 0.48, 1);
		borderReady = ImGui.v4(1, 1, 1, 0.45);
		readyGlowColor = ImGui.v4(1, 0.752941, 0.25098, 1);
		borderIdle = ImGui.v4(0.28, 0.30, 0.34, 1);
		cdText = ImGui.v4(1, 0.92, 0.55, 1);
		windowBg = ImGui.v4(0.08, 0.09, 0.11, 1);
	}

	public function effectiveCdDisplay():Int {
		var m = cdDisplay.get();
		if (m < CD_SHOW_DIM || m > CD_SHOW_FULL)
			m = dimOnCd.get() ? CD_SHOW_DIM : CD_SHOW_FULL;
		return m;
	}

	public function hideOnCooldown():Bool {
		return effectiveCdDisplay() == CD_HIDE;
	}


	public function shouldDimOnCooldown():Bool {
		return effectiveCdDisplay() == CD_SHOW_DIM;
	}

	public function drawEditor():Bool {
		var dirty = false;
		if (ImGui.collapsingHeader("Look")) {
			if (solarflare.ui.BuilderSlider.draw("Padding##geaux", padding, 0, 32, "%.0f px"))
				dirty = true;
			if (solarflare.ui.BuilderSlider.draw("Gap##geaux", gap, 0, 16, "%.0f px"))
				dirty = true;
			if (solarflare.ui.BuilderSlider.draw("Rounding##geaux", rounding, 0, 16, "%.1f"))
				dirty = true;
			if (solarflare.ui.BuilderSlider.draw("Border##geaux", border, 0.5, 4, "%.1f"))
				dirty = true;
			if (solarflare.ui.BuilderSlider.draw("Window alpha##geaux", bgAlpha, 0, 1, "%.2f"))
				dirty = true;
			if (solarflare.ui.BuilderSlider.draw("Glyph scale##geaux", glyphScale, 0.5, 1.4, "%.2f"))
				dirty = true;

			ImGui.separatorText("Attention & Effects");
			var readyAttnLabel = switch (readyAttention.get()) {
				case 0: "None";
				case 2: "Bright";
				case 3: "Aura glow";
				default: "Pulse";
			};
			if (ImGui.beginCombo("Ready attention##geaux_ready_attn", readyAttnLabel)) {
				if (ImGui.selectable("None##r_none", readyAttention.get() == 0)) { readyAttention.set(0); dirty = true; }
				if (ImGui.selectable("Pulse##r_pulse", readyAttention.get() == 1)) { readyAttention.set(1); dirty = true; }
				if (ImGui.selectable("Bright##r_bright", readyAttention.get() == 2)) { readyAttention.set(2); dirty = true; }
				if (ImGui.selectable("Aura glow##r_proc", readyAttention.get() == 3)) { readyAttention.set(3); dirty = true; }
				ImGui.endCombo();
			}

			var cdAttnLabel = switch (cooldownAttention.get()) {
				case 0: "None";
				case 2: "Outline";
				default: "Dim";
			};
			if (ImGui.beginCombo("Cooldown attention##geaux_cd_attn", cdAttnLabel)) {
				if (ImGui.selectable("None##c_none", cooldownAttention.get() == 0)) { cooldownAttention.set(0); dirty = true; }
				if (ImGui.selectable("Dim##c_dim", cooldownAttention.get() == 1)) { cooldownAttention.set(1); dirty = true; }
				if (ImGui.selectable("Outline##c_outline", cooldownAttention.get() == 2)) { cooldownAttention.set(2); dirty = true; }
				ImGui.endCombo();
			}

			if (ImGui.checkbox("Show group tags", showGroupTags))
				dirty = true;
			if (ImGui.checkbox("Show cooldown text", showCdText))
				dirty = true;
			if (ImGui.checkbox("Show cooldown pinwheel", showPinwheel))
				dirty = true;
			if (ImGui.checkbox("Show key overlays", showHotkeys))
				dirty = true;
			if (ImGui.checkbox("Show remaining charges", showCharges))
				dirty = true;
			if (showHotkeys.get())
				ImGui.textWrapped("Type a Key next to each slot (e.g. 1, Q, F) - drawn as a high-contrast chip on the icon.");
			ImGui.separatorText("Cooldown cells");
			var mode = effectiveCdDisplay();
			var modeLabel = switch (mode) {
				case CD_HIDE: "Hide while on cooldown";
				case CD_SHOW_FULL: "Always show (no dim)";
				default: "Show + dim on cooldown";
			};
			if (ImGui.beginCombo("On cooldown##geaux_cd", modeLabel)) {
				if (ImGui.selectable("Show + dim on cooldown", mode == CD_SHOW_DIM)) {
					cdDisplay.set(CD_SHOW_DIM);
					dimOnCd.set(true);
					dirty = true;
				}
				if (ImGui.selectable("Hide while on cooldown", mode == CD_HIDE)) {
					cdDisplay.set(CD_HIDE);
					dimOnCd.set(false);
					dirty = true;
				}
				if (ImGui.selectable("Always show (no dim)", mode == CD_SHOW_FULL)) {
					cdDisplay.set(CD_SHOW_FULL);
					dimOnCd.set(false);
					dirty = true;
				}
				ImGui.endCombo();
			}
			if (ImGui.checkbox("Dim when lacking resources", dimOnNoResource))
				dirty = true;
		}
		if (ImGui.collapsingHeader("Colors")) {
			var flags = ImGuiColorEditFlags.AlphaBar | ImGuiColorEditFlags.NoInputs;
			if (ImGui.colorEdit4("Window bg##geaux", windowBg, flags))
				dirty = true;
			if (ImGui.colorEdit4("Empty slot##geaux", emptyFill, flags))
				dirty = true;
			if (ImGui.colorEdit4("Grid squares##geaux", readyDefault, flags)) {
				copyV4(readyWep, readyDefault);
				copyV4(readyCls, readyDefault);
				copyV4(readySig, readyDefault);
				dirty = true;
			}
			if (ImGui.colorEdit4("Border ready##geaux", borderReady, flags))
				dirty = true;
			if (ImGui.colorEdit4("Border idle##geaux", borderIdle, flags))
				dirty = true;
			if (ImGui.colorEdit4("CD text##geaux", cdText, flags))
				dirty = true;
			if (ImGui.button("Reset colors##geaux")) {
				resetColors();
				dirty = true;
			}
		}
		return dirty;
	}

	public function resetColors():Void {
		setV4(emptyFill, 0.12, 0.13, 0.15, 1);
		setV4(readyDefault, 0.35, 0.40, 0.48, 1);
		copyV4(readyWep, readyDefault);
		copyV4(readyCls, readyDefault);
		copyV4(readySig, readyDefault);
		setV4(borderReady, 1, 1, 1, 0.45);
		setV4(readyGlowColor, 1, 0.752941, 0.25098, 1);
		setV4(borderIdle, 0.28, 0.30, 0.34, 1);
		setV4(cdText, 1, 0.92, 0.55, 1);
		setV4(windowBg, 0.08, 0.09, 0.11, 1);
	}

	/** Keep weapon/class/signature fills synced to the shared grid-square color. */
	public function syncReadyFillsFromDefault():Void {
		copyV4(readyWep, readyDefault);
		copyV4(readyCls, readyDefault);
		copyV4(readySig, readyDefault);
	}

	public function readEmpty():ImVec4 {
		return readV4(emptyFill);
	}

	/** Lit = fully available; dim for CD (when mode says so) or missing resources. */
	public function readyFill(group:String, lit:Bool, id:String):ImVec4 {
		// One builder color is authoritative for every populated grid square.
		var base = readyDefault;
		if (!lit && (shouldDimOnCooldown() || dimOnNoResource.get()))
			return dimOf(base);
		if (!lit)
			return readV4(emptyFill);
		return readV4(base);
	}

	public function borderCol(lit:Bool):ImVec4 {
		return lit ? readV4(borderReady) : readV4(borderIdle);
	}

	public function cdTextCol():ImVec4 {
		return readV4(cdText);
	}

	public function windowBgCol(alphaOverride:Single = -1):ImVec4 {
		var c = readV4(windowBg);
		var a:Single = alphaOverride >= 0 ? alphaOverride : bgAlpha.get();
		return ImGui.vec4(c.x, c.y, c.z, a);
	}

	static function prayerFill(id:String, ready:Bool):ImVec4 {
		var k = PrayerCache.prayerKind(id);
		if (!ready) {
			if (k == "life")
				return ImGui.vec4(0.16, 0.22, 0.16, 1);
			if (k == "shield")
				return ImGui.vec4(0.14, 0.16, 0.22, 1);
			if (k == "smite")
				return ImGui.vec4(0.22, 0.20, 0.12, 1);
			return ImGui.vec4(0.16, 0.16, 0.12, 1);
		}
		if (k == "life")
			return ImGui.vec4(0.28, 0.82, 0.42, 1);
		if (k == "shield")
			return ImGui.vec4(0.30, 0.58, 0.95, 1);
		if (k == "smite")
			return ImGui.vec4(0.95, 0.78, 0.22, 1);
		return ImGui.vec4(0.72, 0.62, 0.28, 1);
	}

	public function glowColor(opacity:Float):Int {
		var c = readV4(readyGlowColor);
		return ImGui.colorConvertFloat4ToU32(ImGui.vec4(c.x, c.y, c.z, c.w * opacity));
	}
	public function setGlowRgb(rgb:Int):Void {
		setV4(readyGlowColor, ((rgb >> 16) & 255) / 255, ((rgb >> 8) & 255) / 255, (rgb & 255) / 255, 1);
	}

	public function dump():Dynamic {
		return {
			gap: gap.get(),
			padding: padding.get(),
			rounding: rounding.get(),
			border: border.get(),
			bgAlpha: bgAlpha.get(),
			glyphScale: glyphScale.get(),
			readyAttention: readyAttention.get(),
			readyGlowColor: dumpV4(readyGlowColor),
			cooldownAttention: cooldownAttention.get(),
			showLabels: showLabels.get(),
			showGroupTags: showGroupTags.get(),
			showCdText: showCdText.get(),
			showPinwheel: showPinwheel.get(),
			showHotkeys: showHotkeys.get(),
			showCharges: showCharges.get(),
			dimOnCd: dimOnCd.get(),
			cdDisplay: cdDisplay.get(),
			dimOnNoResource: dimOnNoResource.get(),
			emptyFill: dumpV4(emptyFill),
			readyWep: dumpV4(readyWep),
			readyCls: dumpV4(readyCls),
			readySig: dumpV4(readySig),
			readyDefault: dumpV4(readyDefault),
			borderReady: dumpV4(borderReady),
			borderIdle: dumpV4(borderIdle),
			cdText: dumpV4(cdText),
			windowBg: dumpV4(windowBg)
		};
	}

	public function apply(data:Dynamic):Void {
		if (data == null)
			return;
		setFloat(gap, data.gap);
		setFloat(padding, data.padding);
		setFloat(rounding, data.rounding);
		setFloat(border, data.border);
		setFloat(bgAlpha, data.bgAlpha);
		setFloat(glyphScale, data.glyphScale);
		setInt(readyAttention, data.readyAttention);
		setV4(readyGlowColor, 1, 0.752941, 0.25098, 1);
		loadV4(readyGlowColor, data.readyGlowColor);
		setInt(cooldownAttention, data.cooldownAttention);
		setBool(showLabels, data.showLabels);
		setBool(showGroupTags, data.showGroupTags);
		setBool(showCdText, data.showCdText);
		setBool(showPinwheel, data.showPinwheel);
		setBool(showHotkeys, data.showHotkeys);
		setBool(showCharges, data.showCharges);
		setBool(dimOnCd, data.dimOnCd);
		setBool(dimOnNoResource, data.dimOnNoResource);
		if (data.cdDisplay != null) {
			try {
				var m:Int = data.cdDisplay;
				cdDisplay.set(m);
			} catch (_:Dynamic) {}
		} else if (data.dimOnCd != null) {
			cdDisplay.set(dimOnCd.get() ? CD_SHOW_DIM : CD_SHOW_FULL);
		}
		loadV4(emptyFill, data.emptyFill);
		// Prefer new keys; fall back to old MH/OH/AR saves.
		if (data.readyWep != null)
			loadV4(readyWep, data.readyWep);
		else if (data.readyMh != null)
			loadV4(readyWep, data.readyMh);
		if (data.readyCls != null)
			loadV4(readyCls, data.readyCls);
		else if (data.readyDefault != null)
			loadV4(readyCls, data.readyDefault);
		loadV4(readySig, data.readySig);
		loadV4(readyDefault, data.readyDefault);
		loadV4(borderReady, data.borderReady);
		loadV4(borderIdle, data.borderIdle);
		loadV4(cdText, data.cdText);
		loadV4(windowBg, data.windowBg);
	}

	static function readV4(b:hl.Bytes):ImVec4 {
		if (b == null)
			return ImGui.vec4(1, 1, 1, 1);
		return ImGui.vec4(b.getF32(0), b.getF32(4), b.getF32(8), b.getF32(12));
	}

	static function copyV4(dest:hl.Bytes, src:hl.Bytes):Void {
		if (dest == null || src == null)
			return;
		setV4(dest, src.getF32(0), src.getF32(4), src.getF32(8), src.getF32(12));
	}

	static function dimOf(b:hl.Bytes):ImVec4 {
		var c = readV4(b);
		return ImGui.vec4(c.x * 0.35, c.y * 0.35, c.z * 0.35, 1);
	}

	static function setV4(b:hl.Bytes, x:Single, y:Single, z:Single, w:Single):Void {
		if (b == null)
			return;
		b.setF32(0, x);
		b.setF32(4, y);
		b.setF32(8, z);
		b.setF32(12, w);
	}

	static function dumpV4(b:hl.Bytes):Array<Float> {
		if (b == null)
			return [1, 1, 1, 1];
		return [b.getF32(0), b.getF32(4), b.getF32(8), b.getF32(12)];
	}

	static function loadV4(b:hl.Bytes, data:Dynamic):Void {
		if (b == null || data == null)
			return;
		try {
			var arr:Array<Dynamic> = data;
			if (arr == null || arr.length < 4)
				return;
			setV4(b, asF(arr[0], b.getF32(0)), asF(arr[1], b.getF32(4)), asF(arr[2], b.getF32(8)), asF(arr[3], b.getF32(12)));
		} catch (_:Dynamic) {}
	}

	static function setFloat(ref:FloatRef, v:Dynamic):Void {
		if (ref == null || v == null)
			return;
		try
			ref.set(asF(v, ref.get()))
		catch (_:Dynamic) {}
	}

	static function setBool(ref:BoolRef, v:Dynamic):Void {
		if (ref == null || v == null)
			return;
		try
			ref.set(v == true || v == 1 || v == "true")
		catch (_:Dynamic) {}
	}

	static function setInt(ref:IntRef, v:Dynamic):Void {
		if (ref == null || v == null)
			return;
		try
			ref.set(Std.int(v))
		catch (_:Dynamic) {}
	}

	static function asF(v:Dynamic, fallback:Float):Float {
		try {
			var f:Float = v;
			if (!Math.isNaN(f))
				return f;
		} catch (_:Dynamic) {}
		return fallback;
	}
}

/**
 * Small distinct slot symbols. Drawn with ImDrawList so they stay readable at ~24px.
 */
class GeauxGlyphs {
	public static var ids:Array<String> = [
		"", "sword", "spear", "axe", "bow", "staff", "shield", "boot", "star",
		"bolt", "heart", "drop", "skull", "flame", "eye", "moon", "key"
	];
	public static var labels:Array<String> = [
		"(none)", "Sword", "Spear", "Axe", "Bow", "Staff", "Shield", "Boot", "Star",
		"Bolt", "Heart", "Drop", "Skull", "Flame", "Eye", "Moon", "Key"
	];

	public static function labelOf(id:String):String {
		if (id == null || id.length == 0)
			return "(none)";
		for (i in 0...ids.length) {
			if (ids[i] == id)
				return labels[i];
		}
		return id;
	}

	public static function draw(dl:Dynamic, x:Single, y:Single, size:Single, id:String, lit:Bool):Void {
		if (id == null || id.length == 0)
			return;
		var pad:Single = size * 0.18;
		var ix = x + pad;
		var iy = y + pad;
		var s = size - pad * 2;
		var col = ImGui.colorConvertFloat4ToU32(lit ? ImGui.vec4(1, 1, 1, 0.95) : ImGui.vec4(0.55, 0.56, 0.58, 0.9));
		var t:Single = Math.max(2, s * 0.10);
		switch (id) {
			case "sword":
				drawSword(dl, ix, iy, s, col, t);
			case "spear":
				drawSpear(dl, ix, iy, s, col, t);
			case "axe":
				drawAxe(dl, ix, iy, s, col, t);
			case "bow":
				drawBow(dl, ix, iy, s, col, t);
			case "staff":
				drawStaff(dl, ix, iy, s, col, t);
			case "shield":
				drawShield(dl, ix, iy, s, col);
			case "boot":
				drawBoot(dl, ix, iy, s, col);
			case "star":
				drawStar(dl, ix, iy, s, col);
			case "bolt":
				drawBolt(dl, ix, iy, s, col);
			case "heart":
				drawHeart(dl, ix, iy, s, col);
			case "drop":
				drawDrop(dl, ix, iy, s, col);
			case "skull":
				drawSkull(dl, ix, iy, s, col);
			case "flame":
				drawFlame(dl, ix, iy, s, col);
			case "eye":
				drawEye(dl, ix, iy, s, col, t);
			case "moon":
				drawMoon(dl, ix, iy, s, col);
			case "key":
				drawKey(dl, ix, iy, s, col, t);
			default:
		}
	}

	static function drawSword(dl:Dynamic, x:Single, y:Single, s:Single, col:Int, t:Single):Void {
		var cx = x + s * 0.5;
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(cx - t * 0.45, y + s * 0.08), ImGui.vec2(cx + t * 0.45, y + s * 0.72), col, 1);
		ImGui.ImDrawList_AddTriangleFilled(dl, ImGui.vec2(cx, y), ImGui.vec2(cx - t, y + s * 0.14), ImGui.vec2(cx + t, y + s * 0.14), col);
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x + s * 0.22, y + s * 0.68), ImGui.vec2(x + s * 0.78, y + s * 0.78), col, 1);
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(cx - t * 0.55, y + s * 0.78), ImGui.vec2(cx + t * 0.55, y + s), col, 1);
	}

	static function drawSpear(dl:Dynamic, x:Single, y:Single, s:Single, col:Int, t:Single):Void {
		var cx = x + s * 0.5;
		ImGui.ImDrawList_AddTriangleFilled(dl, ImGui.vec2(cx, y), ImGui.vec2(cx - s * 0.16, y + s * 0.28), ImGui.vec2(cx + s * 0.16, y + s * 0.28), col);
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(cx - t * 0.4, y + s * 0.24), ImGui.vec2(cx + t * 0.4, y + s), col, 1);
	}

	static function drawAxe(dl:Dynamic, x:Single, y:Single, s:Single, col:Int, t:Single):Void {
		var cx = x + s * 0.42;
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(cx - t * 0.4, y + s * 0.08), ImGui.vec2(cx + t * 0.4, y + s), col, 1);
		ImGui.ImDrawList_AddTriangleFilled(dl,
			ImGui.vec2(cx, y + s * 0.12),
			ImGui.vec2(x + s, y + s * 0.08),
			ImGui.vec2(x + s * 0.92, y + s * 0.48), col);
		ImGui.ImDrawList_AddTriangleFilled(dl,
			ImGui.vec2(cx, y + s * 0.18),
			ImGui.vec2(x + s * 0.88, y + s * 0.42),
			ImGui.vec2(cx + t, y + s * 0.42), col);
	}

	static function drawBow(dl:Dynamic, x:Single, y:Single, s:Single, col:Int, t:Single):Void {
		ImGui.ImDrawList_AddLine(dl, ImGui.vec2(x + s * 0.22, y + s * 0.08), ImGui.vec2(x + s * 0.22, y + s * 0.92), col, t);
		// Prefer AddBezierCubic over PathStroke - PathStroke(thickness,flags) has bitten on ABI mismatches.
		ImGui.ImDrawList_AddBezierCubic(dl,
			ImGui.vec2(x + s * 0.22, y + s * 0.08),
			ImGui.vec2(x + s * 0.95, y + s * 0.18),
			ImGui.vec2(x + s * 0.95, y + s * 0.82),
			ImGui.vec2(x + s * 0.22, y + s * 0.92),
			col, t, 12);
		ImGui.ImDrawList_AddLine(dl, ImGui.vec2(x + s * 0.08, y + s * 0.5), ImGui.vec2(x + s * 0.88, y + s * 0.5), col, t * 0.7);
	}

	static function drawStaff(dl:Dynamic, x:Single, y:Single, s:Single, col:Int, t:Single):Void {
		var cx = x + s * 0.5;
		ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, y + s * 0.18), s * 0.16, col, 12);
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(cx - t * 0.4, y + s * 0.28), ImGui.vec2(cx + t * 0.4, y + s), col, 1);
	}

	static function drawShield(dl:Dynamic, x:Single, y:Single, s:Single, col:Int):Void {
		var cx = x + s * 0.5;
		ImGui.ImDrawList_AddTriangleFilled(dl, ImGui.vec2(cx, y + s), ImGui.vec2(x + s * 0.08, y + s * 0.42), ImGui.vec2(x + s * 0.92, y + s * 0.42), col);
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x + s * 0.08, y + s * 0.08), ImGui.vec2(x + s * 0.92, y + s * 0.46), col, 4);
	}

	static function drawBoot(dl:Dynamic, x:Single, y:Single, s:Single, col:Int):Void {
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x + s * 0.22, y + s * 0.08), ImGui.vec2(x + s * 0.58, y + s * 0.72), col, 3);
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x + s * 0.18, y + s * 0.62), ImGui.vec2(x + s * 0.92, y + s * 0.92), col, 4);
	}

	static function drawStar(dl:Dynamic, x:Single, y:Single, s:Single, col:Int):Void {
		var cx = x + s * 0.5;
		var cy = y + s * 0.52;
		var r1:Single = s * 0.46;
		var r2:Single = s * 0.18;
		var pts:Array<{x:Single, y:Single}> = [];
		var i = 0;
		while (i < 5) {
			var a = -Math.PI / 2 + i * Math.PI * 2 / 5;
			pts.push({x: cx + Math.cos(a) * r1, y: cy + Math.sin(a) * r1});
			var b = a + Math.PI / 5;
			pts.push({x: cx + Math.cos(b) * r2, y: cy + Math.sin(b) * r2});
			i++;
		}
		i = 0;
		while (i < pts.length) {
			var n = (i + 1) % pts.length;
			ImGui.ImDrawList_AddTriangleFilled(dl, ImGui.vec2(cx, cy), ImGui.vec2(pts[i].x, pts[i].y), ImGui.vec2(pts[n].x, pts[n].y), col);
			i++;
		}
	}

	static function drawBolt(dl:Dynamic, x:Single, y:Single, s:Single, col:Int):Void {
		ImGui.ImDrawList_AddTriangleFilled(dl, ImGui.vec2(x + s * 0.58, y), ImGui.vec2(x + s * 0.18, y + s * 0.52), ImGui.vec2(x + s * 0.48, y + s * 0.52), col);
		ImGui.ImDrawList_AddTriangleFilled(dl, ImGui.vec2(x + s * 0.42, y + s * 0.48), ImGui.vec2(x + s * 0.82, y + s * 0.48), ImGui.vec2(x + s * 0.38, y + s), col);
	}

	static function drawHeart(dl:Dynamic, x:Single, y:Single, s:Single, col:Int):Void {
		ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(x + s * 0.32, y + s * 0.34), s * 0.22, col, 12);
		ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(x + s * 0.68, y + s * 0.34), s * 0.22, col, 12);
		ImGui.ImDrawList_AddTriangleFilled(dl, ImGui.vec2(x + s * 0.08, y + s * 0.38), ImGui.vec2(x + s * 0.92, y + s * 0.38), ImGui.vec2(x + s * 0.5, y + s), col);
	}

	static function drawDrop(dl:Dynamic, x:Single, y:Single, s:Single, col:Int):Void {
		var cx = x + s * 0.5;
		ImGui.ImDrawList_AddTriangleFilled(dl, ImGui.vec2(cx, y + s * 0.04), ImGui.vec2(x + s * 0.14, y + s * 0.52), ImGui.vec2(x + s * 0.86, y + s * 0.52), col);
		ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, y + s * 0.62), s * 0.28, col, 14);
	}

	static function drawSkull(dl:Dynamic, x:Single, y:Single, s:Single, col:Int):Void {
		ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(x + s * 0.5, y + s * 0.38), s * 0.32, col, 14);
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x + s * 0.28, y + s * 0.52), ImGui.vec2(x + s * 0.72, y + s * 0.88), col, 3);
		var hole = ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.08, 0.09, 0.11, 1));
		ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(x + s * 0.36, y + s * 0.38), s * 0.10, hole, 10);
		ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(x + s * 0.64, y + s * 0.38), s * 0.10, hole, 10);
	}

	static function drawFlame(dl:Dynamic, x:Single, y:Single, s:Single, col:Int):Void {
		var cx = x + s * 0.5;
		ImGui.ImDrawList_AddTriangleFilled(dl, ImGui.vec2(cx, y), ImGui.vec2(x + s * 0.12, y + s * 0.62), ImGui.vec2(x + s * 0.88, y + s * 0.62), col);
		ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, y + s * 0.62), s * 0.30, col, 12);
		ImGui.ImDrawList_AddTriangleFilled(dl, ImGui.vec2(cx + s * 0.08, y + s * 0.18), ImGui.vec2(x + s * 0.78, y + s * 0.58), ImGui.vec2(cx + s * 0.22, y + s * 0.58), col);
	}

	static function drawEye(dl:Dynamic, x:Single, y:Single, s:Single, col:Int, t:Single):Void {
		var cx = x + s * 0.5;
		var cy = y + s * 0.5;
		ImGui.ImDrawList_AddTriangleFilled(dl, ImGui.vec2(x, cy), ImGui.vec2(cx, y + s * 0.18), ImGui.vec2(x + s, cy), col);
		ImGui.ImDrawList_AddTriangleFilled(dl, ImGui.vec2(x, cy), ImGui.vec2(cx, y + s * 0.82), ImGui.vec2(x + s, cy), col);
		var hole = ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.08, 0.09, 0.11, 1));
		ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, cy), s * 0.18, hole, 12);
		ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, cy), s * 0.08, col, 10);
	}

	static function drawMoon(dl:Dynamic, x:Single, y:Single, s:Single, col:Int):Void {
		var cx = x + s * 0.52;
		var cy = y + s * 0.5;
		ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, cy), s * 0.38, col, 16);
		var hole = ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.08, 0.09, 0.11, 1));
		ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx + s * 0.16, cy - s * 0.06), s * 0.30, hole, 16);
	}

	static function drawKey(dl:Dynamic, x:Single, y:Single, s:Single, col:Int, t:Single):Void {
		ImGui.ImDrawList_AddCircle(dl, ImGui.vec2(x + s * 0.32, y + s * 0.28), s * 0.22, col, 12, t);
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x + s * 0.28, y + s * 0.42), ImGui.vec2(x + s * 0.42, y + s * 0.92), col, 1);
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x + s * 0.28, y + s * 0.72), ImGui.vec2(x + s * 0.72, y + s * 0.82), col, 1);
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x + s * 0.28, y + s * 0.84), ImGui.vec2(x + s * 0.58, y + s * 0.94), col, 1);
	}
}
