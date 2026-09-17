
---

## 🪟 **WINDOWS & TITLE BARS - COMPLETE GUIDE**

### **1. Window Types & Variations**

| Window Type | Function | Code Example | Use Case |
|-------------|----------|--------------|----------|
| **Standard Window** | Regular movable window | `ImGui.begin("Window")` | Main UI panels |
| **Child Window** | Nested scrollable area | `ImGui.beginChild("Child")` | Lists, content areas |
| **Popup Window** | Temporary overlay | `ImGui.beginPopup("Popup")` | Context menus |
| **Modal Window** | Blocking window | `ImGui.beginPopupModal("Modal")` | Dialogs, confirmations |
| **Tooltip Window** | Hover-activated | `ImGui.beginTooltip()` | Help text |
| **Dockable Window** | Can be docked | `ImGui.setNextWindowDockID()` | Workspace panels |
| **Floating Window** | No docking | `ImGui.begin("Window", null, ImGuiWindowFlags.NoDocking)` | Popups |
| **Fixed Window** | Fixed position/size | `ImGui.setNextWindowPos()` + `ImGui.setNextWindowSize()` | Debug overlays |
| **Transparent Window** | See-through | `ImGui.setNextWindowBgAlpha(0)` | HUD overlays |
| **NoTitleBar Window** | Without title bar | `ImGuiWindowFlags.NoTitleBar` | Custom title bars |

---

### **2. Window Flags (Comprehensive)**

```haxe
enum ImGuiWindowFlags {
    None;                          // Default
    NoTitleBar;                    // No title bar
    NoResize;                      // Cannot resize
    NoMove;                        // Cannot move
    NoScrollbar;                   // No scrollbar
    NoScrollWithMouse;             // No mouse scrolling
    NoCollapse;                    // Cannot collapse
    AlwaysAutoResize;              // Auto-resize to content
    NoBackground;                  // No background
    NoSavedSettings;               // No saved settings
    NoMouseInputs;                 // No mouse input
    MenuBar;                       // Has menu bar
    HorizontalScrollbar;           // Horizontal scrollbar
    NoFocusOnAppearing;            // No focus on appear
    NoBringToFrontOnFocus;         // No bring to front
    AlwaysVerticalScrollbar;       // Always show vertical scroll
    AlwaysHorizontalScrollbar;     // Always show horizontal scroll
    NoNavInputs;                   // No navigation input
    NoNavFocus;                    // No navigation focus
    UnsavedDocument;               // Unsaved document marker
    NoDocking;                     // Cannot be docked
    NoNav;                         // No navigation
    NoDecoration;                  // No title bar, no resize, no scrollbar, no collapse
    NoInputs;                      // No mouse or nav inputs
    ChildWindow;                   // Child window flag
    Tooltip;                       // Tooltip flag
    Popup;                         // Popup flag
    Modal;                         // Modal flag
    ChildMenu;                     // Child menu flag
    DockNode;                      // Dock node flag
}
```

---

### **3. New Window API**

```haxe
// === STANDARD WINDOW ===
ImGui.begin("My Window");
ImGui.text("Hello!");
ImGui.end();

// === WINDOW WITH OPEN STATE ===
var open = true;
if (ImGui.begin("My Window", open)) {
    // Content
}
ImGui.end();

// === WINDOW WITH CUSTOM FLAGS ===
ImGui.begin("My Window", null, 
    ImGuiWindowFlags.NoTitleBar | 
    ImGuiWindowFlags.NoResize | 
    ImGuiWindowFlags.NoMove);

// === WINDOW WITH SIZE CONSTRAINTS ===
ImGui.setNextWindowSizeConstraints(
    ImGui.vec2(200, 100),  // Min
    ImGui.vec2(600, 400)   // Max
);
ImGui.begin("My Window");

// === WINDOW WITH INITIAL SIZE ===
ImGui.setNextWindowSize(ImGui.vec2(400, 300), ImGuiCond.FirstUseEver);
ImGui.begin("My Window");

// === WINDOW WITH POSITION ===
ImGui.setNextWindowPos(ImGui.vec2(100, 100), ImGuiCond.FirstUseEver);
ImGui.begin("My Window");

// === WINDOW WITH PIVOT ===
ImGui.setNextWindowPos(ImGui.vec2(100, 100), ImGuiCond.Always, ImGui.vec2(0.5, 0.5));
ImGui.begin("My Window");

// === WINDOW WITH BG ALPHA ===
ImGui.setNextWindowBgAlpha(0.8);
ImGui.begin("My Window");

// === WINDOW WITH VIEWPORT ===
ImGui.setNextWindowViewport(viewport_id);
ImGui.begin("My Window");
```

---

### **4. Professional Title Bars**

```haxe
// TitleBar.hx - Professional title bar system
package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiCond;
import imgui.Enums.ImGuiMouseButton;
import imgui.Enums.ImGuiWindowFlags;
import imgui.Structs.ImVec2;
import imgui.Structs.ImRect;

class TitleBar {
    public var title:String = "";
    public var icon:String = "";
    public var height:Float = 28;
    public var showClose:Bool = true;
    public var showMinimize:Bool = true;
    public var showMaximize:Bool = true;
    public var showPinned:Bool = true;
    public var isPinned:Bool = false;
    public var isMaximized:Bool = false;
    
    public function draw(windowName:String, content:Void->Void):Bool {
        var flags = ImGuiWindowFlags.NoTitleBar | 
                   ImGuiWindowFlags.NoCollapse |
                   ImGuiWindowFlags.NoResize;
                   
        ImGui.begin(windowName, null, flags);
        
        var pos = ImGui.getWindowPos();
        var size = ImGui.getWindowSize();
        var drawList = ImGui.getWindowDrawList();
        
        // === TITLE BAR BACKGROUND ===
        var barColor = ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.15, 0.17, 0.22, 0.95));
        ImGui.ImDrawList_AddRectFilled(drawList,
            ImGui.vec2(pos.x, pos.y),
            ImGui.vec2(pos.x + size.x, pos.y + height),
            barColor, 4);
            
        // === TITLE BAR GLOW ===
        var glowColor = ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.3, 0.5, 0.8, 0.2));
        ImGui.ImDrawList_AddRectFilled(drawList,
            ImGui.vec2(pos.x, pos.y + height - 1),
            ImGui.vec2(pos.x + size.x, pos.y + height + 1),
            glowColor);
            
        // === ICON ===
        if (icon.length > 0) {
            ImGui.setCursorScreenPos(ImGui.vec2(pos.x + 8, pos.y + (height - 16) / 2));
            ImGui.text(icon);
            ImGui.sameLine();
        }
        
        // === TITLE ===
        ImGui.setCursorScreenPos(ImGui.vec2(pos.x + (icon.length > 0 ? 28 : 8), pos.y + (height - 14) / 2));
        ImGui.textColored(ImGui.vec4(1, 1, 1, 0.9), title);
        
        // === TITLE BAR BUTTONS ===
        var btnSize = 18;
        var btnY = pos.y + (height - btnSize) / 2;
        var btnX = pos.x + size.x - 4;
        
        // Close button
        if (showClose) {
            btnX -= btnSize + 2;
            drawCloseButton(drawList, ImGui.vec2(btnX, btnY), btnSize);
            if (ImGui.invisibleButton("##close", ImGui.vec2(btnSize, btnSize))) {
                return false; // Close window
            }
        }
        
        // Maximize button
        if (showMaximize) {
            btnX -= btnSize + 2;
            drawMaximizeButton(drawList, ImGui.vec2(btnX, btnY), btnSize);
            if (ImGui.invisibleButton("##maximize", ImGui.vec2(btnSize, btnSize))) {
                isMaximized = !isMaximized;
            }
        }
        
        // Minimize button
        if (showMinimize) {
            btnX -= btnSize + 2;
            drawMinimizeButton(drawList, ImGui.vec2(btnX, btnY), btnSize);
            if (ImGui.invisibleButton("##minimize", ImGui.vec2(btnSize, btnSize))) {
                // Minimize logic
            }
        }
        
        // Pin button
        if (showPinned) {
            btnX -= btnSize + 2;
            drawPinButton(drawList, ImGui.vec2(btnX, btnY), btnSize, isPinned);
            if (ImGui.invisibleButton("##pin", ImGui.vec2(btnSize, btnSize))) {
                isPinned = !isPinned;
            }
        }
        
        // === CONTENT AREA ===
        ImGui.setCursorPosY(height);
        ImGui.beginChild("##content", ImGui.vec2(0, 0), false);
        content();
        ImGui.endChild();
        
        ImGui.end();
        return true;
    }
    
    function drawCloseButton(drawList:Dynamic, pos:ImVec2, size:Float):Void {
        var color = 0x66FFFFFF;
        var hoverColor = 0xFFFF4444;
        ImGui.ImDrawList_AddRectFilled(drawList,
            pos,
            ImGui.vec2(pos.x + size, pos.y + size),
            ImGui.isItemHovered() ? hoverColor : color, 4);
        var pad = size * 0.25;
        ImGui.ImDrawList_AddLine(drawList,
            ImGui.vec2(pos.x + pad, pos.y + pad),
            ImGui.vec2(pos.x + size - pad, pos.y + size - pad),
            0xFFFFFFFF, 1.5);
        ImGui.ImDrawList_AddLine(drawList,
            ImGui.vec2(pos.x + size - pad, pos.y + pad),
            ImGui.vec2(pos.x + pad, pos.y + size - pad),
            0xFFFFFFFF, 1.5);
    }
    
    function drawMaximizeButton(drawList:Dynamic, pos:ImVec2, size:Float):Void {
        var color = 0x66FFFFFF;
        var pad = size * 0.2;
        var innerPad = isMaximized ? size * 0.35 : size * 0.25;
        ImGui.ImDrawList_AddRect(drawList,
            ImGui.vec2(pos.x + pad, pos.y + pad),
            ImGui.vec2(pos.x + size - pad, pos.y + size - pad),
            color, 2);
        if (isMaximized) {
            ImGui.ImDrawList_AddRect(drawList,
                ImGui.vec2(pos.x + innerPad, pos.y + innerPad),
                ImGui.vec2(pos.x + size - innerPad, pos.y + size - innerPad),
                color, 2);
        }
    }
    
    function drawMinimizeButton(drawList:Dynamic, pos:ImVec2, size:Float):Void {
        var color = 0x66FFFFFF;
        var y = pos.y + size * 0.6;
        ImGui.ImDrawList_AddLine(drawList,
            ImGui.vec2(pos.x + size * 0.2, y),
            ImGui.vec2(pos.x + size * 0.8, y),
            color, 2);
    }
    
    function drawPinButton(drawList:Dynamic, pos:ImVec2, size:Float, pinned:Bool):Void {
        var color = pinned ? 0xFFFF4444 : 0x66FFFFFF;
        var cx = pos.x + size/2;
        var cy = pos.y + size/2;
        ImGui.ImDrawList_AddCircleFilled(drawList,
            ImGui.vec2(cx, cy),
            size * 0.3,
            color, 8);
        if (pinned) {
            ImGui.ImDrawList_AddCircleFilled(drawList,
                ImGui.vec2(cx, cy),
                size * 0.15,
                0xFFFFFFFF, 6);
        }
    }
}
```

---

### **5. Enhanced Window Styling**

```haxe
// WindowStyling.hx - Professional window styling
package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiStyleVar;
import imgui.Structs.ImVec2;
import imgui.Structs.ImRect;

class WindowStyling {
    /**
     * Push professional window style
     */
    public static function pushProfessionalStyle():Void {
        // Background
        ImGui.pushStyleColor(ImGuiCol.WindowBg, ImGui.vec4(0.08, 0.09, 0.12, 0.95));
        ImGui.pushStyleColor(ImGuiCol.ChildBg, ImGui.vec4(0.1, 0.11, 0.14, 0.95));
        
        // Borders
        ImGui.pushStyleColor(ImGuiCol.Border, ImGui.vec4(0.3, 0.33, 0.42, 0.5));
        ImGui.pushStyleColor(ImGuiCol.BorderShadow, ImGui.vec4(0, 0, 0, 0));
        
        // Title bar
        ImGui.pushStyleColor(ImGuiCol.TitleBg, ImGui.vec4(0.15, 0.17, 0.22, 0.95));
        ImGui.pushStyleColor(ImGuiCol.TitleBgActive, ImGui.vec4(0.2, 0.22, 0.28, 0.95));
        ImGui.pushStyleColor(ImGuiCol.TitleBgCollapsed, ImGui.vec4(0.12, 0.13, 0.16, 0.95));
        
        // Text
        ImGui.pushStyleColor(ImGuiCol.Text, ImGui.vec4(0.92, 0.94, 0.96, 1));
        ImGui.pushStyleColor(ImGuiCol.TextDisabled, ImGui.vec4(0.6, 0.62, 0.66, 1));
        
        // Scrollbar
        ImGui.pushStyleColor(ImGuiCol.ScrollbarBg, ImGui.vec4(0.12, 0.13, 0.16, 1));
        ImGui.pushStyleColor(ImGuiCol.ScrollbarGrab, ImGui.vec4(0.25, 0.28, 0.35, 0.8));
        ImGui.pushStyleColor(ImGuiCol.ScrollbarGrabHovered, ImGui.vec4(0.3, 0.35, 0.45, 0.9));
        ImGui.pushStyleColor(ImGuiCol.ScrollbarGrabActive, ImGui.vec4(0.35, 0.4, 0.55, 1));
        
        // Style vars
        ImGui.pushStyleVar(ImGuiStyleVar.WindowRounding, 8);
        ImGui.pushStyleVar(ImGuiStyleVar.WindowBorderSize, 1);
        ImGui.pushStyleVar(ImGuiStyleVar.WindowPadding, ImGui.vec2(8, 8));
        ImGui.pushStyleVar(ImGuiStyleVar.WindowTitleAlign, ImGui.vec2(0.5, 0.5));
        ImGui.pushStyleVar(ImGuiStyleVar.WindowMinSize, ImGui.vec2(100, 40));
        ImGui.pushStyleVar(ImGuiStyleVar.ChildRounding, 4);
        ImGui.pushStyleVar(ImGuiStyleVar.ChildBorderSize, 1);
    }
    
    public static function popProfessionalStyle():Void {
        ImGui.popStyleVar(7);
        ImGui.popStyleColor(14);
    }
    
    /**
     * Push modern dark style
     */
    public static function pushDarkStyle():Void {
        ImGui.pushStyleColor(ImGuiCol.WindowBg, ImGui.vec4(0.06, 0.06, 0.08, 0.95));
        ImGui.pushStyleColor(ImGuiCol.TitleBg, ImGui.vec4(0.1, 0.1, 0.15, 0.95));
        ImGui.pushStyleColor(ImGuiCol.TitleBgActive, ImGui.vec4(0.15, 0.15, 0.22, 0.95));
        ImGui.pushStyleVar(ImGuiStyleVar.WindowRounding, 4);
        ImGui.pushStyleVar(ImGuiStyleVar.WindowPadding, ImGui.vec2(4, 4));
    }
    
    public static function popDarkStyle():Void {
        ImGui.popStyleVar(2);
        ImGui.popStyleColor(3);
    }
}
```

---

### **6. Advanced Title Bar Text Features**

```haxe
// TitleBarText.hx - Advanced title bar text
package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Structs.ImVec2;

class TitleBarText {
    /**
     * Draw text with glow effect
     */
    public static function glow(drawList:Dynamic, pos:ImVec2, text:String, 
                                 color:Int, glowColor:Int, glowRadius:Float = 4):Void {
        // Draw glow passes
        for (i in 0...8) {
            var angle = (i / 8) * Math.PI * 2;
            var x = pos.x + Math.cos(angle) * glowRadius;
            var y = pos.y + Math.sin(angle) * glowRadius;
            ImGui.ImDrawList_AddText_Vec2(drawList, ImGui.vec2(x, y), glowColor, text);
        }
        // Main text
        ImGui.ImDrawList_AddText_Vec2(drawList, pos, color, text);
    }
    
    /**
     * Draw gradient text
     */
    public static function gradient(drawList:Dynamic, pos:ImVec2, text:String,
                                    colorTop:Int, colorBottom:Int):Void {
        var chars = text.split("");
        var totalWidth = ImGui.calcTextSize(text).x;
        var charWidth = totalWidth / chars.length;
        
        for (i in 0...chars.length) {
            var t = i / chars.length;
            var color = lerpColor(colorTop, colorBottom, t);
            var x = pos.x + i * charWidth;
            ImGui.ImDrawList_AddText_Vec2(drawList, 
                ImGui.vec2(x, pos.y), color, chars[i]);
        }
    }
    
    /**
     * Draw shadowed text
     */
    public static function shadow(drawList:Dynamic, pos:ImVec2, text:String,
                                  color:Int, shadowColor:Int, offset:ImVec2 = null):Void {
        if (offset == null) offset = ImGui.vec2(1, 1);
        ImGui.ImDrawList_AddText_Vec2(drawList, 
            ImGui.vec2(pos.x + offset.x, pos.y + offset.y), shadowColor, text);
        ImGui.ImDrawList_AddText_Vec2(drawList, pos, color, text);
    }
    
    /**
     * Draw animated text (pulsing)
     */
    public static function animated(drawList:Dynamic, pos:ImVec2, text:String,
                                    baseColor:Int, speed:Float = 1):Void {
        var pulse = 0.5 + 0.5 * Math.sin(ImGui.getTime() * speed);
        var alpha = Std.int(128 + 127 * pulse);
        var color = (baseColor & 0x00FFFFFF) | (alpha << 24);
        ImGui.ImDrawList_AddText_Vec2(drawList, pos, color, text);
    }
    
    static function lerpColor(c1:Int, c2:Int, t:Float):Int {
        var a1 = (c1 >> 24) & 0xFF;
        var r1 = (c1 >> 16) & 0xFF;
        var g1 = (c1 >> 8) & 0xFF;
        var b1 = c1 & 0xFF;
        var a2 = (c2 >> 24) & 0xFF;
        var r2 = (c2 >> 16) & 0xFF;
        var g2 = (c2 >> 8) & 0xFF;
        var b2 = c2 & 0xFF;
        return (Std.int(a1 + (a2 - a1) * t) << 24) |
               (Std.int(r1 + (r2 - r1) * t) << 16) |
               (Std.int(g1 + (g2 - g1) * t) << 8) |
               Std.int(b1 + (b2 - b1) * t);
    }
}
```

---

### **7. Custom Window Decorations**

```haxe
// WindowDecorations.hx - Custom window decorations
package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Structs.ImVec2;
import imgui.Structs.ImRect;

class WindowDecorations {
    /**
     * Draw decorative corner accents
     */
    public static function cornerAccents(drawList:Dynamic, rect:ImRect, 
                                         color:Int, size:Float = 6):Void {
        // Top-left
        ImGui.ImDrawList_AddRectFilled(drawList,
            ImGui.vec2(rect.Min.x + 2, rect.Min.y + 2),
            ImGui.vec2(rect.Min.x + 2 + size, rect.Min.y + 2 + 1),
            color);
        ImGui.ImDrawList_AddRectFilled(drawList,
            ImGui.vec2(rect.Min.x + 2, rect.Min.y + 2),
            ImGui.vec2(rect.Min.x + 2 + 1, rect.Min.y + 2 + size),
            color);
            
        // Top-right
        ImGui.ImDrawList_AddRectFilled(drawList,
            ImGui.vec2(rect.Max.x - 2 - size, rect.Min.y + 2),
            ImGui.vec2(rect.Max.x - 2, rect.Min.y + 2 + 1),
            color);
        ImGui.ImDrawList_AddRectFilled(drawList,
            ImGui.vec2(rect.Max.x - 2 - 1, rect.Min.y + 2),
            ImGui.vec2(rect.Max.x - 2, rect.Min.y + 2 + size),
            color);
            
        // Bottom-left
        ImGui.ImDrawList_AddRectFilled(drawList,
            ImGui.vec2(rect.Min.x + 2, rect.Max.y - 2 - 1),
            ImGui.vec2(rect.Min.x + 2 + size, rect.Max.y - 2),
            color);
        ImGui.ImDrawList_AddRectFilled(drawList,
            ImGui.vec2(rect.Min.x + 2, rect.Max.y - 2 - size),
            ImGui.vec2(rect.Min.x + 2 + 1, rect.Max.y - 2),
            color);
            
        // Bottom-right
        ImGui.ImDrawList_AddRectFilled(drawList,
            ImGui.vec2(rect.Max.x - 2 - size, rect.Max.y - 2 - 1),
            ImGui.vec2(rect.Max.x - 2, rect.Max.y - 2),
            color);
        ImGui.ImDrawList_AddRectFilled(drawList,
            ImGui.vec2(rect.Max.x - 2 - 1, rect.Max.y - 2 - size),
            ImGui.vec2(rect.Max.x - 2, rect.Max.y - 2),
            color);
    }
    
    /**
     * Draw decorative border (double line)
     */
    public static function doubleBorder(drawList:Dynamic, rect:ImRect, 
                                        color1:Int, color2:Int):Void {
        // Outer border
        ImGui.ImDrawList_AddRect(drawList,
            ImGui.vec2(rect.Min.x, rect.Min.y),
            ImGui.vec2(rect.Max.x, rect.Max.y),
            color1, 4);
            
        // Inner border (offset)
        ImGui.ImDrawList_AddRect(drawList,
            ImGui.vec2(rect.Min.x + 4, rect.Min.y + 4),
            ImGui.vec2(rect.Max.x - 4, rect.Max.y - 4),
            color2, 2);
    }
    
    /**
     * Draw gradient border
     */
    public static function gradientBorder(drawList:Dynamic, rect:ImRect, 
                                          color1:Int, color2:Int,
                                          width:Float = 2):Void {
        // Top
        ImGui.ImDrawList_AddLine(drawList,
            ImGui.vec2(rect.Min.x, rect.Min.y),
            ImGui.vec2(rect.Max.x, rect.Min.y),
            color1, width);
        // Bottom
        ImGui.ImDrawList_AddLine(drawList,
            ImGui.vec2(rect.Min.x, rect.Max.y),
            ImGui.vec2(rect.Max.x, rect.Max.y),
            color2, width);
        // Left
        ImGui.ImDrawList_AddLine(drawList,
            ImGui.vec2(rect.Min.x, rect.Min.y),
            ImGui.vec2(rect.Min.x, rect.Max.y),
            color1, width);
        // Right
        ImGui.ImDrawList_AddLine(drawList,
            ImGui.vec2(rect.Max.x, rect.Min.y),
            ImGui.vec2(rect.Max.x, rect.Max.y),
            color2, width);
    }
}
```

---

### **8. Window with Custom Title Bar - Complete Example**

```haxe
// CustomWindow.hx - Complete custom window example
package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiCond;
import imgui.Enums.ImGuiMouseButton;
import imgui.Enums.ImGuiWindowFlags;
import imgui.Structs.ImVec2;
import imgui.Structs.ImRect;
import imgui.ref.BoolRef;

class CustomWindow {
    public var open:BoolRef = new BoolRef(true);
    public var title:String = "My Window";
    public var icon:String = "🚀";
    public var pinned:Bool = false;
    public var minimized:Bool = false;
    public var maximized:Bool = false;
    public var titleBarHeight:Float = 32;
    public var showClose:Bool = true;
    public var showMinimize:Bool = true;
    public var showMaximize:Bool = true;
    public var showPin:Bool = true;
    
    var isDragging:Bool = false;
    var dragStart:ImVec2 = ImGui.vec2(0, 0);
    var windowPos:ImVec2 = ImGui.vec2(0, 0);
    
    public function draw(content:Void->Void):Bool {
        if (!open.get()) return false;
        
        // Window flags
        var flags = ImGuiWindowFlags.NoTitleBar | 
                   ImGuiWindowFlags.NoCollapse |
                   ImGuiWindowFlags.NoResize |
                   ImGuiWindowFlags.NoMove |
                   ImGuiWindowFlags.NoScrollbar;
                   
        if (!minimized) {
            flags |= ImGuiWindowFlags.NoScrollbar;
        }
        
        // Position
        if (windowPos.x != 0 || windowPos.y != 0) {
            ImGui.setNextWindowPos(windowPos, ImGuiCond.Always);
        }
        
        // Size
        if (maximized) {
            var viewport = ImGui.getMainViewport();
            ImGui.setNextWindowSize(viewport.WorkSize, ImGuiCond.Always);
            ImGui.setNextWindowPos(viewport.WorkPos, ImGuiCond.Always);
        } else {
            ImGui.setNextWindowSize(ImGui.vec2(400, 300), ImGuiCond.FirstUseEver);
        }
        
        ImGui.pushStyleColor(ImGuiCol.WindowBg, ImGui.vec4(0.08, 0.09, 0.12, 0.95));
        ImGui.pushStyleColor(ImGuiCol.Border, ImGui.vec4(0.3, 0.33, 0.42, 0.5));
        
        var began = ImGui.begin("##custom_window", null, flags);
        if (!began) {
            ImGui.popStyleColor(2);
            return false;
        }
        
        var pos = ImGui.getWindowPos();
        var size = ImGui.getWindowSize();
        var drawList = ImGui.getWindowDrawList();
        
        // === DROP SHADOW ===
        var rect = new ImRect(pos, ImGui.vec2(pos.x + size.x, pos.y + size.y));
        WindowEffects.dropShadow(drawList, rect, 8, 0.3);
        
        // === TITLE BAR ===
        drawTitleBar(drawList, pos, size);
        
        // === CONTENT ===
        if (!minimized) {
            ImGui.setCursorPosY(titleBarHeight);
            ImGui.beginChild("##content", ImGui.vec2(0, -4), false);
            content();
            ImGui.endChild();
        }
        
        ImGui.popStyleColor(2);
        ImGui.end();
        
        return true;
    }
    
    function drawTitleBar(drawList:Dynamic, pos:ImVec2, size:ImVec2):Void {
        var rect = new ImRect(
            ImGui.vec2(pos.x, pos.y),
            ImGui.vec2(pos.x + size.x, pos.y + titleBarHeight)
        );
        
        // Title bar background
        var barColor = ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.15, 0.17, 0.22, 0.95));
        ImGui.ImDrawList_AddRectFilled(drawList, rect.Min, rect.Max, barColor, 4);
        
        // Title bar glow
        var glowColor = ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.3, 0.5, 0.8, 0.15));
        ImGui.ImDrawList_AddRectFilled(drawList,
            ImGui.vec2(rect.Min.x, rect.Max.y - 1),
            ImGui.vec2(rect.Max.x, rect.Max.y + 1),
            glowColor);
            
        // Icon
        ImGui.setCursorScreenPos(ImGui.vec2(pos.x + 8, pos.y + (titleBarHeight - 16) / 2));
        ImGui.text(icon);
        ImGui.sameLine();
        
        // Title with glow
        var titleX = pos.x + (icon.length > 0 ? 28 : 8);
        var titleY = pos.y + (titleBarHeight - 14) / 2;
        TitleBarText.shadow(drawList, 
            ImGui.vec2(titleX, titleY), title,
            0xFFFFFFFF, 0x44000000, ImGui.vec2(1, 1));
            
        // === BUTTONS ===
        var btnSize = 18;
        var btnY = pos.y + (titleBarHeight - btnSize) / 2;
        var btnX = pos.x + size.x - 4;
        
        // Close
        if (showClose) {
            btnX -= btnSize + 2;
            drawCloseButton(drawList, ImGui.vec2(btnX, btnY), btnSize);
            if (ImGui.invisibleButton("##close", ImGui.vec2(btnSize, btnSize))) {
                open.set(false);
            }
        }
        
        // Maximize
        if (showMaximize) {
            btnX -= btnSize + 2;
            drawMaximizeButton(drawList, ImGui.vec2(btnX, btnY), btnSize, maximized);
            if (ImGui.invisibleButton("##maximize", ImGui.vec2(btnSize, btnSize))) {
                maximized = !maximized;
            }
        }
        
        // Minimize
        if (showMinimize) {
            btnX -= btnSize + 2;
            drawMinimizeButton(drawList, ImGui.vec2(btnX, btnY), btnSize);
            if (ImGui.invisibleButton("##minimize", ImGui.vec2(btnSize, btnSize))) {
                minimized = !minimized;
            }
        }
        
        // Pin
        if (showPin) {
            btnX -= btnSize + 2;
            drawPinButton(drawList, ImGui.vec2(btnX, btnY), btnSize, pinned);
            if (ImGui.invisibleButton("##pin", ImGui.vec2(btnSize, btnSize))) {
                pinned = !pinned;
            }
        }
        
        // === DRAG HANDLE ===
        ImGui.setCursorScreenPos(ImGui.vec2(pos.x + 32, pos.y));
        ImGui.invisibleButton("##drag_handle", ImGui.vec2(size.x - 100, titleBarHeight));
        if (ImGui.isItemActive() && ImGui.isMouseDragging(ImGuiMouseButton.Left)) {
            if (!isDragging) {
                isDragging = true;
                dragStart = ImGui.getMousePos();
                windowPos = pos;
            }
            var delta = ImGui.getMouseDelta();
            windowPos.x += delta.x;
            windowPos.y += delta.y;
        }
        if (ImGui.isMouseReleased(ImGuiMouseButton.Left)) {
            isDragging = false;
        }
        
        // === DECORATIONS ===
        WindowDecorations.cornerAccents(drawList, rect, 
            ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.3, 0.5, 0.8, 0.5)));
    }
    
    function drawCloseButton(drawList:Dynamic, pos:ImVec2, size:Float):Void {
        var color = ImGui.isItemHovered() ? 0xFFFF4444 : 0x66FFFFFF;
        ImGui.ImDrawList_AddRectFilled(drawList, pos, 
            ImGui.vec2(pos.x + size, pos.y + size), color, 4);
        var pad = size * 0.25;
        ImGui.ImDrawList_AddLine(drawList,
            ImGui.vec2(pos.x + pad, pos.y + pad),
            ImGui.vec2(pos.x + size - pad, pos.y + size - pad),
            0xFFFFFFFF, 1.5);
        ImGui.ImDrawList_AddLine(drawList,
            ImGui.vec2(pos.x + size - pad, pos.y + pad),
            ImGui.vec2(pos.x + pad, pos.y + size - pad),
            0xFFFFFFFF, 1.5);
    }
    
    function drawMaximizeButton(drawList:Dynamic, pos:ImVec2, size:Float, maximized:Bool):Void {
        var color = ImGui.isItemHovered() ? 0x66FFFFFF : 0x44FFFFFF;
        var pad = size * 0.2;
        ImGui.ImDrawList_AddRect(drawList,
            ImGui.vec2(pos.x + pad, pos.y + pad),
            ImGui.vec2(pos.x + size - pad, pos.y + size - pad),
            color, 2);
        if (maximized) {
            var innerPad = size * 0.35;
            ImGui.ImDrawList_AddRect(drawList,
                ImGui.vec2(pos.x + innerPad, pos.y + innerPad),
                ImGui.vec2(pos.x + size - innerPad, pos.y + size - innerPad),
                color, 2);
        }
    }
    
    function drawMinimizeButton(drawList:Dynamic, pos:ImVec2, size:Float):Void {
        var color = ImGui.isItemHovered() ? 0x66FFFFFF : 0x44FFFFFF;
        var y = pos.y + size * 0.6;
        ImGui.ImDrawList_AddLine(drawList,
            ImGui.vec2(pos.x + size * 0.2, y),
            ImGui.vec2(pos.x + size * 0.8, y),
            color, 2);
    }
    
    function drawPinButton(drawList:Dynamic, pos:ImVec2, size:Float, pinned:Bool):Void {
        var color = pinned ? 0xFFFF8844 : 0x44FFFFFF;
        var cx = pos.x + size/2;
        var cy = pos.y + size/2;
        ImGui.ImDrawList_AddCircleFilled(drawList,
            ImGui.vec2(cx, cy),
            size * 0.25,
            color, 8);
        if (pinned) {
            ImGui.ImDrawList_AddCircleFilled(drawList,
                ImGui.vec2(cx, cy),
                size * 0.12,
                0xFFFFFFFF, 6);
        }
    }
}
```

---

### **9. Window Features Summary**

| Feature | Before | After |
|---------|--------|-------|
| **Title Bar** | Basic text | Custom icons, glow, animations, buttons |
| **Window Buttons** | Close only | Close, Minimize, Maximize, Pin |
| **Drag** | Standard | Custom drag handles |
| **Styling** | Limited | Full customization |
| **Text** | Plain | Glow, gradient, shadow, animated |
| **Decorations** | None | Corners, borders, patterns |
| **Pinning** | None | Keep window always on top |
| **Minimize** | None | Collapse to title bar |
| **Maximize** | None | Full screen |
| **Docking** | None | Full docking support |
| **Transparency** | None | Variable alpha |
| **Animations** | None | Pulsing, glowing, transitions |

