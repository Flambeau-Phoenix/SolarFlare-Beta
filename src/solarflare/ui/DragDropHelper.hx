package solarflare.ui;

import imgui.ImGui;
import imgui.ImGui.ImGuiPayload;
import haxe.io.Bytes;

/**
 * Payload extraction helpers for HashLink ImGuiPayload handles.
 */
class PayloadExt {
	/**
	 * Extract string from payload safely.
	 */
	public static function getString(payload:ImGuiPayload):String {
		if (payload == null)
			return null;
		
		var dataBytes = ImGui.getPayloadData(payload);
		var dataSize = ImGui.getPayloadDataSize(payload);
		
		if (dataBytes == null || dataSize <= 0)
			return null;

		return ByteUtil.readString(dataBytes, dataSize, true);
	}

	/**
	 * Extract int from payload safely.
	 */
	public static function getInt(payload:ImGuiPayload):Int {
		var str = getString(payload);
		return str != null ? Std.parseInt(str) : -1;
	}
}

/**
 * Drag & Drop helpers for aura management and item dragging in Solar Flare 2.
 */
class DragDropHelper {
	public static inline var PAYLOAD_AURA:String = "AURA_DATA";
	public static inline var PAYLOAD_ICON:String = "ICON_DATA";
	public static inline var PAYLOAD_TEXT:String = "TEXT";
	public static inline var PAYLOAD_AURA_SLOT:String = "AURA_SLOT";
	public static inline var PAYLOAD_SKILL:String = "SKILL_ID";
	public static inline var PAYLOAD_GEAUX_CELL:String = "GEAUX_CELL_IDX";

	public static function beginSkillDrag(skillId:String, displayName:String = null):Bool {
		if (!ImGui.beginDragDropSource(0))
			return false;
		var idBytes = haxe.io.Bytes.ofString(skillId);
		ImGui.setDragDropPayload(PAYLOAD_SKILL, idBytes.getData(), idBytes.length + 1);
		if (displayName != null) {
			ImGui.text('Dragging Skill: $displayName');
		} else {
			ImGui.text('Dragging Skill: $skillId');
		}
		return true;
	}

	public static function endSkillDrag():Void {
		ImGui.endDragDropSource();
	}

	public static function acceptSkillDrop():String {
		if (!ImGui.beginDragDropTarget())
			return null;
		var result:String = null;
		var payload = ImGui.acceptDragDropPayload(PAYLOAD_SKILL);
		if (payload != null && ImGui.ImGuiPayload_IsDataType(payload, PAYLOAD_SKILL)) {
			result = PayloadExt.getString(payload);
		}
		ImGui.endDragDropTarget();
		return result;
	}

	public static function beginCellDrag(cellIdx:Int, skillId:String):Bool {
		if (!ImGui.beginDragDropSource(0))
			return false;
		var idBytes = haxe.io.Bytes.ofString(Std.string(cellIdx));
		ImGui.setDragDropPayload(PAYLOAD_GEAUX_CELL, idBytes.getData(), idBytes.length + 1);
		ImGui.text('Move/Swap Cell #${cellIdx + 1}' + (skillId.length > 0 ? ' ($skillId)' : ''));
		return true;
	}

	public static function endCellDrag():Void {
		ImGui.endDragDropSource();
	}

	public static function acceptCellDrop():Int {
		var r = acceptCellOrSkillDrop();
		return r.fromCell;
	}

	/**
	 * One beginDragDropTarget per item — accept cell-swap and skill payloads together.
	 * Calling acceptCellDrop + acceptSkillDrop separately fails the second begin.
	 */
	public static function acceptCellOrSkillDrop():{fromCell:Int, skillId:String} {
		var fromCell = -1;
		var skillId:String = null;
		if (!ImGui.beginDragDropTarget())
			return {fromCell: fromCell, skillId: skillId};

		var cellPayload = ImGui.acceptDragDropPayload(PAYLOAD_GEAUX_CELL);
		if (cellPayload != null && ImGui.ImGuiPayload_IsDataType(cellPayload, PAYLOAD_GEAUX_CELL))
			fromCell = PayloadExt.getInt(cellPayload);

		var skillPayload = ImGui.acceptDragDropPayload(PAYLOAD_SKILL);
		if (skillPayload != null && ImGui.ImGuiPayload_IsDataType(skillPayload, PAYLOAD_SKILL))
			skillId = PayloadExt.getString(skillPayload);

		ImGui.endDragDropTarget();
		return {fromCell: fromCell, skillId: skillId};
	}

	/**
	 * Start dragging an aura by ID.
	 * @param auraId The aura's ID
	 * @param displayName Optional preview text during drag
	 * @return true if drag source is active
	 */
	public static function beginAuraDrag(auraId:Int, displayName:String = null):Bool {
		if (!ImGui.beginDragDropSource(0))
			return false;

		var idBytes = haxe.io.Bytes.ofString(Std.string(auraId));
		ImGui.setDragDropPayload(PAYLOAD_AURA, idBytes.getData(), idBytes.length + 1);

		if (displayName != null) {
			ImGui.text('Dragging: $displayName');
		} else {
			ImGui.text('Dragging Aura #$auraId');
		}

		return true;
	}

	public static function endAuraDrag():Void {
		ImGui.endDragDropSource();
	}

	/**
	 * Drop target that accepts aura payloads.
	 * @param slotIndex The slot index being targeted
	 * @return The dropped aura ID, or -1 if no drop occurred
	 */
	public static function acceptAuraDrop(slotIndex:Int):Int {
		if (!ImGui.beginDragDropTarget())
			return -1;

		var result = -1;
		var payload = ImGui.acceptDragDropPayload(PAYLOAD_AURA);
		if (payload != null && ImGui.ImGuiPayload_IsDataType(payload, PAYLOAD_AURA)) {
			var droppedId = PayloadExt.getInt(payload);
			if (droppedId >= 0) {
				result = droppedId;
			}
		}

		ImGui.endDragDropTarget();
		return result;
	}

}
