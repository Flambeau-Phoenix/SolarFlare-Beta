package solarflare.ui;

/**
 * Accepts image files dropped from the OS onto the game window. The window callback only records paths;
 * the import itself runs from the action queue during observation. Files are accepted only while an image
 * panel is on screen (`arm()` each draw), so stray drops never write to the images folder.
 */
class ImageDrop {
	static inline var ARMED_S:Float = 1.0;
	static var armedAt:Float = -100;
	static var installed = false;
	static var failed = false;
	/** Called after a successful drop import with the new stems (last one wins). Set by the visible panel. */
	public static var onImported:Array<String>->Void = null;
	public static var support(default, null):String = "Drop files here to import them.";
	/** What the last drop event delivered, shown in the library so a silent failure is visible. */
	public static var lastDrop(default, null):String = "";

	/** Call from draw while an image panel is visible. */
	public static function arm():Void armedAt = haxe.Timer.stamp();

	public static function available():Bool return !failed;

	/** Observe phase: register the window target the first time a panel asks for it. */
	public static function observe():Void {
		if (installed || failed || armedAt < 0) return;
		try {
			var window = hxd.Window.getInstance();
			if (window == null) return;
			window.addDragAndDropTarget(onDrop);
			installed = true;
		} catch (e:Dynamic) {
			failed = true;
			support = "Drag and drop is not available in this game build. Use Paste or Import.";
		}
	}

	/** Window event callback: record only, never touch disk or UI state here. */
	static function onDrop(event:hxd.DropFileEvent):Void {
		var paths:Array<String> = [];
		lastDrop = "Drop event received.";
		try {
			var files = event.files;
			for (i in 0...files.length) {
				var f:hxd.DroppedFile = cast files.getDyn(i);
				var p = f.file;
				if (p != null && p.length > 0) paths.push(p);
			}
		} catch (e:Dynamic) { lastDrop = "Drop event could not be read: " + Std.string(e); }
		if (paths.length == 0) return;
		lastDrop = "Dropped " + paths.length + " file(s).";
		UiActionQueue.custom(function() process(paths));
	}

	static function process(paths:Array<String>):Void {
		if (haxe.Timer.stamp() - armedAt > ARMED_S) { lastDrop = "Drop ignored: open the Image library section first."; return; }
		var report = CustomImages.importMany(paths.join("\n"));
		if (report.imported.length > 0) {
			ToastManager.success("Imported " + report.imported.length + " image" + (report.imported.length == 1 ? "" : "s") + ".");
			if (onImported != null) onImported(report.imported);
		}
		for (e in report.errors) ToastManager.error(e);
	}
}
