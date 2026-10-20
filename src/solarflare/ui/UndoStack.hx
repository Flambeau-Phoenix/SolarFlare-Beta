package solarflare.ui;

class UndoItem<T> {
	public var actionName:String;
	public var data:T;

	public function new(actionName:String, data:T) {
		this.actionName = actionName;
		this.data = data;
	}
}

/** Native-free undo/redo history. UndoManager adds toasts and ImGui buttons on top. */
class UndoStack<T> {
	var history:Array<UndoItem<T>> = [];
	var redoStack:Array<UndoItem<T>> = [];
	var maxHistory:Int;

	public function new(maxHistory:Int = 50) {
		this.maxHistory = maxHistory;
	}

	public function push(actionName:String, data:T):Void {
		history.push(new UndoItem(actionName, data));
		if (history.length > maxHistory)
			history.shift();
		redoStack = [];
	}

	/** Next entry undo would restore, or null. Lets callers capture the matching kind of "current" state. */
	public function peek():UndoItem<T> return history.length > 0 ? history[history.length - 1] : null;

	/** Next entry redo would restore, or null. */
	public function peekRedo():UndoItem<T> return redoStack.length > 0 ? redoStack[redoStack.length - 1] : null;

	public function canUndo():Bool return history.length > 0;

	public function canRedo():Bool return redoStack.length > 0;
 /** An editor's history belongs to the restored profile, never the next character. */
 public function clear():Void { history=[]; redoStack=[]; }

	/** Pops the latest entry, remembers `currentState` for redo and returns the entry, or null when empty. */
	public function takeUndo(currentState:T):UndoItem<T> {
		if (history.length == 0)
			return null;
		var item = history.pop();
		redoStack.push(new UndoItem(item.actionName, currentState));
		return item;
	}

	public function takeRedo(currentState:T):UndoItem<T> {
		if (redoStack.length == 0)
			return null;
		var item = redoStack.pop();
		history.push(new UndoItem(item.actionName, currentState));
		return item;
	}

	public function undo(currentState:T):Null<T> {
		var item = takeUndo(currentState);
		return item != null ? item.data : null;
	}

	public function redo(currentState:T):Null<T> {
		var item = takeRedo(currentState);
		return item != null ? item.data : null;
	}
}
