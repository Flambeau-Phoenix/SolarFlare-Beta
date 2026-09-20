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
	/** Roughly ten seconds at 60 FPS: enough for stable p95/p99 inspection. */
	static inline var MAX_SAMPLES:Int = 600;
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

	static function percentile(sorted:Array<Float>, p:Float):Float {
		if (sorted == null || sorted.length == 0)
			return 0;
		var rank = Std.int(Math.ceil(p * sorted.length)) - 1;
		if (rank < 0) rank = 0;
		if (rank >= sorted.length) rank = sorted.length - 1;
		return sorted[rank] * 1000.0;
	}

	public static function frameStats():Dynamic {
		if (frameTimes.length == 0)
			return {samples: 0, averageMs: 0.0, medianMs: 0.0, p95Ms: 0.0, p99Ms: 0.0};
		var sorted = frameTimes.copy();
		sorted.sort(function(a:Float, b:Float):Int return a < b ? -1 : (a > b ? 1 : 0));
		var sum = 0.0;
		for (value in sorted)
			sum += value;
		return {
			samples: sorted.length,
			averageMs: sum * 1000.0 / sorted.length,
			medianMs: percentile(sorted, 0.50),
			p95Ms: percentile(sorted, 0.95),
			p99Ms: percentile(sorted, 0.99)
		};
	}

	public static function toJson():String {
		var runtime:Dynamic = {};
		try runtime = haxe.Json.parse(solarflare.runtime.RuntimeMetrics.toJson()) catch (_:Dynamic) {}
		return haxe.Json.stringify({frame: frameStats(), runtime: runtime});
	}

	public static function reset():Void {
		frameTimes.resize(0);
		fps = 60.0;
		lastTime = 0.0;
	}

	public static function draw():Void {
		update();
		if (!open.get())
			return;

		if (HudChrome.beginPanel("Performance & Telemetry##sf_perf", open, "Performance Monitor")) {
			var ms:Float = fps > 0 ? (1000.0 / fps) : 0;
			var stats:Dynamic = frameStats();
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

			ImGui.separatorText("SolarFlare Runtime");
			var m = solarflare.runtime.RuntimeMetrics;
			UiLayout.propertyGrid("##sf_runtime_metrics", function() {
				UiLayout.propertyRow("Frame latency", function() {
					ImGui.text('median ${roundMs(stats.medianMs)} ms  p95 ${roundMs(stats.p95Ms)} ms  p99 ${roundMs(stats.p99Ms)} ms');
				});
				UiLayout.propertyRow("Hook ingress", function() {
					ImGui.text('${m.hookEdges} edges  ${m.coalescedEdges} coalesced');
				});
				UiLayout.propertyRow("Scheduler", function() {
					ImGui.text('${m.fastPasses} fast  ${m.heavyPasses} active  ${m.backgroundPasses} bg');
				});
				UiLayout.propertyRow("Polls", function() {
					ImGui.text('id ${m.identityPolls}  vitals ${m.vitalsPolls}  status ${m.statusPolls}');
					ImGui.text('skills ${m.skillPolls}  target ${m.targetPolls}  rift ${m.encounterPolls}  recover ${m.layoutRecoveryPolls}');
				});
				UiLayout.propertyRow("Event ring", function() {
					ImGui.text('${solarflare.runtime.EventRing.depth()}/512  max ${m.maxQueueDepth}  dropped ${m.eventDropped}');
				});
			});
			UiLayout.inlinePair("##sf_runtime_metric_actions",
				function(w:Single) {
					if (ImGui.button("Copy JSON##sf_runtime_copy", ImGui.vec2(w, 26)))
						ImGui.setClipboardText(toJson());
				},
				function(w:Single) {
					if (ImGui.button("Reset counters##sf_runtime_reset", ImGui.vec2(w, 26))) {
						reset();
						m.reset();
					}
				}
			);
		}
		HudChrome.endPanel();
	}

	static inline function roundMs(value:Float):Float {
		return Math.round(value * 100.0) / 100.0;
	}
}
