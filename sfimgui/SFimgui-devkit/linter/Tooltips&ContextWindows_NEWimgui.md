
---

## 💬 **TOOLTIPS - COMPLETE GUIDE**

### **1. Tooltip Features Overview**

| Feature | Function | Code Example | Use Case |
|---------|----------|--------------|----------|
| **Basic Tooltip** | Simple hover text | `ImGui.setTooltip()` | Quick help |
| **Rich Tooltip** | Formatted content | `ImGui.beginTooltip()` | Detailed info |
| **Item Tooltip** | Item-specific | `ImGui.beginItemTooltip()` | Contextual help |
| **Custom Tooltip** | Full control | `ImGui.beginTooltipEx()` | Complex tooltips |
| **Conditional Tooltip** | Show/hide | `ImGui.isItemHovered()` | Dynamic help |
| **Styled Tooltip** | Custom style | `ImGui.pushStyleColor()` | Branded tooltips |
| **Animated Tooltip** | Fade in/out | `ImGui.getTime()` | Smooth transitions |
| **Multi-line Tooltip** | Wrapped text | `ImGui.textWrapped()` | Long descriptions |
| **Tooltip with Icons** | Images/text | `ImGui.image()` | Visual help |
| **Tooltip with Tables** | Structured data | `ImGui.beginTable()` | Complex info |
| **Tooltip with Progress** | Status bars | `ImGui.progressBar()` | Loading states |
| **Tooltip with Buttons** | Interactive | `ImGui.button()` | Action tooltips |
| **Delay Tooltip** | Delayed show | `ImGuiHoveredFlags.DelayNormal` | Reduce clutter |
| **Tooltip Position** | Custom position | `ImGui.setNextWindowPos()` | Precise placement |

---

### **2. Basic & Rich Tooltips**

```haxe
// TooltipSystem.hx - Complete tooltip system
package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiHoveredFlags;
import imgui.Enums.ImGuiWindowFlags;
import imgui.Structs.ImVec2;
import imgui.Structs.ImVec4;

class TooltipSystem {
    
    // === BASIC TOOLTIP ===
    public static function basic(message:String):Void {
        if (ImGui.isItemHovered()) {
            ImGui.beginTooltip();
            ImGui.text(message);
            ImGui.endTooltip();
        }
    }
    
    // === RICH TOOLTIP ===
    public static function rich(content:Void->Void):Void {
        if (ImGui.isItemHovered()) {
            ImGui.beginTooltip();
            content();
            ImGui.endTooltip();
        }
    }
    
    // === DELAYED TOOLTIP ===
    public static function delayed(message:String, delay:Float = 0.3):Void {
        var flags = ImGuiHoveredFlags.DelayNormal | 
                   ImGuiHoveredFlags.NoSharedDelay;
        if (ImGui.isItemHovered(flags)) {
            ImGui.beginTooltip();
            ImGui.text(message);
            ImGui.endTooltip();
        }
    }
    
    // === CONDITIONAL TOOLTIP ===
    public static function conditional(condition:Bool, message:String):Void {
        if (condition && ImGui.isItemHovered()) {
            ImGui.beginTooltip();
            ImGui.text(message);
            ImGui.endTooltip();
        }
    }
    
    // === STYLED TOOLTIP ===
    public static function styled(message:String, bgColor:ImVec4, 
                                  textColor:ImVec4):Void {
        if (ImGui.isItemHovered()) {
            ImGui.pushStyleColor(ImGuiCol.PopupBg, bgColor);
            ImGui.pushStyleColor(ImGuiCol.Text, textColor);
            ImGui.beginTooltip();
            ImGui.text(message);
            ImGui.endTooltip();
            ImGui.popStyleColor(2);
        }
    }
    
    // === TOOLTIP WITH ICON ===
    public static function withIcon(icon:String, message:String):Void {
        if (ImGui.isItemHovered()) {
            ImGui.beginTooltip();
            ImGui.text(icon + " " + message);
            ImGui.endTooltip();
        }
    }
}
```

---

### **3. Advanced Tooltip Examples**

```haxe
// AdvancedTooltips.hx - Professional tooltips
package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiTableFlags;
import imgui.Structs.ImVec2;

class AdvancedTooltips {
    
    /**
     * Aura tooltip with full details
     */
    public static function auraTooltip(aura:AuraDef):Void {
        if (ImGui.isItemHovered()) {
            ImGui.beginTooltip();
            
            // Header
            ImGui.pushStyleColor(ImGuiCol.Text, ImGui.vec4(1, 0.8, 0.4, 1));
            ImGui.text(aura.name);
            ImGui.popStyleColor();
            
            ImGui.separator();
            
            // Details in columns
            ImGui.columns(2, "aura_tooltip", false);
            ImGui.text("Type:"); ImGui.nextColumn();
            ImGui.text(aura.region); ImGui.nextColumn();
            
            ImGui.text("Status:"); ImGui.nextColumn();
            var status = aura.enabled.get() ? "✅ Active" : "⏸️ Inactive";
            ImGui.text(status); ImGui.nextColumn();
            
            ImGui.text("Conditions:"); ImGui.nextColumn();
            ImGui.text(Std.string(aura.rule.conditions.length)); ImGui.nextColumn();
            
            ImGui.columns(1);
            
            // Description
            if (aura.announce != null && aura.announce.length > 0) {
                ImGui.separator();
                ImGui.textWrapped("Description: " + aura.announce);
            }
            
            ImGui.endTooltip();
        }
    }
    
    /**
     * Skill tooltip with cooldown info
     */
    public static function skillTooltip(skillId:String, skillName:String):Void {
        if (ImGui.isItemHovered()) {
            ImGui.beginTooltip();
            
            // Header with icon
            ImGui.pushStyleColor(ImGuiCol.Text, ImGui.vec4(0.4, 0.8, 1, 1));
            ImGui.text("⚔️ " + skillName);
            ImGui.popStyleColor();
            
            ImGui.separator();
            
            // Cooldown info
            var snap = GeauxCache.findSnap(skillId);
            if (snap != null) {
                ImGui.text("Cooldown: " + snap.cdMax + "s");
                ImGui.text("Status: " + (snap.ready ? "✅ Ready" : "⏳ Cooldown"));
                
                if (!snap.ready) {
                    var progress = snap.cdLeft / snap.cdMax;
                    ImGui.progressBar(1 - progress, ImGui.vec2(150, 0), 
                        Std.int(snap.cdLeft) + "s remaining");
                }
            } else {
                ImGui.textDisabled("No cooldown information");
            }
            
            ImGui.endTooltip();
        }
    }
    
    /**
     * Table cell tooltip with rich formatting
     */
    public static function tableCellTooltip(value:String, details:Array<{label:String, value:String}>):Void {
        if (ImGui.isItemHovered()) {
            ImGui.beginTooltip();
            
            ImGui.text(value);
            ImGui.separator();
            
            for (detail in details) {
                ImGui.text(detail.label + ": " + detail.value);
            }
            
            ImGui.endTooltip();
        }
    }
    
    /**
     * Multi-line tooltip with wrapped text
     */
    public static function wrapped(text:String, maxWidth:Float = 200):Void {
        if (ImGui.isItemHovered()) {
            ImGui.beginTooltip();
            ImGui.pushTextWrapPos(maxWidth);
            ImGui.textWrapped(text);
            ImGui.popTextWrapPos();
            ImGui.endTooltip();
        }
    }
}
```

---

### **4. Custom Tooltip Styling**

```haxe
// StyledTooltips.hx - Branded tooltips
package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiStyleVar;
import imgui.Structs.ImVec4;

class StyledTooltips {
    
    public static function applyTooltipStyle():Void {
        ImGui.pushStyleColor(ImGuiCol.PopupBg, ImGui.vec4(0.08, 0.09, 0.12, 0.95));
        ImGui.pushStyleColor(ImGuiCol.Border, ImGui.vec4(0.3, 0.5, 0.8, 0.5));
        ImGui.pushStyleColor(ImGuiCol.Text, ImGui.vec4(0.92, 0.94, 0.96, 1));
        ImGui.pushStyleColor(ImGuiCol.TextDisabled, ImGui.vec4(0.6, 0.62, 0.66, 1));
        ImGui.pushStyleVar(ImGuiStyleVar.WindowPadding, ImGui.vec2(8, 8));
        ImGui.pushStyleVar(ImGuiStyleVar.WindowRounding, 6);
        ImGui.pushStyleVar(ImGuiStyleVar.WindowBorderSize, 1);
    }
    
    public static function popTooltipStyle():Void {
        ImGui.popStyleVar(3);
        ImGui.popStyleColor(4);
    }
    
    /**
     * Tooltip with header and body styling
     */
    public static function styledTooltip(header:String, body:String, 
                                         headerColor:ImVec4 = null):Void {
        if (ImGui.isItemHovered()) {
            applyTooltipStyle();
            ImGui.beginTooltip();
            
            if (headerColor == null) headerColor = ImGui.vec4(1, 0.8, 0.4, 1);
            ImGui.pushStyleColor(ImGuiCol.Text, headerColor);
            ImGui.text(header);
            ImGui.popStyleColor();
            
            ImGui.separator();
            ImGui.textWrapped(body);
            
            ImGui.endTooltip();
            popTooltipStyle();
        }
    }
}
```

---

## 🪟 **CONTEXT WINDOWS - COMPLETE GUIDE**

### **5. Context Window Features**

| Feature | Function | Code Example | Use Case |
|---------|----------|--------------|----------|
| **Basic Context** | Right-click menu | `ImGui.openPopup()` | Actions |
| **Nested Context** | Sub-menus | `ImGui.beginMenu()` | Hierarchical |
| **Modal Context** | Blocking | `ImGui.beginPopupModal()` | Confirmation |
| **Conditional Context** | Dynamic items | `ImGui.menuItem(enabled)` | Context-aware |
| **Styled Context** | Custom look | `ImGui.pushStyleColor()` | Branded menus |
| **Animated Context** | Smooth show | `ImGui.beginPopup()` | Transitions |
| **Context with Icons** | Visual items | `ImGui.image()` | Icon menus |
| **Context with Shortcuts** | Key hints | `ImGui.menuItem("Save", "Ctrl+S")` | Power users |
| **Context Position** | Custom placement | `ImGui.setNextWindowPos()` | Precise menus |
| **Context Size** | Custom size | `ImGui.setNextWindowSize()` | Large menus |

---

### **6. Context Menu System**

```haxe
// ContextMenuSystem.hx - Complete context menu system
package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiMouseButton;
import imgui.Enums.ImGuiPopupFlags;
import imgui.Enums.ImGuiWindowFlags;
import imgui.Structs.ImVec2;

class ContextMenuSystem {
    static var menuStack:Array<String> = [];
    static var selectedItem:Int = -1;
    
    /**
     * Open a context menu on right-click
     */
    public static function openOnRightClick(id:String):Bool {
        if (ImGui.isItemClicked(ImGuiMouseButton.Right)) {
            ImGui.openPopup(id);
            return true;
        }
        return false;
    }
    
    /**
     * Begin a context menu
     */
    public static function begin(id:String):Bool {
        return ImGui.beginPopup(id, ImGuiWindowFlags.None);
    }
    
    /**
     * End a context menu
     */
    public static function end():Void {
        ImGui.endPopup();
    }
    
    /**
     * Draw a menu item with icon
     */
    public static function menuItem(label:String, shortcut:String = "", 
                                    icon:String = "", enabled:Bool = true):Bool {
        if (!enabled) ImGui.beginDisabled();
        
        var result = false;
        if (icon.length > 0) {
            ImGui.text(icon);
            ImGui.sameLine(0, 8);
            result = ImGui.menuItem(label, shortcut);
        } else {
            result = ImGui.menuItem(label, shortcut);
        }
        
        if (!enabled) ImGui.endDisabled();
        return result;
    }
    
    /**
     * Draw a separator with label
     */
    public static function separatorLabel(text:String):Void {
        ImGui.separator();
        ImGui.textColored(ImGui.vec4(0.6, 0.6, 0.7, 1), text);
        ImGui.separator();
    }
    
    /**
     * Nested menu item
     */
    public static function beginMenu(label:String, icon:String = ""):Bool {
        if (icon.length > 0) {
            ImGui.text(icon);
            ImGui.sameLine(0, 8);
        }
        return ImGui.beginMenu(label);
    }
    
    public static function endMenu():Void {
        ImGui.endMenu();
    }
}

// === USAGE EXAMPLE ===
class AuraContextMenu {
    public static function draw(index:Int, aura:AuraDef, 
                                onEdit:Void->Void, onDelete:Void->Void):Void {
        // Open on right-click
        if (ImGui.isItemClicked(ImGuiMouseButton.Right)) {
            ImGui.openPopup("aura_context_" + index);
        }
        
        // Draw context menu
        if (ImGui.beginPopup("aura_context_" + index)) {
            ContextMenuSystem.separatorLabel('✦ ${aura.name}');
            
            if (ContextMenuSystem.menuItem("✎ Edit", "Enter", "", aura.enabled.get())) {
                onEdit();
            }
            
            if (ContextMenuSystem.menuItem(
                aura.enabled.get() ? "⏸️ Disable" : "▶️ Enable", 
                "D", "", true
            )) {
                aura.enabled.set(!aura.enabled.get());
            }
            
            ImGui.separator();
            
            if (ContextMenuSystem.menuItem("📋 Duplicate", "Ctrl+D", "", true)) {
                // Duplicate logic
            }
            
            if (ContextMenuSystem.menuItem("📤 Export", "", "", true)) {
                // Export logic
            }
            
            ImGui.separator();
            
            if (ContextMenuSystem.menuItem("🗑️ Delete", "Del", "", true)) {
                onDelete();
            }
            
            ImGui.endPopup();
        }
    }
}
```

---

### **7. Modal Context Windows**

```haxe
// ModalWindows.hx - Complete modal window system
package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiWindowFlags;
import imgui.Structs.ImVec2;

class ModalWindows {
    
    /**
     * Confirmation dialog
     */
    public static function confirmDialog(title:String, message:String, 
                                         onConfirm:Void->Void, 
                                         onCancel:Void->Void):Bool {
        var result = false;
        ImGui.openPopup(title);
        
        if (ImGui.beginPopupModal(title, null, 
            ImGuiWindowFlags.AlwaysAutoResize)) {
            
            ImGui.textWrapped(message);
            ImGui.separator();
            
            if (ImGui.button("Yes", ImGui.vec2(80, 0))) {
                onConfirm();
                ImGui.closeCurrentPopup();
                result = true;
            }
            ImGui.sameLine();
            if (ImGui.button("No", ImGui.vec2(80, 0))) {
                onCancel();
                ImGui.closeCurrentPopup();
            }
            
            ImGui.endPopup();
        }
        
        return result;
    }
    
    /**
     * Input dialog
     */
    public static function inputDialog(title:String, message:String, 
                                       inputBuf:hl.Bytes, 
                                       onConfirm:Void->Void):Bool {
        var result = false;
        ImGui.openPopup(title);
        
        if (ImGui.beginPopupModal(title, null, 
            ImGuiWindowFlags.AlwaysAutoResize)) {
            
            ImGui.textWrapped(message);
            ImGui.inputText("##input", inputBuf, 256);
            ImGui.separator();
            
            if (ImGui.button("OK", ImGui.vec2(80, 0))) {
                onConfirm();
                ImGui.closeCurrentPopup();
                result = true;
            }
            ImGui.sameLine();
            if (ImGui.button("Cancel", ImGui.vec2(80, 0))) {
                ImGui.closeCurrentPopup();
            }
            
            ImGui.endPopup();
        }
        
        return result;
    }
    
    /**
     * Custom modal with content
     */
    public static function modal(title:String, content:Void->Void, 
                                 width:Float = 400, height:Float = 300):Bool {
        var result = false;
        ImGui.openPopup(title);
        
        ImGui.setNextWindowSize(ImGui.vec2(width, height), ImGuiCond.FirstUseEver);
        if (ImGui.beginPopupModal(title, null, 
            ImGuiWindowFlags.NoResize)) {
            
            content();
            
            ImGui.separator();
            if (ImGui.button("Close", ImGui.vec2(80, 0))) {
                ImGui.closeCurrentPopup();
                result = true;
            }
            
            ImGui.endPopup();
        }
        
        return result;
    }
}
```

---

### **8. Rich Context Menu Example**

```haxe
// RichContextMenu.hx - Full-featured context menu
package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiMouseButton;
import imgui.Structs.ImVec2;

class RichContextMenu {
    
    public static function drawAuraContext(index:Int, aura:AuraDef, 
                                           cfg:AuraConfig):Void {
        // Open on right-click
        if (ImGui.isItemClicked(ImGuiMouseButton.Right)) {
            ImGui.openPopup("aura_rich_context_" + index);
        }
        
        if (ImGui.beginPopup("aura_rich_context_" + index)) {
            // Header with aura info
            ImGui.pushStyleColor(ImGuiCol.Text, ImGui.vec4(1, 0.8, 0.4, 1));
            ImGui.text("✦ " + aura.name);
            ImGui.popStyleColor();
            
            ImGui.separator();
            
            // Status
            var status = aura.enabled.get() ? "✅ Enabled" : "⏸️ Disabled";
            ImGui.text("Status: " + status);
            
            // Type
            ImGui.text("Type: " + aura.region);
            
            ImGui.separator();
            
            // Quick actions
            if (ImGui.beginMenu("⚙️ Quick Actions")) {
                if (ImGui.menuItem(aura.enabled.get() ? "Disable" : "Enable")) {
                    aura.enabled.set(!aura.enabled.get());
                }
                if (ImGui.menuItem("Edit")) {
                    // Open editor
                }
                ImGui.endMenu();
            }
            
            // Copy options
            if (ImGui.beginMenu("📋 Copy")) {
                if (ImGui.menuItem("Copy JSON")) {
                    var json = haxe.Json.stringify(AuraEngine.toObj(aura));
                    ImGui.setClipboardText(json);
                }
                if (ImGui.menuItem("Copy Name")) {
                    ImGui.setClipboardText(aura.name);
                }
                if (ImGui.menuItem("Copy ID")) {
                    ImGui.setClipboardText(aura.id);
                }
                ImGui.endMenu();
            }
            
            // Advanced
            if (ImGui.beginMenu("🔧 Advanced")) {
                if (ImGui.menuItem("Export")) {
                    // Export logic
                }
                if (ImGui.menuItem("Duplicate")) {
                    // Duplicate logic
                }
                ImGui.separator();
                if (ImGui.menuItem("Delete", null, false, true)) {
                    // Delete logic
                }
                ImGui.endMenu();
            }
            
            ImGui.separator();
            
            // Help
            ImGui.textDisabled("Right-click for more options");
            
            ImGui.endPopup();
        }
    }
}
```

---

### **9. Tooltip + Context Integration**

```haxe
// IntegratedHover.hx - Tooltip + Context combined
package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiMouseButton;

class IntegratedHover {
    
    /**
     * Full hover interaction with tooltip and context
     */
    public static function interactive<T>(id:String, item:T, 
                                          tooltipContent:Void->Void,
                                          contextContent:Void->Void):Void {
        // Tooltip on hover
        if (ImGui.isItemHovered()) {
            ImGui.beginTooltip();
            tooltipContent();
            ImGui.endTooltip();
        }
        
        // Context on right-click
        if (ImGui.isItemClicked(ImGuiMouseButton.Right)) {
            ImGui.openPopup("context_" + id);
        }
        
        if (ImGui.beginPopup("context_" + id)) {
            contextContent();
            ImGui.endPopup();
        }
    }
}

// === USAGE EXAMPLE ===
class InteractiveAuraItem {
    public static function draw(aura:AuraDef, index:Int):Void {
        ImGui.pushID(index);
        
        // Draw aura item
        ImGui.text(aura.name);
        
        // Integrated hover
        IntegratedHover.interactive(
            "aura_" + aura.id,
            aura,
            function() {
                // Tooltip content
                ImGui.text(aura.name);
                ImGui.separator();
                ImGui.text("Type: " + aura.region);
                ImGui.text("Status: " + (aura.enabled.get() ? "Active" : "Inactive"));
            },
            function() {
                // Context menu content
                ContextMenuSystem.separatorLabel('✦ ${aura.name}');
                if (ContextMenuSystem.menuItem("Edit")) {
                    // Edit action
                }
                if (ContextMenuSystem.menuItem("Delete")) {
                    // Delete action
                }
            }
        );
        
        ImGui.popID();
    }
}
```

---

### **10. Tooltip & Context Styling**

```haxe
// TooltipStyling.hx - Complete styling
package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiStyleVar;
import imgui.Structs.ImVec4;

class TooltipStyling {
    
    public static function applyTooltipTheme():Void {
        // Tooltip colors
        ImGui.pushStyleColor(ImGuiCol.PopupBg, ImGui.vec4(0.08, 0.09, 0.12, 0.95));
        ImGui.pushStyleColor(ImGuiCol.Border, ImGui.vec4(0.3, 0.5, 0.8, 0.5));
        ImGui.pushStyleColor(ImGuiCol.Text, ImGui.vec4(0.92, 0.94, 0.96, 1));
        ImGui.pushStyleColor(ImGuiCol.TextDisabled, ImGui.vec4(0.6, 0.62, 0.66, 1));
        
        // Tooltip style vars
        ImGui.pushStyleVar(ImGuiStyleVar.WindowPadding, ImGui.vec2(8, 8));
        ImGui.pushStyleVar(ImGuiStyleVar.WindowRounding, 6);
        ImGui.pushStyleVar(ImGuiStyleVar.WindowBorderSize, 1);
        ImGui.pushStyleVar(ImGuiStyleVar.ItemSpacing, ImGui.vec2(4, 4));
    }
    
    public static function popTooltipTheme():Void {
        ImGui.popStyleVar(4);
        ImGui.popStyleColor(4);
    }
    
    public static function themedTooltip(content:Void->Void):Void {
        if (ImGui.isItemHovered()) {
            applyTooltipTheme();
            ImGui.beginTooltip();
            content();
            ImGui.endTooltip();
            popTooltipTheme();
        }
    }
}
```

---

## 📊 **FEATURES SUMMARY TABLE**

| Feature | Before | After | Use Case |
|---------|--------|-------|----------|
| **Tooltip Type** | Basic only | 8+ types | Rich info |
| **Tooltip Content** | Text only | Text, icons, tables, progress | Complex data |
| **Tooltip Style** | Default | Fully customizable | Branding |
| **Tooltip Delay** | None | Configurable delay | Reduced clutter |
| **Context Menu** | Basic | Nested, with icons, shortcuts | Power users |
| **Modal Windows** | Limited | Full modal system | Confirmations |
| **Position Control** | None | Full position control | Precise placement |
| **Animation** | None | Fade/transition effects | Smooth UX |
| **Conditional** | None | Dynamic content | Context-aware |
| **Integration** | Separate | Combined hover system | Seamless UX |

---

## 🎯 **Implementation Checklist**

| Feature | Your Mod Use | Priority |
|---------|--------------|----------|
| **Aura Tooltips** | Show aura details on hover | 🔴 High |
| **Skill Tooltips** | Show skill info/cooldown | 🔴 High |
| **Aura Context Menu** | Edit/delete/duplicate | 🔴 High |
| **Geaux Context Menu** | Assign/clear skills | 🟡 Medium |
| **Rich Tooltips** | Detailed info with tables | 🟡 Medium |
| **Modal Confirmations** | Delete confirmation | 🟡 Medium |
| **Conditional Tooltips** | Show/hide based on state | 🟢 Low |
| **Custom Styling** | Branded tooltips | 🟢 Low |
| **Delay Tooltips** | Reduce screen clutter | 🟢 Low |

---

## 🎯 **Complete Integration Example**

```haxe
// FullIntegration.hx - All features combined
package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiMouseButton;

class FullIntegration {
    
    public static function drawAuraItem(index:Int, aura:AuraDef, 
                                        cfg:AuraConfig):Void {
        ImGui.pushID(index);
        
        // Draw aura
        var color = aura.enabled.get() ? 0xFF44CC44 : 0xFF444444;
        ImGui.pushStyleColor(ImGuiCol.Text, color);
        ImGui.text(aura.name);
        ImGui.popStyleColor();
        
        // Tooltip on hover
        AdvancedTooltips.auraTooltip(aura);
        
        // Context on right-click
        RichContextMenu.drawAuraContext(index, aura, cfg);
        
        ImGui.popID();
    }
}
```

