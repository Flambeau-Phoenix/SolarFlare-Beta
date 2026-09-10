package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiWindowFlags;
import imgui.Enums.ImGuiCond;

class ToastItem {
	public var message:String;
	public var type:String;
	public var timer:Float;
	public var maxTimer:Float;

	public function new(message:String, type:String, duration:Float) {
		this.message = message;
		this.type = type;
		this.timer = duration;
		this.maxTimer = duration;
	}
}

/**
 * Non-intrusive floating toast notifications for Solar Flare 2.
 */
class ToastManager {
	static var toasts:Array<ToastItem> = [];
	static inline var MAX_TOASTS:Int = 5;

	static var lastTime:Float = 0.0;

	public static function show(message:String, type:String = "info", duration:Float = 1.8):Void {
		toasts.push(new ToastItem(message, type, duration));
		if (toasts.length > MAX_TOASTS)
			toasts.shift();
	}

	public static function success(message:String, duration:Float = 1.8):Void {
		show(message, "success", duration);
	}

	public static function error(message:String, duration:Float = 2.2):Void {
		show(message, "error", duration);
	}

	public static function info(message:String, duration:Float = 1.6):Void {
		show(message, "info", duration);
	}

	public static function warn(message:String, duration:Float = 1.8):Void {
		show(message, "warning", duration);
	}

	public static function draw():Void {
		if (toasts.length == 0)
			return;

		var now = Date.now().getTime() / 1000.0;
		var dt:Single = (lastTime > 0.0) ? (now - lastTime) : 0.016;
		lastTime = now;
		if (dt > 0.1) dt = 0.1;

		var yOffset:Single = 30.0;
		var screenW:Single = 1920.0;
		try {
			var win:Dynamic = hxd.Window.getInstance();
			if (win != null) {
				var w:Dynamic = Reflect.field(win, "width");
				if (w != null)
					screenW = w;
			}
		} catch (_:Dynamic) {}

		var remaining:Array<ToastItem> = [];
		for (i in 0...toasts.length) {
			var toast = toasts[i];
			toast.timer -= dt;
			if (toast.timer <= 0)
				continue;
			remaining.push(toast);

			var alpha:Single = toast.timer < 0.5 ? (toast.timer / 0.5) : 1.0;
			var bgCol = switch (toast.type) {
				case "success": ImGui.vec4(0.12, 0.45, 0.22, 0.90 * alpha);
				case "error": ImGui.vec4(0.55, 0.15, 0.15, 0.90 * alpha);
				case "warning": ImGui.vec4(0.60, 0.45, 0.12, 0.90 * alpha);
				default: ImGui.vec4(0.15, 0.18, 0.24, 0.90 * alpha);
			};

			var borderCol = switch (toast.type) {
				case "success": ImGui.vec4(0.30, 0.85, 0.45, 0.95 * alpha);
				case "error": ImGui.vec4(0.90, 0.30, 0.30, 0.95 * alpha);
				case "warning": ImGui.vec4(0.95, 0.75, 0.20, 0.95 * alpha);
				default: ImGui.vec4(0.40, 0.60, 0.95, 0.95 * alpha);
			};

			ImGui.setNextWindowPos(ImGui.vec2(screenW - 320, yOffset), ImGuiCond.Always);
			ImGui.setNextWindowSize(ImGui.vec2(300, 0), ImGuiCond.Always);

			var flags = ImGuiWindowFlags.NoTitleBar |
				ImGuiWindowFlags.NoResize |
				ImGuiWindowFlags.NoMove |
				ImGuiWindowFlags.NoDocking |
				ImGuiWindowFlags.NoSavedSettings |
				ImGuiWindowFlags.NoScrollbar |
				ImGuiWindowFlags.NoInputs;

			ImGui.pushStyleColor(ImGuiCol.WindowBg, bgCol);
			ImGui.pushStyleColor(ImGuiCol.Border, borderCol);

			if (ImGui.begin("##toast_" + i, null, flags)) {
				var icon = switch (toast.type) {
					case "success": "Success: ";
					case "error": "Error: ";
					case "warning": "Warning: ";
					default: "Info: ";
				};
				ImGui.text(icon + toast.message);
			}
			ImGui.end();
			ImGui.popStyleColor(2);

			yOffset += 44.0;
		}

		toasts = remaining;
	}
}
