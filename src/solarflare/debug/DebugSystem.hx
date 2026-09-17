package solarflare.debug;

import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiCond;
import imgui.Enums.ImGuiWindowFlags;
import imgui.Enums.ImGuiStyleVar;
import imgui.ref.BoolRef;
import solarflare.ui.PerformanceMonitor;

enum LogLevel {
	Error;
	Warning;
	Info;
	Debug;
}

class LogEntry {
	public var level:LogLevel;
	public var message:String;
	public var timestamp:String;

	public function new(level:LogLevel, message:String, timestamp:String) {
		this.level = level;
		this.message = message;
		this.timestamp = timestamp;
	}
}

class ProfileEntry {
	public var name:String;
	public var count:Int = 0;
	public var totalTime:Float = 0;
	public var lastTime:Float = 0;
	public var minTime:Float = 999999;
	public var maxTime:Float = 0;

	public function new(name:String) {
		this.name = name;
	}
}

/**
 * Universal runtime debug overlay, profiler, and diagnostic logger for Solar Flare.
 */
class DebugSystem {
	public static var open = new BoolRef(false);
	public static var showMetrics:Bool = true;
	public static var showLog:Bool = true;
	public static var showProfiler:Bool = false;

	static var logEntries:Array<LogEntry> = [];
	static inline var MAX_LOG_ENTRIES:Int = 300;

	static var profiles:Map<String, ProfileEntry> = new Map();
	static var activeProfiles:Map<String, Float> = new Map();

	public static function toggle():Void {
		open.set(!open.get());
		log(Info, "Debug overlay " + (open.get() ? "opened" : "closed"));
	}

	public static function log(level:LogLevel, message:String):Void {
		var date = Date.now();
		var timeStr = date.getHours() + ":" + date.getMinutes() + ":" + date.getSeconds();
		logEntries.push(new LogEntry(level, message, timeStr));
		if (logEntries.length > MAX_LOG_ENTRIES) {
			logEntries.shift();
		}
	}

	public static function startProfile(name:String):Void {
		activeProfiles.set(name, haxe.Timer.stamp());
	}

	public static function stopProfile(name:String):Void {
		var start = activeProfiles.get(name);
		if (start == null) return;
		activeProfiles.remove(name);
		var elapsed = haxe.Timer.stamp() - start;

		var entry = profiles.get(name);
		if (entry == null) {
			entry = new ProfileEntry(name);
			profiles.set(name, entry);
		}
		entry.count++;
		entry.totalTime += elapsed;
		entry.lastTime = elapsed;
		if (elapsed < entry.minTime) entry.minTime = elapsed;
		if (elapsed > entry.maxTime) entry.maxTime = elapsed;
	}

	public static function draw():Void {
		if (!open.get())
			return;

		// Gated like every other window: this was the last one building raw flags,
		// so it kept hit-testing during camera-look.
		var flags = solarflare.ui.CursorCaptureFix.windowFlags(ImGuiWindowFlags.NoCollapse | ImGuiWindowFlags.AlwaysAutoResize);
		ImGui.setNextWindowSizeConstraints(ImGui.vec2(320, 200), ImGui.vec2(700, 800));

		if (ImGui.begin("SolarFlare Diagnostics##sf_dbg", open, flags)) {
			// Toolbar
			if (ImGui.smallButton(showMetrics ? "[Metrics ON]" : "Metrics")) showMetrics = !showMetrics;
			ImGui.sameLine();
			if (ImGui.smallButton(showLog ? "[Log ON]" : "Log")) showLog = !showLog;
			ImGui.sameLine();
			if (ImGui.smallButton(showProfiler ? "[Profiler ON]" : "Profiler")) showProfiler = !showProfiler;
			ImGui.sameLine();
			if (ImGui.smallButton("Clear Log")) logEntries = [];

			ImGui.separator();

			// Metrics
			if (showMetrics) {
				var now = Date.now().getTime() / 1000.0;
				var fps = PerformanceMonitor.open != null ? 60 : 60;
				ImGui.text("Performance Status: Active");
				ImGui.separator();
			}

			// Profiler
			if (showProfiler) {
				ImGui.separatorText("Profiler Timings");
				for (k in profiles.keys()) {
					var p = profiles.get(k);
					var avg = p.count > 0 ? (p.totalTime / p.count * 1000.0) : 0;
					var last = p.lastTime * 1000.0;
					ImGui.text('$k: ${Math.round(last * 100) / 100}ms (avg: ${Math.round(avg * 100) / 100}ms, calls: ${p.count})');
				}
				ImGui.separator();
			}

			// Log viewer
			if (showLog) {
				ImGui.separatorText("Event Log");
				ImGui.beginChild("##sf_dbg_log_child", ImGui.vec2(0, 180), 0);
				for (entry in logEntries) {
					var col = switch (entry.level) {
						case Error: ImGui.vec4(1.0, 0.3, 0.3, 1.0);
						case Warning: ImGui.vec4(1.0, 0.85, 0.2, 1.0);
						case Debug: ImGui.vec4(0.5, 0.8, 1.0, 1.0);
						default: ImGui.vec4(0.9, 0.9, 0.9, 1.0);
					};
					ImGui.textColored(col, '[${entry.timestamp}] ${entry.message}');
				}
				ImGui.endChild();
			}
		}
		ImGui.end();
	}
}

class DebugLogger {
	public static inline function error(msg:String):Void DebugSystem.log(Error, msg);
	public static inline function warn(msg:String):Void DebugSystem.log(Warning, msg);
	public static inline function info(msg:String):Void DebugSystem.log(Info, msg);
	public static inline function debug(msg:String):Void DebugSystem.log(Debug, msg);
}
