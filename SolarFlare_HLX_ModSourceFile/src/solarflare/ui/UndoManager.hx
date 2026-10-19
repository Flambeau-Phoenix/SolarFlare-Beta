package solarflare.ui;

import imgui.ImGui;

/**
 * Generic Undo/Redo stack for UI modifications.
 */
class UndoManager<T> extends UndoStack<T> {
	override public function undo(currentState:T):Null<T> {
		var item = takeUndo(currentState);
		if (item == null)
			return null;
		ToastManager.info('Undo: ${item.actionName}');
		return item.data;
	}

	override public function redo(currentState:T):Null<T> {
		var item = takeRedo(currentState);
		if (item == null)
			return null;
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
