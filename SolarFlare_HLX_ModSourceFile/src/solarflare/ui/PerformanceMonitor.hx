package solarflare.ui;

import imgui.ImGui;
import imgui.ref.BoolRef;
import hl.Bytes;

/**
 * Performance & telemetry monitor showing real-time frame rates and draw statistics.
 */
class PerformanceMonitor {
	public static var open = new BoolRef(false);
	static var frameTimes:Array<Float> = [];
	static inline var MAX_SAMPLES:Int = 60;
	static var fps:Float = 60.0;
	static var lastTime:Float = 0.0;
	static var plotValues = new Bytes(MAX_SAMPLES * 4);

	public static function update():Void {
		var now = Date.now().getTime() / 1000.0;
		var dt = (lastTime > 0.0) ? (now - lastTime) : 0.016;
		lastTime = now;
		if (dt > 0.2) dt = 0.2;

		frameTimes.push(dt);
		if (frameTimes.length > MAX_SAMPLES)
			frameTimes.shift();

		var sum:Float = 0.0;
		for (t in frameTimes)
			sum += t;
		var avg = sum / frameTimes.length;
		fps = avg > 0.0001 ? (1.0 / avg) : 60.0;
	}

	public static function draw():Void {
		update();
		if (!open.get())
			return;

		if (HudChrome.beginPanel("Performance & Telemetry##sf_perf", open, "Performance Monitor")) {
			var ms:Float = fps > 0 ? (1000.0 / fps) : 0;
			ImGui.text('FPS: ${Std.int(fps)} (${Math.round(ms * 10) / 10} ms)');
			ImGui.separator();

			for (i in 0...frameTimes.length) {
				plotValues.setF32(i * 4, frameTimes[i] * 1000.0);
			}

			ImGui.plotLines("Frametime (ms)", plotValues, frameTimes.length, 0, null, 0.0, 33.3, ImGui.vec2(0, 65));

			ImGui.separatorText("ImGui Render Statistics");
			var io = ImGui.getIO();
			if (io != null) {
				ImGui.text('Framerate: ${Std.int(fps)} FPS');
			}
		}
		HudChrome.endPanel();
	}
}
