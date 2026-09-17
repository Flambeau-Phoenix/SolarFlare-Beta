package solarflare.geaux;

import solarflare.HealthCache;
import solarflare.ui.GameIcons;
import solarflare.ui.HudChrome;
import solarflare.ui.UiCol;
import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiCond;
import imgui.Enums.ImGuiStyleVar;
import imgui.Enums.ImGuiWindowFlags;
import imgui.Theme;

// GeauxStyle + GeauxGlyphs live in GeauxConfig.hx (same package module).
import solarflare.geaux.GeauxConfig;
import solarflare.geaux.GeauxCache.GeauxSlotSnap;

/**
 * Display-only grid over hero.skillSlots; interaction belongs to the builder.
 * Always draws empty cells when enabled — does not wait for skill data.
 */
class GeauxBar {
	static inline var FLAGS:Int = ImGuiWindowFlags.NoTitleBar | ImGuiWindowFlags.NoCollapse
		| ImGuiWindowFlags.NoScrollbar | ImGuiWindowFlags.NoScrollWithMouse;

	/** F6 hub diagnostics — why the grid is / isn't visible. */
	public static var lastStatus:String = "geaux idle";

	var theme:Theme;
	/** Absolute ImGui time when a builder cell flash expires. */
	var flashUntil = new Map<Int, Float>();
	public var previewFlashUntil:Float = 0;

	public function new() {
		theme = new Theme()
			.varF(ImGuiStyleVar.WindowRounding, 6)
			.varF(ImGuiStyleVar.FrameRounding, 3)
			.color(ImGuiCol.ResizeGrip, ImGui.vec4(0.35, 0.40, 0.48, 0.45));
	}

	/** Brief gold flash after assign / swap in the builder preview. */
	public function flashCell(idx:Int, duration:Float = 0.45):Void {
		if (idx < 0) return;
		flashUntil.set(idx, ImGui.getTime() + duration);
	}

	public function draw(cfg:GeauxConfig):Void {
		if (cfg == null) {
			lastStatus = "geaux: null config";
			return;
		}
		if (!cfg.enabled.get()) {
			lastStatus = "geaux: OFF (Show Geaux bar unchecked)";
			return;
		}
		try {
			cfg.ensureSlots();
			if (cfg.style == null)
				cfg.style = new GeauxStyle();
			theme.wrap(() -> drawWindow(cfg));
			lastStatus = "geaux: drawing "
				+ Std.string(cfg.rows.get()) + "x" + Std.string(cfg.cols.get())
				+ " bar=" + Std.string(GeauxCache.weapons.length)
				+ " @ " + Std.string(Std.int(cfg.chrome != null ? cfg.chrome.x.get() : 0))
				+ "," + Std.string(Std.int(cfg.chrome != null ? cfg.chrome.y.get() : 0));
		} catch (e:Dynamic) {
			lastStatus = "geaux: draw error " + Std.string(e);
		}
	}

	/** Embedded builder preview. enableDnD = cell/skill drag; onCellRightClick = assign menu. */
	public function drawPreview(cfg:GeauxConfig, onCellClick:Int->Void = null, selectedIdx:Int = -1,
			enableDnD:Bool = false, onSkillDrop:Int->String->Void = null, onCellSwap:Int->Int->Void = null,
			onCellRightClick:Int->Void = null, fit:Bool = true, zoom:Single = 1):Void {
		if (cfg == null)
			return;
		cfg.ensureSlots();
		if (cfg.style == null)
			cfg.style = new GeauxStyle();
		var rows = cfg.rows.get();
		var cols = cfg.cols.get();
		if (rows < 1) rows = 1;
		if (cols < 1) cols = 1;
		var gap:Single = cfg.style.gap.get();
		if (gap < 0) gap = 0;
		var avail = ImGui.getContentRegionAvail();
		var basePad:Single = Math.max(0, cfg.style.padding.get());
		var baseCell:Single = Math.max(1, Math.min((cfg.width.get() - basePad * 2 - gap * (cols - 1)) / cols,
			(cfg.height.get() - basePad * 2 - gap * (rows - 1)) / rows));
		var naturalW:Single = baseCell * cols + gap * (cols - 1) + basePad * 2;
		var naturalH:Single = baseCell * rows + gap * (rows - 1) + basePad * 2;
		var previewScale:Single = fit ? Math.max(0.01, Math.min(avail.x / (naturalW + 32), avail.y / (naturalH + 32))) : zoom;
		var pad:Single = basePad * previewScale + 16 * previewScale;
		gap *= previewScale;
		var previewW:Single = (naturalW + 32) * previewScale;
		var previewH:Single = (naturalH + 32) * previewScale;
		var cell:Single = baseCell * previewScale;
		var start = ImGui.getCursorScreenPos();
		ImGui.dummy(ImGui.vec2(Math.max(avail.x, previewW), Math.max(avail.y, previewH)));
		var frameOrigin = ImGui.vec2(start.x + Math.max(0, (avail.x - previewW) / 2), start.y + Math.max(0, (avail.y - previewH) / 2));

		ImGui.ImDrawList_AddRectFilled(ImGui.getWindowDrawList(), frameOrigin,
			ImGui.vec2(frameOrigin.x + previewW, frameOrigin.y + previewH),
			ImGui.colorConvertFloat4ToU32(cfg.style.windowBgCol(cfg.chrome.transparent.get() ? 0 : cfg.style.bgAlpha.get())), 4);
		var origin = ImGui.vec2(frameOrigin.x + pad, frameOrigin.y + pad);
		var rounding:Single = Math.max(0, cfg.style.rounding.get()) * previewScale;
		var borderW:Single = Math.max(0, cfg.style.border.get()) * previewScale;
		var count = rows * cols;
		var dragActive = ImGui.getDragDropPayload() != null;
		var now = ImGui.getTime();
		for (idx in 0...count) {
			var r = Std.int(idx / cols);
			var c = idx % cols;
			var id = idx < cfg.slotIds.length ? cfg.slotIds[idx] : "";
			var snap:Dynamic = (idx >= 0 && idx < GeauxCache.count && GeauxCache.slots[idx].present && GeauxCache.slots[idx].id == id)
				? GeauxCache.slots[idx]
				: (id.length > 0 ? GeauxCache.findSnap(id) : null);
			if (snap == null && id.length > 0) {
				var fallback = new GeauxSlotSnap();
				fallback.index = idx;
				fallback.id = id;
				fallback.iconId = id;
				fallback.label = GeauxCache.shortLabel(id);
				fallback.present = true;
				fallback.ready = true;
				fallback.group = GeauxCache.groupForId(id);
				snap = fallback;
			}
			var glyph = idx < cfg.slotGlyphs.length ? cfg.slotGlyphs[idx] : "";
			var hotkey = idx < cfg.slotHotkeys.length ? cfg.slotHotkeys[idx] : "";
			var cellX = origin.x + c * (cell + gap);
			var cellY = origin.y + r * (cell + gap);
			// Hit-test + DnD must run before GameIcons.image() steals LastItem.
			var hit = drawSnap(cfg.style, cellX, cellY, cell, rounding, borderW,
				snap, "##geaux_preview_cell_" + idx, true, glyph, hotkey, enableDnD ? function() {
					if (id.length > 0) {
						if (solarflare.ui.DragDropHelper.beginCellDrag(idx, id))
							solarflare.ui.DragDropHelper.endCellDrag();
					}
					var drop = solarflare.ui.DragDropHelper.acceptCellOrSkillDrop();
					if (drop.fromCell >= 0 && drop.fromCell != idx && onCellSwap != null)
						onCellSwap(drop.fromCell, idx);
					if (drop.skillId != null && drop.skillId.length > 0 && onSkillDrop != null)
						onSkillDrop(idx, drop.skillId);
				} : null);

			var dl = ImGui.getWindowDrawList();

			// Slot index chip (builder reference)
			var num = Std.string(idx + 1);
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(cellX + 3, cellY + 2), 0x66FFFFFF, num);

			// Empty-cell drop hint while a catalog/cell drag is active
			if (dragActive && id.length == 0) {
				ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(cellX, cellY),
					ImGui.vec2(cellX + cell, cellY + cell), 0x22FFCC44, rounding);
				if (cell >= 40) {
					var hint = "+";
					var hs = ImGui.calcTextSize(hint);
					ImGui.ImDrawList_AddText_Vec2(dl,
						ImGui.vec2(cellX + (cell - hs.x) * 0.5, cellY + (cell - hs.y) * 0.5),
						0x88FFE088, hint);
				}
			}

			// Hovered drop target glow
			if (dragActive && hit.hovered) {
				solarflare.ui.WindowEffects.glowBorder(dl, cellX, cellY, cellX + cell, cellY + cell, UiCol.rgb(0xFF8800), 0.65, 2.0, 6.0);
			}

			// Assign / swap flash
			if (flashUntil.exists(idx)) {
				var until = flashUntil.get(idx);
				if (now < until) {
					var t = (until - now) / 0.45;
					if (t < 0) t = 0;
					if (t > 1) t = 1;
					var a = Std.int(0x88 * t);
					solarflare.ui.WindowEffects.glowBorder(dl, cellX - 1, cellY - 1, cellX + cell + 1, cellY + cell + 1,
						0x00FFCC44 | (a << 24), 0.5 + 0.4 * t, 2.0, 8.0);
				} else {
					flashUntil.remove(idx);
				}
			}

			if (idx == selectedIdx) {
				ImGui.ImDrawList_AddRect(dl, ImGui.vec2(cellX - 2, cellY - 2),
					ImGui.vec2(cellX + cell + 2, cellY + cell + 2), UiCol.rgb(0x28B4FF), rounding, 2.5);
				solarflare.ui.VectorGlow.rect(dl, cellX - 1, cellY - 1, cell + 2, cell + 2, 0x6628B4FF, rounding, 1.5);
			}
			if (hit.clicked && onCellClick != null)
				onCellClick(idx);
			if (hit.rightClicked) {
				if (onCellClick != null)
					onCellClick(idx);
				if (onCellRightClick != null)
					onCellRightClick(idx);
			}
		}
		ImGui.setCursorScreenPos(frameOrigin);
		ImGui.dummy(ImGui.vec2(previewW, previewH));
	}

	public var openBuilder:Void->Void;
	function drawWindow(cfg:GeauxConfig):Void {
		var style = cfg.style;
		var gap:Single = Math.max(0, style.gap.get());
		var rounding:Single = Math.max(0, style.rounding.get());
		var borderW:Single = Math.max(0, style.border.get());
		solarflare.ui.HUDWidgetWindow.draw("SolarFlare Geaux", "Geaux", cfg.chrome, cfg.width.get(), cfg.height.get(), function(size) {
				var rows = cfg.rows.get();
				var cols = cfg.cols.get();
				if (rows < 1)
					rows = 1;
				if (cols < 1)
					cols = 1;
				var avail = size;
				var cellW:Single = (avail.x - gap * (cols - 1)) / cols;
				var cellH:Single = (avail.y - gap * (rows - 1)) / rows;
				if (cellW < 20)
					cellW = 20;
				if (cellH < 20)
					cellH = 20;
				var cell:Single = cellW < cellH ? cellW : cellH;

				var origin = ImGui.getCursorScreenPos();
				var idx = 0;
				for (r in 0...rows) {
					for (c in 0...cols) {
						var x:Single = origin.x + c * (cell + gap);
						var y:Single = origin.y + r * (cell + gap);
						var id = (cfg.slotIds != null && idx < cfg.slotIds.length) ? cfg.slotIds[idx] : "";
						var snap = (idx >= 0 && idx < GeauxCache.count && GeauxCache.slots[idx].present) ? GeauxCache.slots[idx] : null;
						if (snap == null && id.length > 0) {
							var fallback = new GeauxSlotSnap();
							fallback.index = idx;
							fallback.id = id;
							fallback.iconId = id;
							fallback.label = GeauxCache.shortLabel(id);
							fallback.present = true;
							fallback.ready = true;
							fallback.group = GeauxCache.groupForId(id);
							snap = fallback;
						}
						var glyph = (cfg.slotGlyphs != null && idx < cfg.slotGlyphs.length) ? cfg.slotGlyphs[idx] : "";
						var hotkey = (cfg.slotHotkeys != null && idx < cfg.slotHotkeys.length) ? cfg.slotHotkeys[idx] : "";
						drawSnap(style, x, y, cell, rounding, borderW, snap, "geaux_cell_" + idx, false, glyph, hotkey);
						idx++;
					}
				}
				ImGui.dummy(ImGui.vec2(avail.x > 1 ? avail.x : cell * cols, cell * rows + gap * (rows - 1)));
		}, openBuilder, function() { cfg.enabled.set(false); solarflare.ui.SettingsStore.markDirty(); }, false, null, function(newW:Single, newH:Single) {
			cfg.width.set(Math.max(24, newW));
			cfg.height.set(Math.max(24, newH));
			solarflare.ui.SettingsStore.markDirty();
		});
	}

	/**
	 * @param onHitStillActive Called while invisibleButton is still LastItem (before icon widgets).
	 * @return Click state captured before GameIcons.image() replaces LastItem.
	 */
	function drawSnap(style:GeauxStyle, x:Single, y:Single, size:Single, rounding:Single, borderW:Single, snap:Dynamic, id:String, pickable:Bool, glyph:String = "", hotkey:String = "",
			onHitStillActive:Void->Void = null):{clicked:Bool, rightClicked:Bool, hovered:Bool} {
		ImGui.setCursorScreenPos(ImGui.vec2(x, y));
		var clicked = false;
		var hovered = false;
		var rightClicked = false;
		if (pickable) {
			clicked = ImGui.invisibleButton(id, ImGui.vec2(size, size));
			hovered = ImGui.isItemHovered();
			rightClicked = ImGui.isItemClicked(1);
			// Builder DnD must bind to this button before ImGui.image decorations.
			if (onHitStillActive != null)
				onHitStillActive();
		} else {
			ImGui.dummy(ImGui.vec2(size, size));
		}

		var dl = ImGui.getWindowDrawList();
		var present = snap != null && snap.present;
		var ready = present && snap.ready;
		var affordable = !present || snap.affordable != false;
		var hasCharges = present && snap.chargesMax > 0 && snap.charges > 0;
		var onCd = present && (snap.cdLeft > 0.05 || snap.remaining > 0.02 || (!ready && !hasCharges));
		// Hide only when truly unavailable: empty charge pool or non-charged on CD.
		var hideForCd = onCd && !hasCharges;
		if (present && hideForCd && style.hideOnCooldown()) {
			return {clicked: clicked, rightClicked: rightClicked, hovered: hovered};
		}
		// Lit while usable ammo remains (pinwheel may still show regen).
		var lit = present && (ready || hasCharges) && (affordable || !style.dimOnNoResource.get());
		if (present && onCd && !hasCharges && !style.shouldDimOnCooldown() && style.effectiveCdDisplay() == GeauxStyle.CD_SHOW_FULL)
			lit = true;
		var showCdFx = !style.hideOnCooldown() || hasCharges;
		var group = snap != null && snap.group != null ? snap.group : "";
		var snapId = present && snap.id != null ? GeauxCache.sanitizeSkillId(snap.id) : "";
		if (present && snapId.length == 0)
			present = false;

		// Geaux only: ready prayers dim while Judgment is on CD. Vitals stay lit iff readiest.
		if (present && lit && (group == "PR" || solarflare.PrayerCache.isPrayerId(snapId))
			&& GeauxCache.judgmentOnCooldown())
			lit = false;
		var fill = !present ? style.readEmpty() : style.readyFill(group, lit, snapId);
		var border = style.borderCol(lit);

		// Near-ready CD pulse only (usable/proc SAO draws after icon).
		if (present && onCd && !hasCharges && snap.cdLeft <= 1.2 && snap.cdLeft > 0.05) {
			var pulseAlpha = 0.25 + 0.25 * Math.sin(ImGui.getTime() * 8.0);
			var pulseCol = 0x00FFFF | (Std.int(pulseAlpha * 255) << 24);
			solarflare.ui.VectorGlow.radial(dl, x + size * 0.5, y + size * 0.5, size * 0.5, pulseCol, 0.4, 4);
		}

		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x, y), ImGui.vec2(x + size, y + size), ImGui.colorConvertFloat4ToU32(fill), rounding);
		if (pickable && hovered) {
			solarflare.ui.VectorGlow.rect(dl, x, y, size, size, UiCol.rgb(0xFFAA22), rounding, 2.0);
		} else if (present && lit) {
			var bU32 = ImGui.colorConvertFloat4ToU32(border);
			solarflare.ui.VectorGlow.rect(dl, x, y, size, size, bU32, rounding, borderW > 0 ? borderW : 1.5);
		} else if (present && onCd && style.cooldownAttention.get() == GeauxStyle.CD_ATTN_OUTLINE) {
			solarflare.ui.VectorGlow.rect(dl, x - 1, y - 1, size + 2, size + 2, 0xAA5AA0FF, rounding, 2.0);
		} else if (borderW > 0) {
			ImGui.ImDrawList_AddRect(dl, ImGui.vec2(x, y), ImGui.vec2(x + size, y + size), ImGui.colorConvertFloat4ToU32(border), rounding, borderW);
		}

		var gScale:Single = style.glyphScale.get();
		if (gScale < 0.5)
			gScale = 0.5;
		if (gScale > 1.4)
			gScale = 1.4;
		var gSize:Single = size * gScale;
		var gx:Single = x + (size - gSize) * 0.5;
		var gy:Single = y + (size - gSize) * 0.5;
		var drewIcon = false;

		// Same blit path as SolarFlare prayer icons: GameIcons.registerTexture + ImGui.image.
		if (glyph != null && glyph.length > 0 && present) {
			GeauxGlyphs.draw(dl, gx, gy, gSize, glyph, lit);
			drewIcon = true;
		} else if (present && snapId.length > 0) {
			var pad:Single = (size - size * 0.76 * gScale) * 0.5;
			var iconSize:Single = size - pad * 2;
			if (iconSize < 8)
				iconSize = size;
			var iconHint = "";
			try {
				if (snap.iconId != null)
					iconHint = GeauxCache.sanitizeSkillId(snap.iconId);
			} catch (_:Dynamic) {}
			var tried:Array<String> = snap.iconCandidates;
			if (tried == null || tried.length == 0)
				tried = GeauxCache.iconIdCandidates(iconHint.length > 0 ? iconHint : snapId, null);
			if (iconHint.length > 0 && iconHint != snapId) {
				for (extra in GeauxCache.iconIdCandidates(snapId, null)) {
					var known = false;
					for (t in tried) {
						if (t == extra) {
							known = true;
							break;
						}
					}
					if (!known)
						tried.push(extra);
				}
			}
			for (cid in tried) {
				var tex = GameIcons.get(cid);
				if (GameIcons.draw(dl, tex, x + pad, y + pad, iconSize, GameIcons.tintReady(lit))) {
					drewIcon = true;
					break;
				}
			}
			if (!drewIcon && group == "PR") {
				var ptex = GameIcons.get(GameIcons.prayerId(solarflare.PrayerCache.prayerKind(snapId)));
				if (GameIcons.draw(dl, ptex, x + pad, y + pad, iconSize, GameIcons.tintReady(lit)))
					drewIcon = true;
			}
			if (!drewIcon && (group == "SIG" || GeauxCache.isSignatureId(snapId, null))) {
				var stex = GameIcons.get(solarflare.PrayerCache.JUDGMENT_SCRIPT);
				if (GameIcons.draw(dl, stex, x + pad, y + pad, iconSize, GameIcons.tintReady(lit)))
					drewIcon = true;
			}
		}
		if (!drewIcon) {
			if (present && group == "PR")
				drawPrayerGlyph(dl, x, y, size, snapId, lit);
			else if (present && style.showGroupTags.get() && group.length > 0 && group != "BAR" && group.indexOf("{") < 0) {
				var tagCol = lit ? ImGui.vec4(1, 1, 1, 0.7) : ImGui.vec4(0.6, 0.62, 0.66, 0.7);
				ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(x + 4, y + 3), ImGui.colorConvertFloat4ToU32(tagCol), group);
			} else if (!present) {
				var mark = "#";
				var ms = ImGui.calcTextSize(mark);
				ImGui.ImDrawList_AddText_Vec2(dl,
					ImGui.vec2(x + (size - ms.x) * 0.5, y + (size - ms.y) * 0.5),
					ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.45, 0.48, 0.52, 0.85)), mark);
			}
		}

		// Snapshot deadline uses the same monotonic clock as observation. Preview deadline is isolated.
		var deadline:Float = present ? snap.readyFlashUntil : 0;
		if (pickable && previewFlashUntil > 0) deadline = previewFlashUntil;
		var flashAlpha = ReadyFlashState.opacity(deadline, haxe.Timer.stamp());
		var glowDl = pickable ? dl : ImGui.getBackgroundDrawList();
		// SAO / usable attention after icon, before CD text & hotkeys.
		if (present) {
			var procReady = false;
			try
				procReady = snap.procReady == true
			catch (_:Dynamic) {}
			if (procReady) {
				solarflare.ui.VectorGlow.procOverlay(dl, x, y, size, size, ImGui.getTime());
			} else if (lit && affordable && flashAlpha > 0 && style.readyAttention.get() == GeauxStyle.ATTN_PROC) {
				// Same effect as the aura Glow tile: bright core, sparks travelling the border.
				// Drawn on dl (not glowDl) like the proc branch above - it stays within a few px
				// of the cell, so it needs no background list to reach past the chrome.
				solarflare.ui.VectorGlow.procTinted(dl, x, y, size, size, ImGui.getTime(), style.glowColor(1));
			} else if (lit && affordable && flashAlpha > 0 && style.readyAttention.get() == GeauxStyle.ATTN_PULSE) {
				// Wide exponential neon bloom — travels into gap/chrome, not FringeScale fat stroke.
				var bloomDist:Single = Math.min(24, size * 0.35);
				solarflare.ui.VectorGlow.skillAlertBloom(glowDl, x, y, size, size, style.glowColor(flashAlpha), bloomDist, rounding, 14, 2.2);
			} else if (lit && affordable && flashAlpha > 0 && style.readyAttention.get() == GeauxStyle.ATTN_BRIGHT) {
				// Tighter high-intensity outline bloom (fewer layers / shorter reach).
				solarflare.ui.VectorGlow.skillAlertBloom(glowDl, x, y, size, size, style.glowColor(flashAlpha), Math.min(16, size * 0.2), rounding, 10, 1.85);
			}
		}

		if (present && style.showPinwheel.get() && showCdFx && snap.remaining > 0.02
			&& (snap.cdLeft > 0.05 || snap.remaining < 0.98))
			drawPinwheel(dl, x, y, size, snap.remaining);

		if (present && style.showCdText.get() && showCdFx && onCd && snap.cdLeft > 0.05) {
			var secs = Std.int(Math.ceil(snap.cdLeft));
			var num = Std.string(secs);
			var ns = ImGui.calcTextSize(num);
			var ny:Single = drewIcon ? y + size * 0.72 : y + size * 0.58;
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(x + (size - ns.x) * 0.5, ny),
				ImGui.colorConvertFloat4ToU32(style.cdTextCol()), num);
		}

		if (present && style.showCharges.get() && snap.chargesMax > 0) {
			var ch = Std.string(snap.charges);
			var cs = ImGui.calcTextSize(ch);
			var cx:Single = x + size - cs.x - 3;
			var cy:Single = y + size - cs.y - 2;
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(cx + 1, cy + 1),
				ImGui.colorConvertFloat4ToU32(ImGui.vec4(0, 0, 0, 0.85)), ch);
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(cx, cy),
				ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.95, 0.98, 1.0, lit ? 1 : 0.75)), ch);
		}

		// User-defined keybind reminder (Key##hk fields) — not the skill name.
		if (style.showHotkeys.get() && hotkey != null) {
			var hk = GeauxConfig.sanitizeHotkey(hotkey);
			if (hk.length > 0)
				drawKeyOverlay(dl, x, y, size, hk, present && lit);
		}
		return {clicked: clicked, rightClicked: rightClicked, hovered: hovered};
	}

	/** High-contrast key chip: dark plate + cream text so it reads on busy skill art. */
	static function drawKeyOverlay(dl:Dynamic, x:Single, y:Single, size:Single, hk:String, lit:Bool):Void {
		var fontSize:Single = Math.max(ImGui.getFontSize() * 1.05, size * 0.28);
		if (fontSize > 22)
			fontSize = 22;
		if (fontSize < 12)
			fontSize = 12;
		ImGui.pushFont(ImGui.getFont(), fontSize);
		var ts = ImGui.calcTextSize(hk);
		var padX:Single = Math.max(4, size * 0.06);
		var padY:Single = Math.max(2, size * 0.04);
		var tx:Single = x + 3;
		var ty:Single = y + 2;
		var bx0:Single = tx - 1;
		var by0:Single = ty - 1;
		var bx1:Single = tx + ts.x + padX;
		var by1:Single = ty + ts.y + padY;
		var plateA:Single = lit ? 0.88 : 0.72;
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(bx0, by0), ImGui.vec2(bx1, by1),
			ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.02, 0.02, 0.03, plateA)), 4);
		// thickness=1 only — never pass flags as 1 (ImGui 1.92 InvalidMask assert).
		ImGui.ImDrawList_AddRect(dl, ImGui.vec2(bx0, by0), ImGui.vec2(bx1, by1),
			ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 1, 1, lit ? 0.35 : 0.22)), 4, 1);
		var textCol = lit ? ImGui.vec4(1, 0.96, 0.78, 1) : ImGui.vec4(0.78, 0.76, 0.70, 0.95);
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(tx + 1, ty + 1),
			ImGui.colorConvertFloat4ToU32(ImGui.vec4(0, 0, 0, 0.95)), hk);
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(tx, ty), ImGui.colorConvertFloat4ToU32(textCol), hk);
		ImGui.popFont();
	}

	static function drawPrayerGlyph(dl:Dynamic, x:Single, y:Single, size:Single, id:String, ready:Bool):Void {
		var k = solarflare.PrayerCache.prayerKind(id);
		var cx:Single = x + size * 0.5;
		var cy:Single = y + size * 0.38;
		var col = ImGui.colorConvertFloat4ToU32(ready ? ImGui.vec4(1, 1, 1, 0.95) : ImGui.vec4(0.45, 0.46, 0.48, 0.85));
		if (k == "life") {
			var t:Single = size * 0.08;
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(cx - t, cy - size * 0.16), ImGui.vec2(cx + t, cy + size * 0.16), col, 2);
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(cx - size * 0.16, cy - t), ImGui.vec2(cx + size * 0.16, cy + t), col, 2);
		} else if (k == "shield") {
			ImGui.ImDrawList_AddTriangleFilled(dl,
				ImGui.vec2(cx, cy - size * 0.16),
				ImGui.vec2(cx - size * 0.16, cy + size * 0.04),
				ImGui.vec2(cx + size * 0.16, cy + size * 0.04), col);
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(cx - size * 0.16, cy + size * 0.02), ImGui.vec2(cx + size * 0.16, cy + size * 0.14), col, 3);
		} else {
			ImGui.ImDrawList_AddTriangleFilled(dl,
				ImGui.vec2(cx, cy - size * 0.18),
				ImGui.vec2(cx - size * 0.08, cy + size * 0.02),
				ImGui.vec2(cx + size * 0.08, cy + size * 0.02), col);
			ImGui.ImDrawList_AddTriangleFilled(dl,
				ImGui.vec2(cx, cy + size * 0.16),
				ImGui.vec2(cx - size * 0.10, cy - size * 0.02),
				ImGui.vec2(cx + size * 0.10, cy - size * 0.02), col);
		}
	}

	function drawPinwheel(dl:Dynamic, x:Single, y:Single, size:Single, remaining:Float):Void {
		var cx:Single = x + size * 0.5;
		var cy:Single = y + size * 0.5;
		var r:Single = size * 0.48;
		var a0:Single = -Math.PI / 2;
		var a1:Single = a0 + remaining * Math.PI * 2;
		ImGui.ImDrawList_PathClear(dl);
		ImGui.ImDrawList_PathLineTo(dl, ImGui.vec2(cx, cy));
		ImGui.ImDrawList_PathArcTo(dl, ImGui.vec2(cx, cy), r, a0, a1, 28);
		ImGui.ImDrawList_PathFillConvex(dl, ImGui.colorConvertFloat4ToU32(ImGui.vec4(0, 0, 0, 0.62)));
	}

}
