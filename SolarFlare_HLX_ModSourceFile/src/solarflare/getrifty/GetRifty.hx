package solarflare.getrifty;

import solarflare.ui.GameIcons;
import solarflare.ui.CursorCaptureFix;
import solarflare.ui.HudChrome;
import solarflare.ui.SettingsStore;
import solarflare.ui.UiLayout;
import solarflare.HealthCache;
import solarflare.FieldWalk;
import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiCond;
import imgui.Enums.ImGuiStyleVar;
import imgui.Enums.ImGuiWindowFlags;
import imgui.Theme;
import imgui.ref.BoolRef;
import imgui.ref.FloatRef;
import imgui.ref.IntRef;

/**
 * System-clock rift schedule. :45 portal active, :00 rift open. Alerts last 10s.
 */
class GetRiftyCache {
	public static inline var ALERT_NONE:Int = 0;
	public static inline var ALERT_PORTAL:Int = 1;
	public static inline var ALERT_RIFT:Int = 2;
	public static inline var ALERT_MS:Float = 10000;
	public static inline var CLOSE_MINUTES:Int = 3;

	public static var alertKind:Int = 0;
	public static var countdownText:String = "00:00";
	public static var phaseLabel:String = ":00 RIFT";
	public static var alertTitle:String = "";
	public static var alertBody:String = "";
	/** Layer 1: GameLayer.isRift / Activity.isRift — wall-clock still drives the countdown. */
	public static var inInstance:Bool = false;
	public static var instanceRemainText:String = "";
	/** Alert animation frame (observe). */
	public static var animFrame:Int = 0;

	static var hasTriggeredThisMinute:Bool = false;
	static var alertUntilMs:Float = 0;

	public static function tick():Void {
		var now = Date.now();
		var min = now.getMinutes();
		var sec = now.getSeconds();
		var ms = now.getTime();

		if (sec != 0)
			hasTriggeredThisMinute = false;
		else if (!hasTriggeredThisMinute && (min == 45 || min == 0)) {
			hasTriggeredThisMinute = true;
			startAlert(min == 45 ? ALERT_PORTAL : ALERT_RIFT, ms);
		}

		if (alertKind != ALERT_NONE && ms >= alertUntilMs)
			alertKind = ALERT_NONE;

		if (alertKind == ALERT_NONE)
			animFrame = 0;
		else {
			var elapsed = ms - (alertUntilMs - ALERT_MS);
			if (elapsed < 0)
				elapsed = 0;
			animFrame = Std.int(elapsed / 120);
		}

		updateCountdown(min, sec);
		if (inInstance) {
			phaseLabel = "IN RIFT";
			if (instanceRemainText.length > 0)
				countdownText = instanceRemainText;
		}
		updateAlertCopy();
	}

	/** Poll rift instance flag from GameApp.layer — identity/metrics only, no widgets. */
	public static function observeApp(app:Dynamic):Void {
		inInstance = false;
		instanceRemainText = "";
		if (app == null)
			return;
		try {
			var layer = FieldWalk.extractObject(app, "layer");
			if (layer == null)
				return;
			var riftFlag = FieldWalk.extractBool(layer, "isRift", false);
			var activity = FieldWalk.extractObject(layer, "mainActivity");
			if (!riftFlag && activity != null) {
				try {
					var a:st.Activity = cast activity;
					if (a != null && a.isRift())
						riftFlag = true;
				} catch (_:Dynamic) {}
			}
			var cfg = FieldWalk.extractObject(layer, "config");
			if (cfg == null) {
				var inst = FieldWalk.extractPath(app, ["connectionInfo", "instanceInfo"]);
				cfg = FieldWalk.extractObject(inst, "config");
			}
			var mapId = dynId(FieldWalk.extractObject(cfg, "mapId"));
			var actId = dynId(FieldWalk.extractObject(cfg, "activityID"));
			if (!riftFlag && (looksLikeRiftPlace(mapId) || looksLikeRiftPlace(actId)))
				riftFlag = true;
			inInstance = riftFlag;
			if (solarflare.debug.ResolutionLedger.armed()) {
				var method = "typed";
				var name = "isRift";
				if (looksLikeRiftPlace(mapId) || looksLikeRiftPlace(actId)) {
					method = "fieldwalk";
					name = "mapId";
				}
				solarflare.debug.ResolutionLedger.touch("getrifty.inInstance", method, "GetRiftyCache.observeApp", name, "bool", inInstance ? "true" : "false");
			}
			if (inInstance) {
				// Typed encounter identity for the Aura evidence ledger.  This stays
				// observation-only: no runtime discovery and no gameplay state changes.
				try {
					var rift:st.activity.Rift = cast activity;
					var bossId:String = rift == null ? null : rift.targetBossId;
					if (bossId != null && bossId.length > 0 && solarflare.debug.ResolutionLedger.armed())
						solarflare.debug.ResolutionLedger.touch("getrifty.targetBossId", "typed", "st.activity.Rift", "targetBossId", "String", bossId);
				} catch (_:Dynamic) {}
				var left = FieldWalk.extractNumberAny(activity, ["remaining", "timeLeft", "durationLeft"], -1);
				if (left > 0) {
					instanceRemainText = formatRemain(left);
					if (solarflare.debug.ResolutionLedger.armed())
						solarflare.debug.ResolutionLedger.touch("getrifty.remain", "fieldwalk", "GetRiftyCache.observeApp", "remaining", "number", Std.string(Math.round(left * 1000) / 1000));
				}
			}
		} catch (_:Dynamic) {}
	}

	static function dynId(v:Dynamic):String {
		if (v == null)
			return "";
		try {
			if (Std.isOfType(v, String))
				return (cast v : String).toLowerCase();
		} catch (_:Dynamic) {}
		return "";
	}

	static function looksLikeRiftPlace(id:String):Bool {
		if (id == null || id.length < 3)
			return false;
		return id.indexOf("rift") >= 0;
	}

	static function formatRemain(sec:Float):String {
		var s = Std.int(sec);
		if (s < 0)
			s = 0;
		var m = Std.int(s / 60);
		s = s % 60;
		return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
	}

	public static function forceAlert(kind:Int):Void {
		startAlert(kind, Date.now().getTime());
		updateAlertCopy();
	}

	static function startAlert(kind:Int, nowMs:Float):Void {
		if (kind != ALERT_PORTAL && kind != ALERT_RIFT)
			return;
		alertKind = kind;
		alertUntilMs = nowMs + ALERT_MS;
	}

	static function updateCountdown(min:Int, sec:Int):Void {
		var total = min * 60 + sec;
		var toClose = CLOSE_MINUTES * 60 - total;
		var toPortal = 45 * 60 - total;
		var toRift = 60 * 60 - total;
		if (toPortal <= 0)
			toPortal += 3600;
		if (toRift <= 0)
			toRift += 3600;

		var remain = toRift;
		phaseLabel = ":00 RIFT";
		if (min < CLOSE_MINUTES) {
			remain = toClose > 0 ? toClose : 0;
			phaseLabel = "CLOSE";
		} else if (toPortal <= toRift) {
			remain = toPortal;
			phaseLabel = ":45 PORTAL";
		}
		if (alertKind == ALERT_PORTAL) {
			phaseLabel = ":45 PORTAL";
			remain = toRift;
		} else if (alertKind == ALERT_RIFT) {
			phaseLabel = ":00 RIFT";
			remain = toClose > 0 ? toClose : 0;
		}
		var mm = Std.int(remain / 60);
		var ss = remain - mm * 60;
		countdownText = pad2(mm) + ":" + pad2(ss);
	}

	static function updateAlertCopy():Void {
		if (alertKind == ALERT_PORTAL) {
			alertTitle = ":45 PORTAL";
			alertBody = "Portal Waves Spawning!";
		} else if (alertKind == ALERT_RIFT) {
			alertTitle = ":00 RIFT";
			alertBody = "Defeat the Boss! (Closes in 3m)";
		} else {
			alertTitle = "";
			alertBody = "";
		}
	}

	static function pad2(n:Int):String {
		if (n < 10)
			return "0" + Std.string(n);
		return Std.string(n);
	}
}

/**
 * F6 → GetRifty. Hide + size + preview alerts.
 */
class GetRiftyConfig {
	public static inline var MIN_SIZE:Single = 96;
	public static inline var MAX_SIZE:Single = 360;

	public static inline var STYLE_SUN:Int = 0;
	public static inline var STYLE_PLAIN:Int = 1;
	public static inline var STYLE_BLANK:Int = 2;
	public static inline var STYLE_CLOCK_MODERN:Int = 3;
	public static inline var STYLE_CLOCK_DASH:Int = 4;
	public static inline var STYLE_CLOCK_MATRIX:Int = 5;
	public static inline var STYLE_CLOCK_CYBER:Int = 6;
	public static inline var STYLE_ASCII_EMPTY:Int = 7;
	public static inline var STYLE_ASCII_HAPPY:Int = 8;
	public static inline var STYLE_ASCII_RIFTSUN:Int = 9;
	public static inline var STYLE_ASCII_MOON:Int = 10;
	public static inline var STYLE_ASCII_BACKDROP:Int = 11;
	public static inline var STYLE_ASCII_ALPINE:Int = 12;
	public static inline var STYLE_ASCII_STAR:Int = 13;
	public static inline var STYLE_ASCII_DAY:Int = 14;
	public static inline var STYLE_ASCII_NIGHT:Int = 15;

	public var open:BoolRef;
	public var hidden:BoolRef;
	public var size = new FloatRef(168);
	public var clockStyle = new IntRef(STYLE_SUN);
	public var textU0 = new FloatRef(0.28);
	public var textV0 = new FloatRef(0.38);
	public var textU1 = new FloatRef(0.72);
	public var textV1 = new FloatRef(0.68);
	public var sizeDirty = true;
	public var chrome:HudChrome;

	public function new() {
		open = new BoolRef(false);
		hidden = new BoolRef(false);
		chrome = new HudChrome(40, 40);
	}

	public function draw():Void {
		if (!open.get())
			return;
		ImGui.setNextWindowSize(ImGui.vec2(360, 0), ImGuiCond.FirstUseEver);
		if (HudChrome.beginPanel("GetRifty##solarflare_cfg", open, "GetRifty")) {
			ImGui.textWrapped("Rift timer. Portal at :45, rift at :00. Off until you uncheck Hide.");
			ImGui.separatorText("Window");
			chrome.drawWindowSettings(hidden, "rifty");
			UiLayout.propertyGrid("##rifty_props", function() {
				UiLayout.propertyRow("Size", function() {
					if (ImGui.sliderFloat("##rifty_size", size, MIN_SIZE, MAX_SIZE, "%.0f px")) {
						sizeDirty = true;
						SettingsStore.markDirty();
					}
				});
				UiLayout.propertyRow("Clock style", function() {
					var style = clockStyle.get();
					var preview = styleName(style);
					if (ImGui.beginCombo("##rifty_style", preview)) {
						pickStyle("Sun", STYLE_SUN);
						pickStyle("Plain (white on black)", STYLE_PLAIN);
						pickStyle("BlankButton", STYLE_BLANK);
						pickStyle("Modern Box", STYLE_CLOCK_MODERN);
						pickStyle("Split Dashboard", STYLE_CLOCK_DASH);
						pickStyle("Terminal Matrix", STYLE_CLOCK_MATRIX);
						pickStyle("Retro Cyberpunk", STYLE_CLOCK_CYBER);
						pickStyle("Empty Sun", STYLE_ASCII_EMPTY);
						pickStyle("Happy Sun", STYLE_ASCII_HAPPY);
						pickStyle("Rift Sun art", STYLE_ASCII_RIFTSUN);
						pickStyle("Moon", STYLE_ASCII_MOON);
						pickStyle("Comet", STYLE_ASCII_BACKDROP);
						pickStyle("Alpine Star", STYLE_ASCII_ALPINE);
						pickStyle("Big Star", STYLE_ASCII_STAR);
						pickStyle("Daytime Rift", STYLE_ASCII_DAY);
						pickStyle("Nighttime Rift", STYLE_ASCII_NIGHT);
						ImGui.endCombo();
					}
				});
			});
			ImGui.separatorText("Preview");
			UiLayout.inlinePair(
				"##rifty_test",
				function(w:Single) {
					if (ImGui.button("Test portal (:45)##rifty_portal", ImGui.vec2(w, 0)))
						GetRiftyCache.forceAlert(GetRiftyCache.ALERT_PORTAL);
				},
				function(w:Single) {
					if (ImGui.button("Test rift (:00)##rifty_rift", ImGui.vec2(w, 0)))
						GetRiftyCache.forceAlert(GetRiftyCache.ALERT_RIFT);
				}
			);
			if (ImGui.collapsingHeader("ASCII / text hole")) {
				UiLayout.propertyGrid("##rifty_uv_props", function() {
					UiLayout.propertyRow("Left / Top", function() {
						UiLayout.inlinePair(
							"##rifty_uv0",
							function(_:Single) {
								if (ImGui.sliderFloat("L##rifty_u0", textU0, 0, 1, "%.2f"))
									SettingsStore.markDirty();
							},
							function(_:Single) {
								if (ImGui.sliderFloat("T##rifty_v0", textV0, 0, 1, "%.2f"))
									SettingsStore.markDirty();
							}
						);
					});
					UiLayout.propertyRow("Right / Bottom", function() {
						UiLayout.inlinePair(
							"##rifty_uv1",
							function(_:Single) {
								if (ImGui.sliderFloat("R##rifty_u1", textU1, 0, 1, "%.2f"))
									SettingsStore.markDirty();
							},
							function(_:Single) {
								if (ImGui.sliderFloat("B##rifty_v1", textV1, 0, 1, "%.2f"))
									SettingsStore.markDirty();
							}
						);
					});
				});
				if (ImGui.button("Reset text hole##rifty_uv")) {
					textU0.set(0.28);
					textV0.set(0.38);
					textU1.set(0.72);
					textV1.set(0.68);
					SettingsStore.markDirty();
				}
				ImGui.textDisabled("Timer draws in this region of the art.");
				drawCropPreview();
			}
		}
		HudChrome.endPanel();
	}

	function pickStyle(label:String, id:Int):Void {
		if (ImGui.selectable(label, clockStyle.get() == id)) {
			clockStyle.set(id);
			SettingsStore.markDirty();
		}
	}

	public static function styleName(style:Int):String {
		return switch (style) {
			case STYLE_PLAIN: "Plain";
			case STYLE_BLANK: "BlankButton";
			case STYLE_CLOCK_MODERN: "Modern Box";
			case STYLE_CLOCK_DASH: "Split Dashboard";
			case STYLE_CLOCK_MATRIX: "Terminal Matrix";
			case STYLE_CLOCK_CYBER: "Retro Cyberpunk";
			case STYLE_ASCII_EMPTY: "Empty Sun";
			case STYLE_ASCII_HAPPY: "Happy Sun";
			case STYLE_ASCII_RIFTSUN: "Rift Sun art";
			case STYLE_ASCII_MOON: "Moon";
			case STYLE_ASCII_BACKDROP: "Comet";
			case STYLE_ASCII_ALPINE: "Alpine Star";
			case STYLE_ASCII_STAR: "Big Star";
			case STYLE_ASCII_DAY: "Daytime Rift";
			case STYLE_ASCII_NIGHT: "Nighttime Rift";
			default: "Sun";
		};
	}

	public static function asciiStem(style:Int):String {
		return switch (style) {
			case STYLE_ASCII_EMPTY: "Empty_Sun";
			case STYLE_ASCII_HAPPY: "happysun";
			case STYLE_ASCII_RIFTSUN: "RiftSun";
			case STYLE_ASCII_MOON: "moon_real";
			case STYLE_ASCII_BACKDROP: "GetRiftyBackdrop1";
			case STYLE_ASCII_ALPINE: "AlpineStar";
			case STYLE_ASCII_STAR: "BigStars";
			case STYLE_ASCII_DAY: "daytime_rift";
			case STYLE_ASCII_NIGHT: "nighttime_rift";
			default: "";
		};
	}

	public static function isClockTemplate(style:Int):Bool {
		return style == STYLE_CLOCK_MODERN || style == STYLE_CLOCK_DASH
			|| style == STYLE_CLOCK_MATRIX || style == STYLE_CLOCK_CYBER;
	}

	public static function isAsciiStyle(style:Int):Bool {
		return asciiStem(style).length > 0;
	}

	function drawCropPreview():Void {
		var stem = asciiStem(clockStyle.get());
		if (stem.length == 0)
			stem = "Empty_Sun";
		var tex = AsciiArt.get(stem);
		if (tex == 0) {
			ImGui.text("Art not found: " + stem + ".txt");
			return;
		}
		var pw:Single = 220;
		var ph:Single = 220;
		var origin = ImGui.getCursorScreenPos();
		ImGui.dummy(ImGui.vec2(pw, ph));
		var dl = ImGui.getWindowDrawList();
		GameIcons.drawRect(dl, tex, origin.x, origin.y, pw, ph);
		var x0 = origin.x + pw * clamp01(textU0.get());
		var y0 = origin.y + ph * clamp01(textV0.get());
		var x1 = origin.x + pw * clamp01(textU1.get());
		var y1 = origin.y + ph * clamp01(textV1.get());
		if (x1 < x0) {
			var t = x0;
			x0 = x1;
			x1 = t;
		}
		if (y1 < y0) {
			var t = y0;
			y0 = y1;
			y1 = t;
		}
		ImGui.ImDrawList_AddRect(dl, ImGui.vec2(x0, y0), ImGui.vec2(x1, y1),
			ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 0.85, 0.2, 1)), 0, 2);
	}

	static function clamp01(v:Float):Float {
		if (v < 0)
			return 0;
		if (v > 1)
			return 1;
		return v;
	}
}

/**
 * Frameless sun overlay. Blits rift-sun.png; timer in the disk; 10s alert banner above.
 */
class GetRiftyOverlay {
	static inline var FLAGS:Int = ImGuiWindowFlags.NoTitleBar | ImGuiWindowFlags.NoCollapse
		| ImGuiWindowFlags.NoScrollbar | ImGuiWindowFlags.NoScrollWithMouse
		| ImGuiWindowFlags.NoBackground;
	static inline var RAYS:Int = 16;

	/** Prior frame's real window width — edge-drag delta feeds cfg.size. */
	var lastWinW:Single = 0;

	var theme:Theme;

	public function new() {
		theme = new Theme()
			.varV(ImGuiStyleVar.WindowPadding, ImGui.vec2(0, 0))
			.varF(ImGuiStyleVar.WindowRounding, 0)
			.varF(ImGuiStyleVar.WindowBorderSize, 0)
			.color(ImGuiCol.WindowBg, ImGui.vec4(0, 0, 0, 0))
			.color(ImGuiCol.Border, ImGui.vec4(0, 0, 0, 0));
	}

	public function draw(cfg:GetRiftyConfig):Void {
		if (cfg == null || cfg.hidden.get())
			return;
		theme.wrap(() -> drawWindow(cfg));
	}

	function drawWindow(cfg:GetRiftyConfig):Void {
		var size:Single = cfg.size.get();
		if (size < GetRiftyConfig.MIN_SIZE)
			size = GetRiftyConfig.MIN_SIZE;
		if (size > GetRiftyConfig.MAX_SIZE)
			size = GetRiftyConfig.MAX_SIZE;
		var bannerH:Single = GetRiftyCache.alertKind != GetRiftyCache.ALERT_NONE ? 52 : 0;
		var winW:Single = size;
		var winH:Single = size + bannerH;

		// The strip sits above the sun; grow the window so the art keeps its configured size.
		var stripH:Single = solarflare.ui.HudChrome.STRIP + 2;
		ImGui.setNextWindowBgAlpha(0);
		ImGui.setNextWindowSizeConstraints(ImGui.vec2(GetRiftyConfig.MIN_SIZE, GetRiftyConfig.MIN_SIZE),
			ImGui.vec2(GetRiftyConfig.MAX_SIZE, GetRiftyConfig.MAX_SIZE + 60 + stripH));
		if (cfg.sizeDirty) {
			ImGui.setNextWindowSize(ImGui.vec2(winW, winH + stripH), ImGuiCond.Always);
			cfg.sizeDirty = false;
			lastWinW = 0;
		} else {
			ImGui.setNextWindowSize(ImGui.vec2(winW, winH + stripH), ImGuiCond.FirstUseEver);
			ImGui.setNextWindowPos(ImGui.vec2(40, 40), ImGuiCond.FirstUseEver);
		}
		if (cfg.chrome != null) {
			cfg.chrome.clampToViewport();
			cfg.chrome.applyPos();
		}

		var flags = cfg.chrome != null ? cfg.chrome.windowFlags(FLAGS) : FLAGS;
		flags |= ImGuiWindowFlags.NoSavedSettings;
		var began = ImGui.begin("SolarFlare GetRifty", null, flags);
		if (began) {
			if (cfg.chrome == null || !cfg.chrome.isLocked()) {
				// Edge-drag delta drives the art size; the strip covers the top border.
				var win = ImGui.getWindowSize();
				if (lastWinW > 0 && Math.abs(win.x - lastWinW) > 1) {
					var next:Single = size + (win.x - lastWinW);
					if (next < GetRiftyConfig.MIN_SIZE)
						next = GetRiftyConfig.MIN_SIZE;
					if (next > GetRiftyConfig.MAX_SIZE)
						next = GetRiftyConfig.MAX_SIZE;
					cfg.size.set(next);
					SettingsStore.markDirty();
				}
				lastWinW = win.x;
				if (cfg.chrome != null)
					cfg.chrome.capturePos();
			}
			if (cfg.chrome == null || cfg.chrome.beginBody(function() {
				cfg.hidden.set(true);
				SettingsStore.markDirty();
			}, null, "GetRifty")) {
			var origin = ImGui.getCursorScreenPos();
			// Reserve body size with a real item first — GameIcons.draw uses SetCursorScreenPos.
			ImGui.dummy(ImGui.vec2(winW, winH));
			var settle = ImGui.getCursorScreenPos();
			var dl = ImGui.getWindowDrawList();
			var sunY:Single = origin.y + bannerH;
			if (GetRiftyCache.alertKind != GetRiftyCache.ALERT_NONE)
				drawBanner(dl, origin.x, origin.y, winW, bannerH);
			var style = cfg.clockStyle.get();
			var usedAnim = drawAlertAnim(dl, origin.x, sunY, size);
			if (!usedAnim) {
				if (style == GetRiftyConfig.STYLE_PLAIN)
					drawPlain(dl, origin.x, sunY, size);
				else if (style == GetRiftyConfig.STYLE_BLANK)
					drawBlank(dl, origin.x, sunY, size);
				else if (GetRiftyConfig.isClockTemplate(style))
					drawClockTemplate(dl, origin.x, sunY, size, style);
				else if (GetRiftyConfig.isAsciiStyle(style))
					drawAscii(dl, origin.x, sunY, size, GetRiftyConfig.asciiStem(style), 0);
				else
					drawSun(dl, origin.x, sunY, size, GetRiftyCache.alertKind);
			}
			var light = style != GetRiftyConfig.STYLE_SUN || usedAnim || GetRiftyConfig.isAsciiStyle(style)
				|| GetRiftyConfig.isClockTemplate(style);
			if (GetRiftyConfig.isClockTemplate(style) && !usedAnim)
				drawTemplateText(dl, origin.x, sunY, size, style);
			else
				drawHoleText(dl, origin.x, sunY, size, cfg, light);
			// Settle cursor with an item so EndChild does not see a bare SetCursorScreenPos extend.
			ImGui.setCursorScreenPos(settle);
			ImGui.dummy(ImGui.vec2(1, 1));
			}
		}
		solarflare.ui.HudChrome.endOverlayWindow(began, cfg.chrome);
	}

	function drawBanner(dl:Dynamic, x:Single, y:Single, w:Single, h:Single):Void {
		var rift = GetRiftyCache.alertKind == GetRiftyCache.ALERT_RIFT;
		var bg = rift ? ImGui.vec4(0.22, 0.08, 0.42, 0.92) : ImGui.vec4(0.55, 0.28, 0.06, 0.92);
		var edge = rift ? ImGui.vec4(0.72, 0.28, 0.92, 1) : ImGui.vec4(1.0, 0.62, 0.18, 1);
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x + 8, y + 6), ImGui.vec2(x + w - 8, y + h - 4),
			ImGui.colorConvertFloat4ToU32(bg), 8);
		ImGui.ImDrawList_AddRect(dl, ImGui.vec2(x + 8, y + 6), ImGui.vec2(x + w - 8, y + h - 4),
			ImGui.colorConvertFloat4ToU32(edge), 8, 2);
		var title = GetRiftyCache.alertTitle;
		var body = GetRiftyCache.alertBody;
		var titleCol = rift ? ImGui.vec4(0.95, 0.72, 1.0, 1) : ImGui.vec4(1.0, 0.92, 0.55, 1);
		var bodyCol = ImGui.vec4(1, 1, 1, 0.92);
		centerLine(dl, x, y + 10, w, title, titleCol);
		centerLine(dl, x, y + 28, w, body, bodyCol);
	}

	function drawPlain(dl:Dynamic, x:Single, y:Single, size:Single):Void {
		var pad:Single = 4;
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x + pad, y + pad), ImGui.vec2(x + size - pad, y + size - pad),
			ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.02, 0.02, 0.04, 0.92)), 8);
	}

	function drawBlank(dl:Dynamic, x:Single, y:Single, size:Single):Void {
		var tex = GameIcons.get("BlankButton");
		if (GameIcons.drawRect(dl, tex, x, y, size, size))
			return;
		drawPlain(dl, x, y, size);
	}

	function drawAlertAnim(dl:Dynamic, x:Single, y:Single, size:Single):Bool {
		if (GetRiftyCache.alertKind == GetRiftyCache.ALERT_NONE)
			return false;
		var tex:hl.I64 = 0;
		if (GetRiftyCache.alertKind == GetRiftyCache.ALERT_RIFT) {
			var pick = GetRiftyCache.animFrame % 3;
			if (pick == 0)
				tex = AsciiArt.get("TrippyStarForAnim");
			else if (pick == 1)
				tex = AsciiArt.get("AnimatedRandomParse");
			else
				tex = AsciiArt.get("rift");
			if (tex == 0)
				tex = AsciiArt.frameTex("rift_anim", GetRiftyCache.animFrame);
		} else
			tex = AsciiArt.frameTex("rift_anim", GetRiftyCache.animFrame);
		if (tex == 0)
			return false;
		var tint = GetRiftyCache.alertKind == GetRiftyCache.ALERT_RIFT ? 0xFFE8C8FF : 0xFFFFFFFF;
		if (!GameIcons.drawRect(dl, tex, x, y, size, size, tint))
			return false;
		return true;
	}

	function drawAscii(dl:Dynamic, x:Single, y:Single, size:Single, stem:String, frame:Int):Void {
		var tex = frame > 0 ? AsciiArt.frameTex(stem, frame) : AsciiArt.get(stem);
		if (GameIcons.drawRect(dl, tex, x, y, size, size))
			return;
		drawPlain(dl, x, y, size);
	}

	function drawClockTemplate(dl:Dynamic, x:Single, y:Single, size:Single, style:Int):Void {
		var pad:Single = 4;
		var x0 = x + pad;
		var y0 = y + pad;
		var x1 = x + size - pad;
		var y1 = y + size - pad;
		var bg = ImGui.vec4(0.04, 0.05, 0.07, 0.94);
		var edge = ImGui.vec4(0.55, 0.72, 0.85, 1);
		if (style == GetRiftyConfig.STYLE_CLOCK_CYBER)
			edge = ImGui.vec4(0.95, 0.35, 0.75, 1);
		else if (style == GetRiftyConfig.STYLE_CLOCK_MATRIX)
			edge = ImGui.vec4(0.25, 0.95, 0.45, 1);
		else if (style == GetRiftyConfig.STYLE_CLOCK_DASH)
			edge = ImGui.vec4(0.75, 0.82, 0.35, 1);
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x0, y0), ImGui.vec2(x1, y1),
			ImGui.colorConvertFloat4ToU32(bg), 4);
		ImGui.ImDrawList_AddRect(dl, ImGui.vec2(x0, y0), ImGui.vec2(x1, y1),
			ImGui.colorConvertFloat4ToU32(edge), 4, 2);
		if (style == GetRiftyConfig.STYLE_CLOCK_DASH || style == GetRiftyConfig.STYLE_CLOCK_CYBER) {
			var mid = y0 + (y1 - y0) * 0.22;
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(x0 + 8, mid), ImGui.vec2(x1 - 8, mid),
				ImGui.colorConvertFloat4ToU32(edge), 1);
		}
	}

	function drawTemplateText(dl:Dynamic, x:Single, y:Single, size:Single, style:Int):Void {
		var col = ImGui.vec4(0.85, 0.95, 1, 1);
		if (style == GetRiftyConfig.STYLE_CLOCK_MATRIX)
			col = ImGui.vec4(0.45, 1, 0.55, 1);
		else if (style == GetRiftyConfig.STYLE_CLOCK_CYBER)
			col = ImGui.vec4(1, 0.55, 0.85, 1);
		centerLine(dl, x, y + size * 0.08, size, "TIME  [ " + GetRiftyCache.countdownText + " ]", col);
		centerLine(dl, x, y + size * 0.42, size, GetRiftyCache.phaseLabel, col);
		centerLine(dl, x, y + size * 0.58, size, GetRiftyCache.countdownText, col);
		var status = GetRiftyCache.alertKind != GetRiftyCache.ALERT_NONE ? GetRiftyCache.alertBody : "LOCAL";
		if (GetRiftyCache.inInstance)
			status = "IN RIFT";
		centerLine(dl, x, y + size * 0.78, size, "STATUS: " + status, ImGui.vec4(1, 1, 1, 0.88));
	}

	function drawHoleText(dl:Dynamic, x:Single, y:Single, size:Single, cfg:GetRiftyConfig, light:Bool):Void {
		var u0 = cfg.textU0.get();
		var v0 = cfg.textV0.get();
		var u1 = cfg.textU1.get();
		var v1 = cfg.textV1.get();
		if (u1 < u0) {
			var t = u0;
			u0 = u1;
			u1 = t;
		}
		if (v1 < v0) {
			var t = v0;
			v0 = v1;
			v1 = t;
		}
		if (u1 - u0 < 0.12) {
			u0 = 0.28;
			u1 = 0.72;
		}
		if (v1 - v0 < 0.12) {
			v0 = 0.38;
			v1 = 0.68;
		}
		var hx = x + size * u0;
		var hy = y + size * v0;
		var hw = size * (u1 - u0);
		var hh = size * (v1 - v0);
		var labelCol = ImGui.vec4(0.18, 0.08, 0.02, 1);
		var timeCol = ImGui.vec4(0.12, 0.05, 0.02, 1);
		if (light) {
			labelCol = ImGui.vec4(1, 1, 1, 0.95);
			timeCol = ImGui.vec4(1, 1, 1, 0.92);
		} else if (GetRiftyCache.alertKind == GetRiftyCache.ALERT_RIFT) {
			labelCol = ImGui.vec4(0.28, 0.06, 0.42, 1);
			timeCol = ImGui.vec4(0.18, 0.04, 0.32, 1);
		}
		centerLineOutlined(dl, hx, hy + hh * 0.22, hw, GetRiftyCache.phaseLabel, labelCol);
		centerLineOutlined(dl, hx, hy + hh * 0.52, hw, GetRiftyCache.countdownText, timeCol);
	}

	function drawSun(dl:Dynamic, x:Single, y:Single, size:Single, kind:Int):Void {
		var tex = GameIcons.get(GameIcons.RIFT_TIMER_BG);
		if (tex == 0)
			tex = GameIcons.get(GameIcons.RIFT_SUN);
		if (GameIcons.draw(dl, tex, x, y, size, 0xFFFFFFFF))
			return;
		drawSunFallback(dl, x, y, size, kind);
	}

	function drawSunFallback(dl:Dynamic, x:Single, y:Single, size:Single, kind:Int):Void {
		var cx:Single = x + size * 0.5;
		var cy:Single = y + size * 0.5;
		var rift = kind == GetRiftyCache.ALERT_RIFT;
		var ray = rift ? ImGui.vec4(0.42, 0.12, 0.72, 1) : ImGui.vec4(1.0, 0.78, 0.12, 1);
		var rayHi = rift ? ImGui.vec4(0.78, 0.42, 1.0, 1) : ImGui.vec4(1.0, 0.92, 0.35, 1);
		var disk = rift ? ImGui.vec4(0.92, 0.82, 1.0, 1) : ImGui.vec4(1.0, 0.88, 0.18, 1);
		var outline = ImGui.vec4(0.02, 0.02, 0.04, 1);

		var outer:Single = size * 0.48;
		var inner:Single = size * 0.18;

		var i = 0;
		while (i < RAYS) {
			var longRay = i % 2 == 0;
			var a0 = i * Math.PI * 2 / RAYS - 0.12;
			var a1 = i * Math.PI * 2 / RAYS + 0.12;
			var tip = longRay ? outer : outer * 0.82;
			var midA = i * Math.PI * 2 / RAYS;
			var col = longRay ? rayHi : ray;
			var black = ImGui.colorConvertFloat4ToU32(outline);
			var fill = ImGui.colorConvertFloat4ToU32(col);
			var pTip = ImGui.vec2(cx + Math.cos(midA) * (tip + 2), cy + Math.sin(midA) * (tip + 2));
			var pL = ImGui.vec2(cx + Math.cos(a0) * inner, cy + Math.sin(a0) * inner);
			var pR = ImGui.vec2(cx + Math.cos(a1) * inner, cy + Math.sin(a1) * inner);
			ImGui.ImDrawList_AddTriangleFilled(dl, pL, pTip, pR, black);
			pTip = ImGui.vec2(cx + Math.cos(midA) * tip, cy + Math.sin(midA) * tip);
			ImGui.ImDrawList_AddTriangleFilled(dl, pL, pTip, pR, fill);
			i++;
		}

		ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, cy), inner + 3, ImGui.colorConvertFloat4ToU32(outline), 36);
		ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, cy), inner, ImGui.colorConvertFloat4ToU32(disk), 36);
	}

	function drawCenterText(dl:Dynamic, x:Single, y:Single, size:Single, light:Bool):Void {
		var labelCol = ImGui.vec4(0.18, 0.08, 0.02, 1);
		var timeCol = ImGui.vec4(0.12, 0.05, 0.02, 1);
		if (light) {
			labelCol = ImGui.vec4(1, 1, 1, 0.95);
			timeCol = ImGui.vec4(1, 1, 1, 0.92);
		} else if (GetRiftyCache.alertKind == GetRiftyCache.ALERT_RIFT) {
			labelCol = ImGui.vec4(0.28, 0.06, 0.42, 1);
			timeCol = ImGui.vec4(0.18, 0.04, 0.32, 1);
		}
		centerLineOutlined(dl, x, y + size * 0.38, size, GetRiftyCache.phaseLabel, labelCol);
		centerLineOutlined(dl, x, y + size * 0.52, size, GetRiftyCache.countdownText, timeCol);
	}

	static function centerLine(dl:Dynamic, x:Single, y:Single, w:Single, text:String, col:Dynamic):Void {
		if (text == null || text.length == 0)
			return;
		var ts = ImGui.calcTextSize(text);
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(x + (w - ts.x) * 0.5, y), ImGui.colorConvertFloat4ToU32(col), text);
	}

	static function centerLineOutlined(dl:Dynamic, x:Single, y:Single, w:Single, text:String, col:Dynamic):Void {
		if (text == null || text.length == 0)
			return;
		var ts = ImGui.calcTextSize(text);
		var px:Single = x + (w - ts.x) * 0.5;
		var shadow = ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 0.95, 0.7, 0.85));
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(px + 1, y + 1), shadow, text);
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(px, y), ImGui.colorConvertFloat4ToU32(col), text);
	}
}
