package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiTableFlags;
import imgui.Enums.ImGuiTableColumnFlags;
import imgui.Enums.ImGuiSortDirection;

/**
 * Column definition for generic sortable tables.
 */
class SortableColumn<T> {
	public var label:String;
	public var getter:T->String;
	public var sortable:Bool;
	public var flags:Int;

	public function new(label:String, getter:T->String, sortable:Bool = true, flags:Int = 0) {
		this.label = label;
		this.getter = getter;
		this.sortable = sortable;
		this.flags = flags;
	}
}

/**
 * Generic sortable table wrapper for Solar Flare UI tables.
 */
class SortableTable<T> {
	public var data:Array<T>;
	public var columns:Array<SortableColumn<T>>;
	public var sortColumn:Int = -1;
	public var sortDirection:Int = ImGuiSortDirection.Ascending;
	public var flags:Int;
	public var tableId:String;

	public function new(tableId:String, data:Array<T>, columns:Array<SortableColumn<T>>, extraFlags:Int = 0) {
		this.tableId = tableId;
		this.data = data != null ? data : [];
		this.columns = columns != null ? columns : [];
		this.flags = ImGuiTableFlags.Borders |
			ImGuiTableFlags.RowBg |
			ImGuiTableFlags.Resizable |
			ImGuiTableFlags.Reorderable |
			ImGuiTableFlags.Hideable |
			ImGuiTableFlags.Sortable |
			extraFlags;
	}

	public function draw(renderRow:T->Void):Void {
		if (columns.length == 0)
			return;

		if (!ImGui.beginTable(tableId, columns.length, flags))
			return;

		var hasSortable = false;
		for (i in 0...columns.length) {
			var col = columns[i];
			var colFlags = col.flags;
			if (col.sortable) {
				colFlags |= ImGuiTableColumnFlags.DefaultSort;
				hasSortable = true;
			}
			ImGui.tableSetupColumn(col.label, colFlags);
		}
		ImGui.tableHeadersRow();

		if (hasSortable) {
			processSorting();
		}

		var sortedData = sortData();
		for (row in sortedData) {
			ImGui.tableNextRow(0, 0);
			renderRow(row);
		}

		ImGui.endTable();
	}

	function processSorting():Void {
		var specs = ImGui.tableGetSortSpecs();
		if (specs == null || !ImGui.tableSortSpecsGetSpecsDirty(specs))
			return;

		var count = ImGui.tableSortSpecsGetSpecsCount(specs);
		if (count > 0) {
			sortColumn = ImGui.tableSortSpecsGetColumnIndex(specs, 0);
			sortDirection = ImGui.tableSortSpecsGetSortDirection(specs, 0);
		} else {
			sortColumn = -1;
		}

		ImGui.tableSortSpecsSetSpecsDirty(specs, false);
	}

	function sortData():Array<T> {
		if (sortColumn < 0 || sortColumn >= columns.length)
			return data;
		if (!columns[sortColumn].sortable)
			return data;

		var sorted = data.copy();
		var getter = columns[sortColumn].getter;
		var dir = sortDirection;

		sorted.sort(function(a:T, b:T):Int {
			var va = getter(a);
			var vb = getter(b);
			if (va == null) va = "";
			if (vb == null) vb = "";
			var result = (va < vb) ? -1 : (va > vb ? 1 : 0);
			return (dir == ImGuiSortDirection.Ascending) ? result : -result;
		});

		return sorted;
	}

	public function refresh(newData:Array<T>):Void {
		data = newData != null ? newData : [];
	}
}
