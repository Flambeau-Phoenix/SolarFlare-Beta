package solarflare.extrabars;

import imgui.ImGui;
import solarflare.ui.GameIcons;
import solarflare.ui.HudChrome;
import solarflare.ui.HUDWidgetWindow;
import solarflare.ui.ThemePalette;

/** Configurable grid shell; only its first cell owns the runtime-gated test item. */
class ExtraBarsPrototypeBar {
 static inline var ACTIVE_OUTLINE:Int = 0xFF75D855;
 public function new() {}
 public function draw(slot:ExtraBarsPrototypeSlot, chrome:HudChrome, edit:Void->Void,
   rows:Int = 2, columns:Int = 4, pixels:Int = 48, onResize:Int->Void = null):Void {
  if (!slot.enabled || !ExtraBarsGrid.valid(rows, columns)) return;
  pixels = ExtraBarsGrid.size(pixels);
  var contentW:Single = ExtraBarsGrid.width(columns, pixels);
  var contentH:Single = ExtraBarsGrid.height(rows, pixels);
  HUDWidgetWindow.draw("SolarFlare.ExtraBarsPrototypeSlot", "ExtraBars", chrome, contentW, contentH, function(size) {
   var theme = ThemePalette.current();
   var origin = ImGui.getCursorScreenPos();
   var dl = ImGui.getWindowDrawList();
   for (index in 0...rows * columns) {
    var x:Single = origin.x + (index % columns) * (pixels + ExtraBarsGrid.GAP);
    var y:Single = origin.y + Std.int(index / columns) * (pixels + ExtraBarsGrid.GAP);
    ImGui.setCursorScreenPos(ImGui.vec2(x, y));
    ImGui.dummy(ImGui.vec2(pixels, pixels));
    var hovered = ImGui.isItemHovered();
    if (index == 0) {
     drawItem(dl, slot, x, y, pixels);
     if (hovered) ImGui.setTooltip(slot.inputLabel + " / " + slot.inputDetail + "\n" + slot.name + "\n" + slot.binding + "\n"
       + (slot.reason.length > 0 ? slot.reason : "Press the bar key to test native use."));
    } else {
     ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x, y), ImGui.vec2(x + pixels, y + pixels),
       ImGui.colorConvertFloat4ToU32(theme.cellBg), 4);
     ImGui.ImDrawList_AddRect(dl, ImGui.vec2(x, y), ImGui.vec2(x + pixels, y + pixels),
       slot.inputActive ? ACTIVE_OUTLINE : ImGui.colorConvertFloat4ToU32(theme.border), 4, 1);
     var label = "" + (index + 1);
     var measured = ImGui.calcTextSize(label);
     ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(x + (pixels - measured.x) * 0.5, y + (pixels - measured.y) * 0.5),
       ImGui.colorConvertFloat4ToU32(theme.textDisabled), label);
     if (hovered) ImGui.setTooltip("Empty cell " + (index + 1) + ". Additional assignments follow input acceptance.");
    }
   }
   var captionsY:Single = origin.y + contentH - ExtraBarsGrid.CAPTION + 3;
   var stateLabel = contentW >= 88 ? slot.inputLabel : (slot.inputActive ? "ON" : "OFF");
   drawKeyBadge(dl, stateLabel, origin.x + 2, captionsY,
     ImGui.colorConvertFloat4ToU32(slot.inputActive ? theme.accent : theme.border), contentW - 4, true);
   drawLabel(dl, slot.name, origin.x, captionsY + 16, contentW, ImGui.colorConvertFloat4ToU32(theme.textDisabled));
   ImGui.setCursorScreenPos(origin);
   ImGui.dummy(ImGui.vec2(contentW, contentH));
  }, edit, null, false, null, function(width:Single, height:Single) {
   if (onResize != null) onResize(ExtraBarsGrid.resized(rows, columns, width, height));
  });
 }
 public static function drawItem(dl:Dynamic, slot:ExtraBarsPrototypeSlot, x:Single, y:Single, pixels:Int):Void {
  var theme = ThemePalette.current();
  var edge = slot.ready ? theme.accent : theme.border;
  ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x, y), ImGui.vec2(x + pixels, y + pixels),
    ImGui.colorConvertFloat4ToU32(theme.cellBg), 4);
  if (!GameIcons.drawKey(dl, slot.icon, x + 3, y + 3, pixels - 6, pixels - 6)) {
   drawLabel(dl,slot.name,x+3,y+(pixels-ImGui.getFontSize())*0.5,pixels-6,ImGui.colorConvertFloat4ToU32(theme.text));
  }
  if (!slot.ready) ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x, y), ImGui.vec2(x + pixels, y + pixels),
    ImGui.colorConvertFloat4ToU32(theme.dimOverlay), 4);
  ImGui.ImDrawList_AddRect(dl, ImGui.vec2(x, y), ImGui.vec2(x + pixels, y + pixels),
    slot.inputActive ? ACTIVE_OUTLINE : ImGui.colorConvertFloat4ToU32(edge), 4, slot.inputActive ? 1 : 1.5);
  if (slot.triggerStrength > 0) {
   var flash = (Std.int(Math.min(1, slot.triggerStrength) * 255) << 24) | 0x00B8FFAA;
   ImGui.ImDrawList_AddRect(dl, ImGui.vec2(x + 1.5, y + 1.5), ImGui.vec2(x + pixels - 1.5, y + pixels - 1.5),
     flash, 3, 2);
  }
  if (slot.progress > 0 && slot.progress < 1) {
   var center = ImGui.vec2(x + pixels * 0.5, y + pixels * 0.5);
   var radius:Single = pixels * 0.375;
   ImGui.ImDrawList_AddCircle(dl, center, radius, 0xDD000000, 32, 5);
   ImGui.ImDrawList_PathArcTo(dl, center, radius, -Math.PI * 0.5,
     -Math.PI * 0.5 + Math.PI * 2 * slot.progress, 32);
   ImGui.ImDrawList_PathStroke(dl, ImGui.colorConvertFloat4ToU32(theme.accent), 3);
  }
  drawKeyBadge(dl, slot.keyHint, x + 3, y + 2, ImGui.colorConvertFloat4ToU32(edge), pixels - 6);
  var count = slot.known ? Std.string(slot.count) : "?";
  var textSize = ImGui.calcTextSize(count);
  var countX:Single = x + pixels - 3 - textSize.x;
  var countY:Single = y + pixels - textSize.y - 2;
  ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(countX + 1, countY + 1), 0xFF000000, count);
  ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(countX, countY), ImGui.colorConvertFloat4ToU32(theme.text), count);
 }
	/** Geaux-style contrast plate, top-left so counts remain clear at bottom-right. */
	public static function drawKeyBadge(dl:Dynamic, label:String, x:Single, y:Single, border:Int, width:Single, centered:Bool = false):Void {
		if (label.length == 0) return;
		var font = ImGui.getFont();
		var originalSize = ImGui.getFontSize();
		var naturalWidth = ImGui.calcTextSize(label).x;
		var badgeSize:Single = Math.min(originalSize, 12);
		if (naturalWidth > 0) badgeSize = Math.min(badgeSize, originalSize * Math.max(1, width - 3) / naturalWidth);
		if (font != null) ImGui.pushFont(font, Math.max(1, badgeSize));
		try {
			var textSize = ImGui.calcTextSize(label);
			if (centered) x += Math.max(0, (width - textSize.x) * 0.5);
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x - 1, y - 1),
				ImGui.vec2(x + textSize.x + 2, y + textSize.y + 1), 0xE6000000, 3);
			ImGui.ImDrawList_AddRect(dl, ImGui.vec2(x - 1, y - 1),
				ImGui.vec2(x + textSize.x + 2, y + textSize.y + 1), border, 3, 1);
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(x, y), 0xFFF0F5FF, label);
		} catch (e:Dynamic) {
			if (font != null) ImGui.popFont();
			throw e;
		}
		if (font != null) ImGui.popFont();
	}
	public static function drawLabel(dl:Dynamic, label:String, x:Single, y:Single, width:Single, color:Int):Void {
		var visible = label;
		while (visible.length > 1 && ImGui.calcTextSize(visible).x > width) visible = visible.substr(0, visible.length - 1);
		if (visible.length < label.length && visible.length > 3) visible = visible.substr(0, visible.length - 3) + "...";
		var w = ImGui.calcTextSize(visible).x;
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(x + Math.max(0, (width - w) * 0.5), y), color, visible);
	}
}
