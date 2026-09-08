package solarflare.ui;

import imgui.ImGui;

/**
 * External work enqueued from tool draw (save / clipboard / JSON IO).
 * Drain from observe() — never perform disk/clipboard/JSON in draw().
 */
enum UiActionKind {
	SaveSettings;
	ResetDockLayout;
	CopyClipboard(text:String, successMsg:String);
	ImportGeauxClipboard;
	ExportGeauxClipboard;
	ImportAuraClipboard;
	ExportAuraSelection(json:String, successMsg:String);
	ExportAuraPack;
	Custom(run:Void->Void);
}

class UiAction {
	public var kind:UiActionKind;

	public function new(kind:UiActionKind) {
		this.kind = kind;
	}
}

class UiActionQueue {
	static var queue:Array<UiAction> = [];
	static var host:ConfigPanel = null;

	public static function bind(cfg:ConfigPanel):Void {
		host = cfg;
	}

	public static function enqueue(kind:UiActionKind):Void {
		queue.push(new UiAction(kind));
	}

	public static function save():Void {
		enqueue(SaveSettings);
	}

	public static function copyText(text:String, successMsg:String = "Copied to clipboard"):Void {
		if (text == null)
			return;
		enqueue(CopyClipboard(text, successMsg));
	}

	public static function custom(run:Void->Void):Void {
		if (run != null)
			enqueue(Custom(run));
	}

	/** Run pending actions outside the ImGui draw callback. */
	public static function drain():Void {
		if (queue.length == 0)
			return;
		var batch = queue;
		queue = [];
		for (action in batch) {
			try
				runOne(action)
			catch (e:Dynamic) {
				ToastManager.error("Action failed: " + Std.string(e));
			}
		}
	}

	static function runOne(action:UiAction):Void {
		if (action == null || action.kind == null)
			return;
		switch (action.kind) {
			case SaveSettings:
				SettingsStore.saveNow();
			case ResetDockLayout:
				SettingsStore.resetLayout();
			case CopyClipboard(text, successMsg):
				try {
					ImGui.setClipboardText(text);
					ToastManager.success(successMsg);
				} catch (e:Dynamic) {
					ToastManager.error("Clipboard copy failed");
				}
			case ImportGeauxClipboard:
				importGeauxFromClipboard();
			case ExportGeauxClipboard:
				exportGeauxToClipboard();
			case ImportAuraClipboard:
				importAuraFromClipboard();
			case ExportAuraSelection(json, successMsg):
				try {
					ImGui.setClipboardText(json);
					ToastManager.success(successMsg);
				} catch (_:Dynamic) {
					ToastManager.error("Clipboard copy failed");
				}
			case ExportAuraPack:
				exportAuraPackToClipboard();
			case Custom(run):
				if (run != null)
					run();
		}
	}

	static function importGeauxFromClipboard():Void {
		if (host == null || host.geaux == null || host.geauxBuilder == null) {
			ToastManager.error("Geaux builder unavailable");
			return;
		}
		try {
			var clipBytes = ImGui.getClipboardText();
			var clip = clipBytes != null ? ByteUtil.readString(clipBytes, 8192, true) : null;
			if (clip == null || clip.length < 5) {
				ToastManager.error("Clipboard does not contain valid JSON.");
				return;
			}
			var parsed:Dynamic = haxe.Json.parse(clip);
			host.geauxBuilder.applyExternalLayout(parsed, "Import Layout");
			ToastManager.success("Imported Geaux layout from clipboard!");
		} catch (e:Dynamic) {
			ToastManager.error("Failed to import JSON: " + e);
		}
	}

	static function exportGeauxToClipboard():Void {
		if (host == null || host.geaux == null) {
			ToastManager.error("Geaux unavailable");
			return;
		}
		try {
			var json = haxe.Json.stringify(host.geaux.dumpLayout(), null, "  ");
			ImGui.setClipboardText(json);
			ToastManager.success("Geaux layout copied to clipboard!");
		} catch (e:Dynamic) {
			ToastManager.error("Export failed: " + e);
		}
	}

	static function importAuraFromClipboard():Void {
		if (host == null || host.auraBuilder == null) {
			ToastManager.error("Aura builder unavailable");
			return;
		}
		host.auraBuilder.importFromClipboardQueued();
	}

	static function exportAuraPackToClipboard():Void {
		if (host == null || host.auraBuilder == null) {
			ToastManager.error("Aura builder unavailable");
			return;
		}
		host.auraBuilder.exportPackQueued();
	}
}
