package solarflare.aura.signal;

/** Native-free, retained geometry shared by rendering, navigation and spatial checks. */
class AuraConditionPickerLayout {
	public static inline var GAP:Float = 12;
	public static inline var PAD:Float = 8;
	public var rows(default, null):Array<PickerLayoutRow> = [];
	/** Indexed by the model's match index, never by a volatile widget ID. */
	public var cells(default, null):Array<PickerLayoutCell> = [];
	public var columns(default, null):Int = 1;
	public var width(default, null):Float = 0;
	public var minCellWidth(default, null):Float = 224;
	public var contentHeight(default, null):Float = 0;
	public var textLimited(default, null):Bool = false;
	public var revision(default, null):Int = -1;
	public var fontHeight(default, null):Float = 0;
	public var generation(default, null):Int = 0;
	var rowPool:Array<PickerLayoutRow> = [];
	var cellPool:Array<PickerLayoutCell> = [];
	var desiredColumn:Int = -1;
	var previousHighlight:Int = -1;
	var cachedModel:AuraConditionPickerModel;
	var cachedColumns:Int = -1;
	public function new() {}
	public static function minimumWidth(font:Float):Float return 224 * Math.max(1, font / 13);
	public static function columnBudget(available:Float, minimum:Float):Int {
		return Std.int(Math.max(1, Math.min(3, Math.floor((available + GAP) / (minimum + GAP)))));
	}
	public function invalidate():Void revision = -1;
	/** Measurement is injected by the UI; no ImGui or live engine dependency. */
	public function rebuild(model:AuraConditionPickerModel, available:Float, font:Float, requestedColumns:Int,
		measure:String->Float):Bool {
		available = Math.max(1, Math.floor(available));
		if (cachedModel == model && revision == model.revision && width == available && fontHeight == font && cachedColumns == requestedColumns) return false;
		cachedModel = model; cachedColumns = requestedColumns;
		revision = model.revision; width = available; fontHeight = font; minCellWidth = minimumWidth(font); generation++;
		columns = Std.int(Math.max(1, Math.min(requestedColumns, columnBudget(width, minCellWidth))));
		textLimited = false; desiredColumn = previousHighlight = -1;
		cells.resize(0);
		for (i in 0...model.matches.length) {
			if (i >= cellPool.length) cellPool.push(new PickerLayoutCell());
			var cell = cellPool[i]; var entry = model.entries[model.matches[i]];
			cell.id = entry.descriptor.id; cell.matchIndex = i; cells.push(cell);
		}
		// Try fewer columns if any real label needs more than two title lines.
		var maxLines = 1; var cellWidth:Float = 1;
		while (true) {
			cellWidth = Math.max(1, Math.floor((width - GAP * (columns - 1)) / columns)); maxLines = 1;
			for (cell in cells) {
				wrap(model.entries[model.matches[cell.matchIndex]].descriptor.label, Math.max(1, cellWidth - PAD * 2), measure, cell.lines);
				maxLines = Std.int(Math.max(maxLines, cell.lines.length));
			}
			if (maxLines <= 2 || columns == 1) break;
			columns--; textLimited = true;
		}
		var cellHeight = Math.ceil(PAD * 2 + Math.max(2, maxLines) * font + 4 + font);
		rows.resize(0); contentHeight = 0;
		var i = 0;
		while (i < cells.length) {
			var first = model.entries[model.matches[i]]; var group = first.descriptor.group; var end = i;
			var families = 0; var lastFamily:String = null;
			while (end < cells.length && model.entries[model.matches[end]].descriptor.group == group) {
				var family = model.entries[model.matches[end]].family;
				if (family != lastFamily) { families++; lastFamily = family; } end++;
			}
			addHeading("heading", group + " (" + (end - i) + ")", font, measure);
			lastFamily = null; var row:PickerLayoutRow = null;
			while (i < end) {
				var entry = model.entries[model.matches[i]];
				if (lastFamily != entry.family) {
					row = null; lastFamily = entry.family;
					if (families > 1 && entry.family != "") addHeading("family", entry.family, font, measure);
				}
				if (row == null || row.cells.length == columns) row = addRow("cells", cellHeight);
				var cell = cells[i]; cell.row = rows.length - 1; cell.column = row.cells.length;
				cell.x = cell.column * (cellWidth + GAP); cell.y = row.y; cell.width = cellWidth; cell.height = cellHeight;
				cell.textWidth = measure(entry.currentCaption);
				for (line in cell.lines) cell.textWidth = Math.max(cell.textWidth, measure(line));
				cell.textHeight = cell.lines.length * font + 4 + font;
				row.cells.push(cell); i++;
			}
		}
		return true;
	}
	function addRow(kind:String, height:Float):PickerLayoutRow {
		var index = rows.length;
		if (index >= rowPool.length) rowPool.push(new PickerLayoutRow());
		var row = rowPool[index]; row.kind = kind; row.y = contentHeight + (index == 0 ? 0 : GAP);
		row.height = height; row.cells.resize(0); row.lines.resize(0);
		contentHeight = row.y + height; rows.push(row); return row;
	}
	function addHeading(kind:String, label:String, font:Float, measure:String->Float):Void {
		var row = addRow(kind, font + PAD);
		wrap(label, Math.max(1, width - PAD * 2), measure, row.lines);
		row.height = row.lines.length * font + PAD; contentHeight = row.y + row.height;
	}
	/** Wrap into retained lines; break even a long unbroken identifier safely. */
	public static function wrap(text:String, available:Float, measure:String->Float, out:Array<String>):Void {
		out.resize(0); var line = "";
		for (word in text.split(" ")) {
			var joined = line == "" ? word : line + " " + word;
			if (measure(joined) <= available) { line = joined; continue; }
			if (line != "") { out.push(line); line = ""; }
			for (i in 0...word.length) {
				var next = line + word.charAt(i);
				if (line != "" && measure(next) > available) { out.push(line); line = ""; }
				line += word.charAt(i);
			}
		}
		if (line != "") out.push(line);
		if (out.length == 0) out.push("");
	}
	public function move(highlight:Int, dx:Int, dy:Int):Int {
		if (cells.length == 0) return -1;
		if (highlight < 0 || highlight >= cells.length) highlight = 0;
		var cell = cells[highlight];
		if (highlight != previousHighlight || desiredColumn < 0) desiredColumn = cell.column;
		var row = rows[cell.row]; var target = cell;
		if (dx != 0) {
			var col = Std.int(Math.max(0, Math.min(row.cells.length - 1, cell.column + dx)));
			target = row.cells[col]; desiredColumn = col;
		} else if (dy != 0) {
			var index = cell.row + dy;
			while (index >= 0 && index < rows.length) {
				var candidate = rows[index];
				if (candidate.cells.length > 0) {
					target = candidate.cells[Std.int(Math.min(desiredColumn, candidate.cells.length - 1))]; break;
				}
				index += dy;
			}
		}
		previousHighlight = target.matchIndex; return previousHighlight;
	}
	/** Content-relative scroll target; no previous-frame ImGui ScrollMax dependency. */
	public function scrollTo(highlight:Int, top:Float, view:Float):Float {
		var maximum = Math.max(0, contentHeight - view);
		if (highlight < 0 || highlight >= cells.length) return Math.max(0, Math.min(top, maximum));
		var cell = cells[highlight]; var target = top;
		if (cell.y < top) target = cell.y;
		else if (cell.y + cell.height > top + view) target = cell.y + cell.height - view;
		return Math.max(0, Math.min(target, maximum));
	}
	/** Explicit QA export only; the production renderer never serializes or writes. */
	public function report(name:String):Dynamic {
		return {name:name, width:width, columns:columns, minCellWidth:minCellWidth, gap:GAP,
			contentHeight:contentHeight, textLimited:textLimited,
			rows:[for (row in rows) {kind:row.kind, y:row.y, height:row.height}],
			cells:[for (cell in cells) {id:cell.id, x:cell.x, y:cell.y, width:cell.width, height:cell.height,
				row:cell.row, column:cell.column, textBounds:{x:cell.x + PAD, y:cell.y + PAD, width:cell.textWidth, height:cell.textHeight}}],
			expectedIds:[for (cell in cells) cell.id]};
	}
}

class PickerLayoutRow {
	public var kind:String = "";
	public var y:Float = 0;
	public var height:Float = 0;
	public var lines:Array<String> = [];
	public var cells:Array<PickerLayoutCell> = [];
	public function new() {}
}

class PickerLayoutCell {
	public var id:String = "";
	public var matchIndex:Int = 0;
	public var row:Int = 0;
	public var column:Int = 0;
	public var x:Float = 0;
	public var y:Float = 0;
	public var width:Float = 0;
	public var height:Float = 0;
	public var lines:Array<String> = [];
	public var textWidth:Float = 0;
	public var textHeight:Float = 0;
	public function new() {}
}
