package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiStyleVar;
import imgui.Enums.ImGuiTableColumnFlags;
import imgui.Enums.ImGuiTableFlags;

/** Shared responsive and high-density layout helpers. */
class UiLayout {
	/** Runtime content density, separate from editor property-grid spacing. */
	public static function contentSpacing(draw:Void->Void):Void {
		ImGui.pushStyleVar(ImGuiStyleVar.ItemSpacing, ImGui.vec2(3, 3));
		var failed = false;
		var failure:Dynamic = null;
		try { draw(); } catch (e:Dynamic) { failed = true; failure = e; }
		ImGui.popStyleVar();
		if (failed) throw failure;
	}
	static var rowMinimum:Single = 0;
	public static inline var DENSE_PAD_X:Single = 4;
	public static inline var DENSE_PAD_Y:Single = 2;
	public static inline var DENSE_GAP:Single = 4;
	public static inline var LABEL_WEIGHT:Single = 0.35;
	public static inline var CONTROL_WEIGHT:Single = 0.65;
	/** Default fixed label column width (px). Escape hatch via propertyGrid(..., labelWidth). */
	public static inline var LABEL_FIXED_PX:Single = 132;
	public static inline var WIDE_BREAKPOINT:Single = 900;

	public static inline function isWide():Bool {
		return ImGui.getContentRegionAvail().x >= WIDE_BREAKPOINT;
	}

	public static function columnCount(availableWidth:Single, minimumWidth:Single,
			maxColumns:Int, gap:Single = DENSE_GAP):Int {
		if (maxColumns < 1)
			return 1;
		var safeMinimum = Math.max(1, minimumWidth);
		var count = Std.int((availableWidth + gap) / (safeMinimum + gap));
		if (count < 1) count = 1;
		if (count > maxColumns) count = maxColumns;
		return count;
	}

	/**
	 * Dense label/control table. Seam D:
	 * - Label column: WidthFixed @ labelWidth (default 132), no NoResize
	 * - Control column: WidthStretch
	 * - propertyRow calls pushItemWidth(-1) so controls fill the cell
	 */
	public static function propertyGrid(id:String, drawProperties:Void->Void,
			extraFlags:Int = 0, labelWidth:Single = 132, minRowHeight:Single = 0):Void {
		var previousMinimum = rowMinimum;
		rowMinimum = minRowHeight;
		var pushed = 0;
		var failed = false;
		var failure:Dynamic = null;
		var lw:Single = labelWidth > 40 ? labelWidth : LABEL_FIXED_PX;
		try {
			ImGui.pushStyleVar(ImGuiStyleVar.CellPadding,
				ImGui.vec2(DENSE_PAD_X, DENSE_PAD_Y));
			pushed++;
			ImGui.pushStyleVar(ImGuiStyleVar.ItemSpacing,
				ImGui.vec2(DENSE_PAD_X, DENSE_PAD_Y));
			pushed++;

			var flags = ImGuiTableFlags.RowBg
				| ImGuiTableFlags.BordersOuter
				| ImGuiTableFlags.BordersInnerH
				| ImGuiTableFlags.SizingStretchProp
				| ImGuiTableFlags.NoSavedSettings
				| extraFlags;
			UiScope.table(id, 2, function() {
				ImGui.tableSetupColumn("Label", ImGuiTableColumnFlags.WidthFixed, lw);
				ImGui.tableSetupColumn("Control", ImGuiTableColumnFlags.WidthStretch, 1);
				if (drawProperties != null)
					drawProperties();
			}, flags);
		} catch (e:Dynamic) {
			failed = true;
			failure = e;
		}
		if (pushed > 0)
			ImGui.popStyleVar(pushed);
		rowMinimum = previousMinimum;
		if (failed)
			UiScope.report("property grid", id, failure);
	}

	/** One flush label/control row inside propertyGrid(). */
	public static function propertyRow(label:String, drawControl:Void->Void,
			help:String = null):Void {
		ImGui.tableNextRow(0, rowMinimum);
		ImGui.tableSetColumnIndex(0);
		ImGui.alignTextToFramePadding();
		ImGui.text(label);

		ImGui.tableSetColumnIndex(1);
		ImGui.pushItemWidth(-1);
		var failed = false;
		var failure:Dynamic = null;
		try {
			if (drawControl != null)
				drawControl();
		} catch (e:Dynamic) {
			failed = true;
			failure = e;
		}
		ImGui.popItemWidth();

		if (help != null && help.length > 0) {
			ImGui.tableNextRow();
			ImGui.tableSetColumnIndex(1);
			ImGui.pushTextWrapPos(0);
			ImGui.textDisabled(help);
			ImGui.popTextWrapPos();
		}
		if (failed)
			throw failure;
	}

	/**
	 * Equal horizontal cells with stable identity. The callback receives the
	 * usable cell width so buttons can opt into the complete allocation.
	 */
	public static function inlineSplit(id:String, count:Int,
			drawCell:Int->Single->Void, gap:Single = DENSE_GAP):Void {
		if (count <= 0 || drawCell == null)
			return;

		var available = Math.max(1, ImGui.getContentRegionAvail().x);
		var totalGap = gap * (count - 1);
		var cellWidth = Math.max(1, (available - totalGap) / count);
		var pushed = 0;
		var failed = false;
		var failure:Dynamic = null;
		try {
			ImGui.pushStyleVar(ImGuiStyleVar.CellPadding, ImGui.vec2(gap * 0.5, 0));
			pushed++;

			var flags = ImGuiTableFlags.SizingFixedFit
				| ImGuiTableFlags.NoSavedSettings
				| ImGuiTableFlags.NoPadOuterX;
			UiScope.table(id, count, function() {
				for (i in 0...count)
					ImGui.tableSetupColumn("##inline_" + i,
						ImGuiTableColumnFlags.WidthFixed, cellWidth);
				ImGui.tableNextRow();
				for (i in 0...count) {
					ImGui.tableSetColumnIndex(i);
					ImGui.pushItemWidth(-1);
					var cellFailed = false;
					var cellFailure:Dynamic = null;
					try {
						drawCell(i, cellWidth);
					} catch (e:Dynamic) {
						cellFailed = true;
						cellFailure = e;
					}
					ImGui.popItemWidth();
					if (cellFailed)
						throw cellFailure;
				}
			}, flags);
		} catch (e:Dynamic) {
			failed = true;
			failure = e;
		}
		if (pushed > 0)
			ImGui.popStyleVar(pushed);
		if (failed)
			UiScope.report("inline split", id, failure);
	}

	public static function inlinePair(id:String, drawLeft:Single->Void,
			drawRight:Single->Void, gap:Single = DENSE_GAP):Void {
		inlineSplit(id, 2, function(index:Int, width:Single) {
			if (index == 0 && drawLeft != null)
				drawLeft(width);
			else if (index == 1 && drawRight != null)
				drawRight(width);
		}, gap);
	}
}
