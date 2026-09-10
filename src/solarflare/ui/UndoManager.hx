package solarflare.ui;

import imgui.ImGui;

class UndoItem<T> {
	public var actionName:String;
	public var data:T;

	public function new(actionName:String, data:T) {
		this.actionName = actionName;
		this.data = data;
	}
}

/**
 * Generic Undo/Redo stack for UI modifications.
 */
class UndoManager<T> {
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

	public function canUndo():Bool {
		return history.length > 0;
	}

	public function canRedo():Bool {
		return redoStack.length > 0;
	}

	public function undo(currentState:T):Null<T> {
		if (history.length == 0)
			return null;
		var item = history.pop();
		redoStack.push(new UndoItem(item.actionName, currentState));
		ToastManager.info('Undo: ${item.actionName}');
		return item.data;
	}

	public function redo(currentState:T):Null<T> {
		if (redoStack.length == 0)
			return null;
		var item = redoStack.pop();
		history.push(new UndoItem(item.actionName, currentState));
		ToastManager.info('Redo: ${item.actionName}');
		return item.data;
	}

	public function drawButtons(currentState:T, onRestore:T->Void):Void {
		ImGui.beginDisabled(!canUndo());
		if (ImGui.button("Undo")) {
			var state = undo(currentState);
			if (state != null && onRestore != null)
				onRestore(state);
		}
		ImGui.endDisabled();

		ImGui.sameLine();

		ImGui.beginDisabled(!canRedo());
		if (ImGui.button("Redo")) {
			var state = redo(currentState);
			if (state != null && onRestore != null)
				onRestore(state);
		}
		ImGui.endDisabled();
	}
}
