package solarflare.aura;

import solarflare.ui.UndoStack;

/**
 * Routes undo/redo between whole-library snapshots and single-aura canvas snapshots that share one history.
 * The state stashed for the opposite direction always matches the kind of the entry being applied, so redo
 * of a canvas edit restores that aura's canvas and nothing else. Host-specific work is passed in as callbacks.
 */
class AuraUndoCoordinator {
	public var stack(default, null):UndoStack<String>;
	var captureLibrary:Void->String;
	/** Current dump of the aura an entry belongs to, or null when it no longer exists. */
	var captureCanvas:String->String;
	var applyLibrary:String->Void;
	/** Returns false when the aura is gone and nothing was restored. */
	var applyCanvas:String->Bool;

	public function new(stack:UndoStack<String>, captureLibrary:Void->String, captureCanvas:String->String,
			applyLibrary:String->Void, applyCanvas:String->Bool) {
		this.stack = stack;
		this.captureLibrary = captureLibrary;
		this.captureCanvas = captureCanvas;
		this.applyLibrary = applyLibrary;
		this.applyCanvas = applyCanvas;
	}

	function currentLike(entry:UndoItem<String>):String {
		if (entry != null && AuraCanvasSnapshot.isScoped(entry.data)) {
			var id = AuraCanvasSnapshot.auraId(entry.data);
			var live = id != null ? captureCanvas(id) : null;
			if (live != null) return live;
		}
		return try captureLibrary() catch (_:Dynamic) "";
	}

	function apply(state:String):Void {
		if (AuraCanvasSnapshot.isScoped(state)) applyCanvas(state); else applyLibrary(state);
	}

	public function undo():Bool {
		if (!stack.canUndo()) return false;
		var snap = stack.undo(currentLike(stack.peek()));
		if (snap == null) return false;
		apply(snap);
		return true;
	}

	public function redo():Bool {
		if (!stack.canRedo()) return false;
		var snap = stack.redo(currentLike(stack.peekRedo()));
		if (snap == null) return false;
		apply(snap);
		return true;
	}
}
