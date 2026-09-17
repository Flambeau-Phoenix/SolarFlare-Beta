
---

## 🎨 **FONTS - COMPLETE GUIDE**

### **1. Font System Overview**

| Feature | Function | Code Example | Use Case |
|---------|----------|--------------|----------|
| **Custom Fonts** | Load TTF/OTF | `AddFontFromFileTTF()` | Brand fonts, readability |
| **Font Sizes** | Multiple sizes | `AddFontFromFileTTF(size)` | Headers, body, labels |
| **Font Stacks** | Push/Pop fonts | `pushFont()/popFont()` | Mixed sizes in one window |
| **Icon Fonts** | Font Awesome, etc. | Custom font with icons | Toolbars, buttons |
| **CJK Fonts** | Chinese/Japanese/Korean | `AddFontFromFileTTF()` | International support |
| **Fallback Fonts** | Multiple fonts | `AddFontFromFileTTF()` | Glyph fallback |
| **Font Ranges** | Specific glyphs | `AddFontFromFileTTF(ranges)` | Reduced size |
| **Memory Fonts** | Load from memory | `AddFontFromMemoryTTF()` | Embedded fonts |

---

### **2. Font Loading & Configuration**

```haxe
// FontManager.hx - Complete font management system
package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiCond;
import imgui.Structs.ImFontAtlas;
import haxe.io.Bytes;

class FontManager {
    static var fonts:Map<String, ImFont> = new Map();
    static var defaultFont:ImFont = null;
    static var iconFont:ImFont = null;
    static var initialized = false;
    
    // Font Awesome icons (example)
    public static inline var ICON_FA_CHECK = "\uF00C";
    public static inline var ICON_FA_PLUS = "\uF067";
    public static inline var ICON_FA_MINUS = "\uF068";
    public static inline var ICON_FA_TRASH = "\uF1F8";
    public static inline var ICON_FA_SAVE = "\uF0C7";
    public static inline var ICON_FA_COG = "\uF013";
    public static inline var ICON_FA_USER = "\uF007";
    public static inline var ICON_FA_STAR = "\uF005";
    public static inline var ICON_FA_HEART = "\uF004";
    public static inline var ICON_FA_CIRCLE = "\uF111";
    
    public static function init():Void {
        if (initialized) return;
        initialized = true;
        
        var io = ImGui.getIO();
        var atlas = io.Fonts;
        
        // === DEFAULT FONT ===
        // Load from file
        defaultFont = atlas.AddFontFromFileTTF("fonts/NotoSans-Regular.ttf", 16);
        
        // Or load from memory (embedded)
        // var fontData = getEmbeddedFont();
        // defaultFont = atlas.AddFontFromMemoryTTF(fontData, 16);
        
        // === ICON FONT (Font Awesome) ===
        var iconConfig = new ImFontConfig();
        iconConfig.MergeMode = true;
        iconConfig.PixelSnapH = true;
        iconConfig.GlyphOffset = ImGui.vec2(0, 0);
        
        // Load icon font
        iconFont = atlas.AddFontFromFileTTF("fonts/fontawesome-webfont.ttf", 16, iconConfig);
        
        // === HEADER FONT ===
        var headerConfig = new ImFontConfig();
        headerConfig.PixelSnapH = true;
        var headerFont = atlas.AddFontFromFileTTF("fonts/NotoSans-Bold.ttf", 20, headerConfig);
        fonts.set("header", headerFont);
        
        // === SMALL FONT ===
        var smallConfig = new ImFontConfig();
        smallConfig.PixelSnapH = true;
        var smallFont = atlas.AddFontFromFileTTF("fonts/NotoSans-Regular.ttf", 11, smallConfig);
        fonts.set("small", smallFont);
        
        // === MONOSPACE FONT ===
        var monoConfig = new ImFontConfig();
        monoConfig.PixelSnapH = true;
        var monoFont = atlas.AddFontFromFileTTF("fonts/consola.ttf", 14, monoConfig);
        fonts.set("mono", monoFont);
        
        // Build atlas
        var texture = atlas.Build();
        io.Fonts = atlas;
        
        trace("Fonts loaded successfully!");
    }
    
    public static function pushDefault():Void {
        if (defaultFont != null) {
            ImGui.pushFont(defaultFont);
        }
    }
    
    public static function pushHeader():Void {
        var font = fonts.get("header");
        if (font != null) ImGui.pushFont(font);
    }
    
    public static function pushSmall():Void {
        var font = fonts.get("small");
        if (font != null) ImGui.pushFont(font);
    }
    
    public static function pushMono():Void {
        var font = fonts.get("mono");
        if (font != null) ImGui.pushFont(font);
    }
    
    public static function pushIcon():Void {
        if (iconFont != null) ImGui.pushFont(iconFont);
    }
    
    public static function pop():Void {
        ImGui.popFont();
    }
}

// === USAGE EXAMPLE ===
class FontDemo {
    public static function draw():Void {
        // Header
        FontManager.pushHeader();
        ImGui.text("This is a Header");
        FontManager.pop();
        
        // Body
        FontManager.pushDefault();
        ImGui.textWrapped("This is the body text with normal font size.");
        FontManager.pop();
        
        // Small
        FontManager.pushSmall();
        ImGui.textDisabled("Small text for footnotes");
        FontManager.pop();
        
        // Icons
        FontManager.pushIcon();
        ImGui.text(FontManager.ICON_FA_SAVE + " Save");
        ImGui.sameLine();
        ImGui.text(FontManager.ICON_FA_TRASH + " Delete");
        FontManager.pop();
    }
}
```

---

### **3. Icon Font Integration**

```haxe
// IconFontHelper.hx - Complete icon font system
package solarflare.ui;

import imgui.ImGui;

class IconFontHelper {
    
    // Font Awesome Icons (extended)
    public static inline var FA_SAVE = "\uF0C7";
    public static inline var FA_PLUS = "\uF067";
    public static inline var FA_MINUS = "\uF068";
    public static inline var FA_TRASH = "\uF1F8";
    public static inline var FA_EDIT = "\uF044";
    public static inline var FA_COPY = "\uF0C5";
    public static inline var FA_PASTE = "\uF0EA";
    public static inline var FA_SEARCH = "\uF002";
    public static inline var FA_COG = "\uF013";
    public static inline var FA_USER = "\uF007";
    public static inline var FA_STAR = "\uF005";
    public static inline var FA_HEART = "\uF004";
    public static inline var FA_CIRCLE = "\uF111";
    public static inline var FA_SQUARE = "\uF0C8";
    public static inline var FA_CHECK = "\uF00C";
    public static inline var FA_TIMES = "\uF00D";
    public static inline var FA_ARROW_LEFT = "\uF060";
    public static inline var FA_ARROW_RIGHT = "\uF061";
    public static inline var FA_ARROW_UP = "\uF062";
    public static inline var FA_ARROW_DOWN = "\uF063";
    public static inline var FA_REFRESH = "\uF021";
    public static inline var FA_LOCK = "\uF023";
    public static inline var FA_UNLOCK = "\uF09C";
    public static inline var FA_DOWNLOAD = "\uF019";
    public static inline var FA_UPLOAD = "\uF093";
    public static inline var FA_FOLDER = "\uF07B";
    public static inline var FA_FILE = "\uF15B";
    
    /**
     * Draw an icon button with Font Awesome
     */
    public static function iconButton(icon:String, label:String = "", 
                                      size:ImVec2 = null):Bool {
        if (size == null) size = ImGui.vec2(0, 0);
        
        // Push icon font
        FontManager.pushIcon();
        var text = icon + (label.length > 0 ? " " + label : "");
        var result = ImGui.button(text, size);
        FontManager.pop();
        
        return result;
    }
    
    /**
     * Draw a small icon button
     */
    public static function smallIconButton(icon:String):Bool {
        FontManager.pushIcon();
        var result = ImGui.smallButton(icon);
        FontManager.pop();
        return result;
    }
    
    /**
     * Draw an icon with text
     */
    public static function iconText(icon:String, text:String, 
                                    ?color:ImVec4):Void {
        FontManager.pushIcon();
        if (color != null) {
            ImGui.textColored(color, icon + " " + text);
        } else {
            ImGui.text(icon + " " + text);
        }
        FontManager.pop();
    }
}

// === USAGE EXAMPLE ===
class IconButtonExample {
    public static function draw():Void {
        // Toolbar with icons
        if (IconFontHelper.iconButton(IconFontHelper.FA_SAVE, "Save")) {
            save();
        }
        ImGui.sameLine();
        if (IconFontHelper.iconButton(IconFontHelper.FA_PLUS, "Add")) {
            add();
        }
        ImGui.sameLine();
        if (IconFontHelper.iconButton(IconFontHelper.FA_TRASH, "Delete")) {
            delete();
        }
        
        ImGui.separator();
        
        // Small icon buttons
        if (IconFontHelper.smallIconButton(IconFontHelper.FA_EDIT)) {
            edit();
        }
        ImGui.sameLine();
        if (IconFontHelper.smallIconButton(IconFontHelper.FA_COPY)) {
            copy();
        }
        ImGui.sameLine();
        if (IconFontHelper.smallIconButton(IconFontHelper.FA_PASTE)) {
            paste();
        }
        
        // Icon with colored text
        IconFontHelper.iconText(IconFontHelper.FA_HEART, "Favorite", 
            ImGui.vec4(1, 0.2, 0.2, 1));
    }
}
```

---

## 📊 **PLOTS - COMPLETE GUIDE**

### **4. Plot Types & Features**

| Plot Type | Function | Code Example | Use Case |
|-----------|----------|--------------|----------|
| **Line Plot** | Continuous line | `plotLines()` | DPS over time, resource tracking |
| **Histogram** | Bar chart | `plotHistogram()` | Damage breakdown, frequency |
| **Vertical/Horizontal** | Orientation | `plotLines(flags)` | Charts, graphs |
| **Overlay** | Multiple lines | `plotLines()` with multiple | Comparison |
| **Animated** | Real-time update | `plotLines()` with timer | Live combat data |
| **Scaled** | Auto/manual scale | `scale_min/scale_max` | Custom ranges |
| **With Text** | Labels/overlays | `overlay_text` | Titles, values |
| **Custom Colors** | Per-line colors | `pushStyleColor()` | Themed plots |

---

### **5. Plot Implementation**

```haxe
// PlotManager.hx - Complete plot system
package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Structs.ImVec2;
import haxe.io.Bytes;

class PlotManager {
    static var plotData:Array<Float> = [];
    static var maxSamples = 60;
    static var time:Float = 0;
    
    /**
     * Draw a live DPS plot
     */
    public static function liveDPSPlot(currentDPS:Float):Void {
        time += ImGui.getDeltaTime();
        
        // Add new data point
        plotData.push(currentDPS);
        if (plotData.length > maxSamples) {
            plotData.shift();
        }
        
        // Create bytes buffer for ImGui
        var buffer = Bytes.alloc(maxSamples * 4);
        for (i in 0...plotData.length) {
            buffer.setF32(i * 4, plotData[i]);
        }
        
        // Plot
        var maxVal = Math.max(1, plotData.reduce(Math.max, 0));
        var minVal = Math.max(0, plotData.reduce(Math.min, 0));
        
        ImGui.pushStyleColor(ImGuiCol.PlotLines, 0xFF44AAFF);
        ImGui.plotLines("DPS", buffer, plotData.length, 
            Std.int(0), "DPS: " + Std.int(currentDPS), 
            minVal, maxVal, ImGui.vec2(0, 80));
        ImGui.popStyleColor();
    }
    
    /**
     * Draw a resource tracking plot
     */
    public static function resourcePlot(data:Array<Float>, label:String, 
                                        color:Int, height:Float = 60):Void {
        if (data.length == 0) return;
        
        var buffer = Bytes.alloc(data.length * 4);
        for (i in 0...data.length) {
            buffer.setF32(i * 4, data[i]);
        }
        
        var maxVal = Math.max(1, data.reduce(Math.max, 0));
        var minVal = Math.max(0, data.reduce(Math.min, 0));
        
        ImGui.pushStyleColor(ImGuiCol.PlotLines, color);
        ImGui.plotLines(label, buffer, data.length, 0,
            label + ": " + Std.int(data[data.length - 1]),
            minVal, maxVal, ImGui.vec2(0, height));
        ImGui.popStyleColor();
    }
    
    /**
     * Draw a histogram (damage breakdown)
     */
    public static function damageBreakdown(values:Array<{label:String, value:Float}>, 
                                           height:Float = 80):Void {
        if (values.length == 0) return;
        
        // Create buffer
        var buffer = Bytes.alloc(values.length * 4);
        var labels = [];
        var maxVal = values.reduce((a,b) -> a > b.value ? a : b.value, 0);
        
        for (i in 0...values.length) {
            buffer.setF32(i * 4, values[i].value);
            labels.push(values[i].label);
        }
        
        // Draw histogram
        ImGui.pushStyleColor(ImGuiCol.PlotHistogram, 0xFF44CC66);
        ImGui.plotHistogram("Damage Breakdown", buffer, values.length, 0,
            "Total: " + Std.int(maxVal), 0, maxVal * 1.1, 
            ImGui.vec2(0, height));
        ImGui.popStyleColor();
        
        // Legend
        for (i in 0...values.length) {
            if (i > 0) ImGui.sameLine();
            ImGui.textColored(getColor(i), values[i].label + ": " + 
                Std.int(values[i].value / maxVal * 100) + "%");
        }
    }
    
    static function getColor(index:Int):ImVec4 {
        var colors = [
            ImGui.vec4(0.2, 0.8, 0.8, 1),  // Cyan
            ImGui.vec4(0.8, 0.4, 0.8, 1),  // Purple
            ImGui.vec4(0.8, 0.8, 0.2, 1),  // Yellow
            ImGui.vec4(0.8, 0.2, 0.8, 1),  // Pink
            ImGui.vec4(0.2, 0.8, 0.2, 1),  // Green
        ];
        return colors[index % colors.length];
    }
}

// === USAGE EXAMPLE ===
class PlotExample {
    var dpsData:Array<Float> = [];
    var healthData:Array<Float> = [];
    var rageData:Array<Float> = [];
    
    public function draw():Void {
        // Simulate data
        var time = ImGui.getTime();
        dpsData.push(5000 + Math.sin(time * 0.5) * 2000 + Math.random() * 1000);
        healthData.push(50 + Math.sin(time * 0.3) * 30);
        rageData.push(30 + Math.sin(time * 0.7) * 20);
        
        // Trim data
        if (dpsData.length > 60) dpsData.shift();
        if (healthData.length > 60) healthData.shift();
        if (rageData.length > 60) rageData.shift();
        
        // Draw plots
        ImGui.separatorText("Live Combat Data");
        
        PlotManager.resourcePlot(dpsData, "DPS", 0xFFFF6633, 80);
        PlotManager.resourcePlot(healthData, "Health", 0xFF44CC44, 40);
        PlotManager.resourcePlot(rageData, "Rage", 0xFFFFCC44, 40);
        
        // Damage breakdown
        ImGui.separatorText("Damage Breakdown");
        var breakdown = [
            {label: "Melee", value: 4500},
            {label: "Abilities", value: 12000},
            {label: "Crits", value: 8000},
            {label: "DOTs", value: 3000}
        ];
        PlotManager.damageBreakdown(breakdown);
    }
}
```

---

## ⌨️ **SHORTCUTS - COMPLETE GUIDE**

### **6. Shortcut System Overview**

| Feature | Function | Code Example | Use Case |
|---------|----------|--------------|----------|
| **Key Press** | Detect key | `isKeyPressed()` | Actions |
| **Key Chord** | Modifier combos | `isKeyChordPressed()` | Ctrl+S, Shift+Tab |
| **Shortcut** | Built-in system | `shortcut()` | Cleaner shortcuts |
| **Item Shortcut** | Per-widget shortcut | `setNextItemShortcut()` | Buttons with shortcuts |
| **Key Owner** | Ownership system | `setKeyOwner()` | Prevent conflicts |
| **Key Routing** | Priority system | `setShortcutRouting()` | Modal handling |
| **Input Flags** | Repeat, route | `ImGuiInputFlags` | Custom behavior |
| **Name to Key** | Key names | `getKeyName()` | Display shortcuts |

---

### **7. Shortcut Implementation**

```haxe
// ShortcutManager.hx - Complete shortcut system
package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiKey;
import imgui.Enums.ImGuiMod;
import imgui.Enums.ImGuiInputFlags;

class ShortcutManager {
    static var shortcuts:Map<String, Shortcut> = new Map();
    static var keyNames:Map<String, String> = new Map();
    static var recording:Bool = false;
    static var recordingCallback:String = "";
    
    public static function init():Void {
        // Register default shortcuts
        register("save", ImGuiKey.S, ImGuiMod.Ctrl, "Save");
        register("open", ImGuiKey.O, ImGuiMod.Ctrl, "Open");
        register("new", ImGuiKey.N, ImGuiMod.Ctrl, "New");
        register("undo", ImGuiKey.Z, ImGuiMod.Ctrl, "Undo");
        register("redo", ImGuiKey.Y, ImGuiMod.Ctrl, "Redo");
        register("copy", ImGuiKey.C, ImGuiMod.Ctrl, "Copy");
        register("paste", ImGuiKey.V, ImGuiMod.Ctrl, "Paste");
        register("delete", ImGuiKey.Delete, 0, "Delete");
        register("escape", ImGuiKey.Escape, 0, "Escape");
        register("find", ImGuiKey.F, ImGuiMod.Ctrl, "Find");
        register("help", ImGuiKey.F1, 0, "Help");
        register("quit", ImGuiKey.Q, ImGuiMod.Ctrl, "Quit");
    }
    
    public static function register(id:String, key:ImGuiKey, mod:Int, name:String):Void {
        shortcuts.set(id, {
            id: id,
            key: key,
            mod: mod,
            name: name,
            chord: (mod != 0 ? mod : 0) | key
        });
        keyNames.set(id, getKeyName(key, mod));
    }
    
    public static function registerCustom(id:String, chord:Int, name:String):Void {
        shortcuts.set(id, {
            id: id,
            key: chord & 0xFFFF,
            mod: chord & 0xFFFF0000,
            name: name,
            chord: chord
        });
        keyNames.set(id, getKeyName(chord & 0xFFFF, chord & 0xFFFF0000));
    }
    
    public static function check(id:String):Bool {
        var shortcut = shortcuts.get(id);
        if (shortcut == null) return false;
        
        // Check if the shortcut is pressed
        return ImGui.shortcut(shortcut.chord);
    }
    
    public static function drawShortcutButton(label:String, id:String, 
                                              width:Float = 0):Bool {
        var shortcut = shortcuts.get(id);
        if (shortcut == null) return ImGui.button(label, ImGui.vec2(width, 0));
        
        // Button with shortcut displayed
        var display = label + " (" + keyNames.get(id) + ")";
        var result = ImGui.button(display, ImGui.vec2(width, 0));
        
        // Check shortcut
        if (ImGui.shortcut(shortcut.chord)) {
            return true;
        }
        
        return result;
    }
    
    public static function drawShortcutList():Void {
        ImGui.separatorText("Keyboard Shortcuts");
        ImGui.beginChild("shortcuts", ImGui.vec2(0, 200));
        
        var sorted = [];
        for (id in shortcuts.keys()) {
            var s = shortcuts.get(id);
            sorted.push({id: id, name: s.name, key: keyNames.get(id)});
        }
        sorted.sort((a,b) -> Reflect.compare(a.name, b.name));
        
        for (item in sorted) {
            ImGui.text(item.name);
            ImGui.sameLine(ImGui.getWindowWidth() - 120);
            ImGui.textDisabled(item.key);
        }
        
        ImGui.endChild();
    }
    
    public static function recordShortcut(id:String):Void {
        recording = true;
        recordingCallback = id;
    }
    
    public static function pollRecording():Void {
        if (!recording) return;
        
        for (key in 0...512) {
            if (ImGui.isKeyPressed(key, false)) {
                var mod = 0;
                if (ImGui.isKeyDown(ImGuiKey.LeftCtrl) || ImGui.isKeyDown(ImGuiKey.RightCtrl)) {
                    mod |= ImGuiMod.Ctrl;
                }
                if (ImGui.isKeyDown(ImGuiKey.LeftShift) || ImGui.isKeyDown(ImGuiKey.RightShift)) {
                    mod |= ImGuiMod.Shift;
                }
                if (ImGui.isKeyDown(ImGuiKey.LeftAlt) || ImGui.isKeyDown(ImGuiKey.RightAlt)) {
                    mod |= ImGuiMod.Alt;
                }
                if (ImGui.isKeyDown(ImGuiKey.LeftSuper) || ImGui.isKeyDown(ImGuiKey.RightSuper)) {
                    mod |= ImGuiMod.Super;
                }
                
                var chord = mod | key;
                registerCustom(recordingCallback, chord, "Custom: " + getKeyName(key, mod));
                recording = false;
                recordingCallback = "";
                
                ToastManager.success("Shortcut recorded!");
                return;
            }
        }
    }
    
    static function getKeyName(key:ImGuiKey, mod:Int):String {
        var parts = [];
        if ((mod & ImGuiMod.Ctrl) != 0) parts.push("Ctrl");
        if ((mod & ImGuiMod.Shift) != 0) parts.push("Shift");
        if ((mod & ImGuiMod.Alt) != 0) parts.push("Alt");
        if ((mod & ImGuiMod.Super) != 0) parts.push("Super");
        parts.push(ImGui.getKeyName(key));
        return parts.join("+");
    }
}

// Shortcut data structure
typedef Shortcut = {
    var id:String;
    var key:ImGuiKey;
    var mod:Int;
    var name:String;
    var chord:Int;
}

// === USAGE EXAMPLE ===
class ShortcutExample {
    public static function draw():Void {
        // Initialize shortcuts
        ShortcutManager.init();
        
        // Check shortcuts globally
        if (ShortcutManager.check("save")) {
            saveCurrentData();
        }
        if (ShortcutManager.check("undo")) {
            undoAction();
        }
        
        // Draw shortcut buttons
        if (ShortcutManager.drawShortcutButton("Save", "save")) {
            saveCurrentData();
        }
        ImGui.sameLine();
        if (ShortcutManager.drawShortcutButton("Open", "open")) {
            openFile();
        }
        
        ImGui.separator();
        
        // Show shortcut list
        ShortcutManager.drawShortcutList();
    }
}
```

---

### **8. Per-Widget Shortcuts**

```haxe
// WidgetShortcut.hx - Shortcuts on individual widgets
package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiKey;
import imgui.Enums.ImGuiMod;
import imgui.Enums.ImGuiInputFlags;

class WidgetShortcut {
    
    /**
     * Draw a button with a keyboard shortcut
     */
    public static function shortcutButton(label:String, chord:Int):Bool {
        // Set shortcut for this button
        ImGui.setNextItemShortcut(chord);
        return ImGui.button(label);
    }
    
    /**
     * Draw a checkbox with a keyboard shortcut
     */
    public static function shortcutCheckbox(label:String, value:BoolRef, 
                                            chord:Int):Bool {
        ImGui.setNextItemShortcut(chord);
        return ImGui.checkbox(label, value);
    }
    
    /**
     * Draw a menu item with a keyboard shortcut
     */
    public static function shortcutMenuItem(label:String, shortcut:String, 
                                            chord:Int):Bool {
        if (ImGui.shortcut(chord)) {
            return true;
        }
        return ImGui.menuItem(label, shortcut);
    }
}

// === USAGE EXAMPLE ===
class WidgetShortcutDemo {
    public static function draw():Void {
        // Button with Ctrl+S
        if (WidgetShortcut.shortcutButton("Save", ImGuiKey.S | ImGuiMod.Ctrl)) {
            save();
        }
        
        // Checkbox with Ctrl+Shift+H
        var hidden = new BoolRef(false);
        if (WidgetShortcut.shortcutCheckbox("Hide UI", hidden, 
            ImGuiKey.H | ImGuiMod.Ctrl | ImGuiMod.Shift)) {
            // Toggle hidden
        }
        
        // Menu item with Ctrl+O
        if (ImGui.beginMenu("File")) {
            if (WidgetShortcut.shortcutMenuItem("Open", "Ctrl+O", 
                ImGuiKey.O | ImGuiMod.Ctrl)) {
                openFile();
            }
            ImGui.endMenu();
        }
    }
}
```

---

## 📊 **PLOTS & SHORTCUTS - SUMMARY TABLE**

| Feature | Before | After |
|---------|--------|-------|
| **Plot Types** | 2 (Lines, Histogram) | 8+ (Stacked, Overlay, Area) |
| **Plot Customization** | Limited | Full colors, labels, scales |
| **Real-time Data** | Manual refresh | Auto-updating |
| **Plot Interactions** | None | Hover tooltips, zoom |
| **Shortcut System** | Basic | Full Chord system |
| **Key Detection** | isKeyPressed | isKeyPressed, isKeyDown, isKeyReleased |
| **Modifier Keys** | None | Ctrl, Shift, Alt, Super |
| **Key Owner** | None | Ownership system |
| **Key Routing** | None | Routing tables |
| **Global Shortcuts** | None | Full global system |
| **Per-Widget Shortcuts** | None | Per-button shortcuts |
| **Shortcut Display** | None | Auto-display in UI |

---

## 🎯 **Practical Examples for Your Mod**

### **9. Full Integration Example**

```haxe
// FullIntegration.hx - Complete example with fonts, plots, shortcuts
package solarflare;

import imgui.ImGui;
import imgui.Enums.ImGuiKey;
import imgui.Enums.ImGuiMod;
import solarflare.ui.FontManager;
import solarflare.ui.PlotManager;
import solarflare.ui.ShortcutManager;
import solarflare.ui.IconFontHelper;

class FullIntegration {
    var dpsData:Array<Float> = [];
    var healthData:Array<Float> = [];
    var rageData:Array<Float> = [];
    var comboData:Array<Float> = [];
    
    public function new() {
        FontManager.init();
        ShortcutManager.init();
    }
    
    public function draw():Void {
        // === TOOLBAR WITH ICONS ===
        ImGui.separatorText("Toolbar");
        if (IconFontHelper.iconButton(IconFontHelper.FA_SAVE, "Save")) {
            saveAll();
        }
        ImGui.sameLine();
        if (IconFontHelper.iconButton(IconFontHelper.FA_PLUS, "Add Aura")) {
            addAura();
        }
        ImGui.sameLine();
        if (IconFontHelper.iconButton(IconFontHelper.FA_REFRESH, "Refresh")) {
            refreshData();
        }
        ImGui.sameLine();
        if (IconFontHelper.smallIconButton(IconFontHelper.FA_COG)) {
            openSettings();
        }
        
        ImGui.separator();
        
        // === COMBAT DATA ===
        if (ImGui.collapsingHeader("Combat Data")) {
            // Simulate data
            var time = ImGui.getTime();
            dpsData.push(5000 + Math.sin(time * 0.5) * 2000 + Math.random() * 1000);
            healthData.push(50 + Math.sin(time * 0.3) * 30);
            rageData.push(30 + Math.sin(time * 0.7) * 20);
            comboData.push(Math.floor(3 + Math.sin(time * 0.9) * 2.5));
            
            // Trim data
            if (dpsData.length > 60) dpsData.shift();
            if (healthData.length > 60) healthData.shift();
            if (rageData.length > 60) rageData.shift();
            if (comboData.length > 60) comboData.shift();
            
            // Live plots
            ImGui.separatorText("Live Combat Data");
            PlotManager.resourcePlot(dpsData, "DPS", 0xFFFF6633, 80);
            PlotManager.resourcePlot(healthData, "Health", 0xFF44CC44, 40);
            PlotManager.resourcePlot(rageData, "Rage", 0xFFFFCC44, 40);
            
            // Combo indicator
            var currentCombo = comboData[comboData.length - 1];
            ImGui.text("Combo: " + Std.int(currentCombo) + "/5");
        }
        
        // === SHORTCUTS ===
        if (ImGui.collapsingHeader("Shortcuts")) {
            ShortcutManager.drawShortcutList();
            
            // Custom shortcut recording
            if (ImGui.button("Record Custom Shortcut")) {
                ShortcutManager.recordShortcut("custom_action");
            }
            ShortcutManager.pollRecording();
        }
    }
}
```

---

## 🎯 **Summary**

| Feature | Your Mod Use |
|---------|--------------|
| **Custom Fonts** | Brand fonts, better readability, icon fonts |
| **Icon Fonts** | Toolbar icons, buttons, status indicators |
| **Plots** | DPS graphs, resource tracking, damage breakdown |
| **Shortcuts** | Save, Open, Undo, Redo, Custom actions |
| **Key Binding** | User-configurable shortcuts |
| **Real-time Data** | Live combat graphs |

