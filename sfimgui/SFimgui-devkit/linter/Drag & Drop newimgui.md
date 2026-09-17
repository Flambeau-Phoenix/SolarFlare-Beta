
---

## 🖱️ **DRAG & DROP - COMPLETE GUIDE**

### **1. Drag & Drop Overview**

| Component | Function | Code Example | Use Case |
|-----------|----------|--------------|----------|
| **Drag Source** | Start dragging | `beginDragDropSource()` | Auras, skills, items |
| **Drag Payload** | Data being dragged | `setDragDropPayload()` | Transfer aura IDs |
| **Drag Target** | Accept drop | `beginDragDropTarget()` | Action bar slots |
| **Drop Accept** | Accept payload | `acceptDragDropPayload()` | Process dropped data |
| **Drag Flags** | Control behavior | `ImGuiDragDropFlags` | Customize drag |
| **Drag Preview** | Visual feedback | `ImGui.text()` | Show dragged item |
| **Drop Highlight** | Target feedback | `ImGui.pushStyleColor()` | Visual drop zones |

---

### **2. Core Drag & Drop API**

```haxe
// DragDropCore.hx - Complete drag & drop system
package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiDragDropFlags;
import imgui.Enums.ImGuiCol;
import imgui.Structs.ImGuiPayload;
import haxe.io.Bytes;

class DragDropCore {
    
    // === PAYLOAD TYPES ===
    public static inline var PAYLOAD_AURA = "AURA_DATA";
    public static inline var PAYLOAD_SKILL = "SKILL_DATA";
    public static inline var PAYLOAD_ICON = "ICON_DATA";
    public static inline var PAYLOAD_TEXT = "TEXT_DATA";
    public static inline var PAYLOAD_ACTION = "ACTION_DATA";
    
    /**
     * Start a drag source with payload
     */
    public static function beginDragSource(payloadType:String, data:Dynamic, 
                                           ?previewText:String, 
                                           flags:Int = 0):Bool {
        if (!ImGui.beginDragDropSource(flags)) return false;
        
        // Convert data to bytes
        var bytes = payloadToBytes(data);
        ImGui.setDragDropPayload(payloadType, bytes, bytes.length + 1);
        
        // Preview
        if (previewText != null) {
            ImGui.text(previewText);
        } else {
            ImGui.text("Dragging...");
        }
        
        return true;
    }
    
    public static function endDragSource():Void {
        ImGui.endDragDropSource();
    }
    
    /**
     * Accept a drop on a target
     */
    public static function acceptDrop(payloadType:String, 
                                      flags:Int = 0):Null<Dynamic> {
        if (!ImGui.beginDragDropTarget()) return null;
        
        var payload = ImGui.acceptDragDropPayload(payloadType, flags);
        if (payload != null && ImGui.ImGuiPayload_IsDataType(payload, payloadType)) {
            var data = payloadToData(payload);
            ImGui.endDragDropTarget();
            return data;
        }
        
        ImGui.endDragDropTarget();
        return null;
    }
    
    /**
     * Check if a drag is currently active
     */
    public static function isDragging():Bool {
        return ImGui.isDragDropActive();
    }
    
    /**
     * Get the current payload (for custom drop handling)
     */
    public static function getCurrentPayload():Null<ImGuiPayload> {
        return ImGui.getDragDropPayload();
    }
    
    // === HELPERS ===
    
    static function payloadToBytes(data:Dynamic):hl.Bytes {
        if (Std.is(data, Int)) {
            return hl.Bytes.fromUTF8(Std.string(data));
        } else if (Std.is(data, String)) {
            return hl.Bytes.fromUTF8(data);
        } else if (Std.is(data, Float)) {
            return hl.Bytes.fromUTF8(Std.string(data));
        } else if (Std.is(data, Bool)) {
            return hl.Bytes.fromUTF8(data ? "true" : "false");
        } else {
            // JSON serialize complex objects
            try {
                var json = haxe.Json.stringify(data);
                return hl.Bytes.fromUTF8(json);
            } catch (e:Dynamic) {
                return hl.Bytes.fromUTF8(Std.string(data));
            }
        }
    }
    
    static function payloadToData(payload:ImGuiPayload):Dynamic {
        if (payload == null || payload.Data == null) return null;
        var bytes = payload.Data;
        var str = Bytes.ofData(bytes).getString(0, payload.DataSize);
        
        // Try parsing as JSON first
        try {
            return haxe.Json.parse(str);
        } catch (e:Dynamic) {}
        
        // Then try as number
        try {
            var num = Std.parseFloat(str);
            if (!Math.isNaN(num)) return num;
        } catch (e:Dynamic) {}
        
        // Return as string
        return str;
    }
}

// === DRAG FLAGS ===
enum DragFlags {
    None;                      // Default
    SourceNoPreviewTooltip;    // No preview tooltip
    SourceNoDisableHover;      // Don't disable hover
    SourceNoHoldToOpenOthers;  // Don't hold to open
    SourceAllowNullID;         // Allow null ID
    SourceExtern;              // External source
    PayloadAutoExpire;         // Auto-expire payload
    PayloadNoCrossContext;     // No cross-context
    PayloadNoCrossProcess;     // No cross-process
    AcceptBeforeDelivery;      // Accept before delivery
    AcceptNoDrawDefaultRect;   // No default rect
    AcceptNoPreviewTooltip;    // No preview tooltip
    AcceptDrawAsHovered;       // Draw as hovered
}
```

---

### **3. Aura Drag & Drop System**

```haxe
// AuraDragDrop.hx - Complete aura drag & drop
package solarflare.aura;

import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Structs.ImVec2;
import solarflare.ui.DragDropCore;

class AuraDragDrop {
    
    /**
     * Drag an aura from the library
     */
    public static function dragAura(aura:AuraDef, previewSize:Float = 64):Bool {
        var result = DragDropCore.beginDragSource(
            DragDropCore.PAYLOAD_AURA,
            {id: aura.id, name: aura.name, type: aura.region},
            "Dragging: " + aura.name
        );
        
        if (result) {
            // Custom preview with aura visual
            var pos = ImGui.getCursorScreenPos();
            var drawList = ImGui.getWindowDrawList();
            
            // Preview background
            ImGui.ImDrawList_AddRectFilled(drawList,
                pos,
                ImGui.vec2(pos.x + previewSize, pos.y + previewSize),
                0xCC1A1A2E, 4);
            
            // Aura preview
            AuraVisualRenderer.draw(drawList, aura,
                pos.x, pos.y, previewSize, previewSize,
                0.5, 1, 0, true);
            
            // Aura name
            ImGui.text(aura.name);
            
            DragDropCore.endDragSource();
            return true;
        }
        
        return false;
    }
    
    /**
     * Drop an aura onto a slot
     */
    public static function dropAuraSlot(slotIndex:Int, 
                                        onDrop:Int->String->Void):Bool {
        var data = DragDropCore.acceptDrop(DragDropCore.PAYLOAD_AURA);
        if (data != null) {
            var auraId = Std.string(data.id);
            if (auraId != null && auraId.length > 0) {
                onDrop(slotIndex, auraId);
                return true;
            }
        }
        return false;
    }
    
    /**
     * Drop zone with visual feedback
     */
    public static function dropZone(slotIndex:Int, size:ImVec2, 
                                    onDrop:Int->String->Void):Bool {
        var pos = ImGui.getCursorScreenPos();
        var isHovered = false;
        var isTarget = false;
        
        // Draw drop zone
        var color = 0x44000000;
        if (ImGui.isDragDropActive()) {
            color = 0x44FFCC44;
            isTarget = true;
        }
        ImGui.ImDrawList_AddRectFilled(ImGui.getWindowDrawList(),
            pos,
            ImGui.vec2(pos.x + size.x, pos.y + size.y),
            color, 4);
        
        // Border highlight
        if (isTarget) {
            ImGui.ImDrawList_AddRect(ImGui.getWindowDrawList(),
                pos,
                ImGui.vec2(pos.x + size.x, pos.y + size.y),
                0xFFFFFFFF, 4, 2);
        }
        
        // Invisible button for drop target
        ImGui.invisibleButton("drop_zone_" + slotIndex, size);
        isHovered = ImGui.isItemHovered();
        
        // Accept drop
        if (isHovered && DragDropCore.isDragging()) {
            var data = DragDropCore.acceptDrop(DragDropCore.PAYLOAD_AURA);
            if (data != null) {
                var auraId = Std.string(data.id);
                if (auraId != null && auraId.length > 0) {
                    onDrop(slotIndex, auraId);
                    return true;
                }
            }
        }
        
        return false;
    }
    
    /**
     * Drop zone with aura preview
     */
    public static function dropZoneWithPreview(slotIndex:Int, size:ImVec2,
                                               currentAura:AuraDef,
                                               onDrop:Int->String->Void):Bool {
        var pos = ImGui.getCursorScreenPos();
        var drawList = ImGui.getWindowDrawList();
        var isHovered = false;
        var isTarget = false;
        
        // Draw zone background
        var color = 0x44000000;
        if (ImGui.isDragDropActive()) {
            color = 0x44FFCC44;
            isTarget = true;
        }
        ImGui.ImDrawList_AddRectFilled(drawList,
            pos,
            ImGui.vec2(pos.x + size.x, pos.y + size.y),
            color, 4);
        
        // Draw current aura if present
        if (currentAura != null) {
            AuraVisualRenderer.draw(drawList, currentAura,
                pos.x + 4, pos.y + 4,
                size.x - 8, size.y - 8,
                1, 1, 0, false);
        }
        
        // Drop target
        ImGui.invisibleButton("drop_preview_" + slotIndex, size);
        isHovered = ImGui.isItemHovered();
        
        // Accept drop
        if (isHovered && DragDropCore.isDragging()) {
            var data = DragDropCore.acceptDrop(DragDropCore.PAYLOAD_AURA);
            if (data != null) {
                var auraId = Std.string(data.id);
                if (auraId != null && auraId.length > 0) {
                    onDrop(slotIndex, auraId);
                    return true;
                }
            }
        }
        
        return false;
    }
}
```

---

### **4. Skill & Action Bar Drag & Drop**

```haxe
// SkillDragDrop.hx - Skill/action bar drag & drop
package solarflare.skill;

import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Structs.ImVec2;
import solarflare.ui.DragDropCore;

class SkillDragDrop {
    
    /**
     * Drag a skill from the catalog
     */
    public static function dragSkill(skillId:String, skillName:String, 
                                     iconId:String = ""):Bool {
        var result = DragDropCore.beginDragSource(
            DragDropCore.PAYLOAD_SKILL,
            {id: skillId, name: skillName, icon: iconId},
            "Dragging: " + skillName
        );
        
        if (result) {
            // Skill preview
            var pos = ImGui.getCursorScreenPos();
            var drawList = ImGui.getWindowDrawList();
            
            // Icon
            if (iconId.length > 0) {
                var tex = GameIcons.get(iconId);
                GameIcons.draw(drawList, tex, pos.x, pos.y, 32);
            }
            
            // Name
            ImGui.sameLine();
            ImGui.text(skillName);
            
            DragDropCore.endDragSource();
            return true;
        }
        
        return false;
    }
    
    /**
     * Drop a skill onto an action bar slot
     */
    public static function dropSkillSlot(slotIndex:Int, 
                                         onDrop:Int->String->Void):Bool {
        var data = DragDropCore.acceptDrop(DragDropCore.PAYLOAD_SKILL);
        if (data != null) {
            var skillId = Std.string(data.id);
            if (skillId != null && skillId.length > 0) {
                onDrop(slotIndex, skillId);
                return true;
            }
        }
        return false;
    }
    
    /**
     * Swap two slots via drag & drop
     */
    public static function swapSlots(slotIndex:Int, currentId:String,
                                     onSwap:Int->Int->Void):Bool {
        // Source: drag out
        if (ImGui.beginDragDropSource()) {
            var data = hl.Bytes.fromUTF8(currentId);
            ImGui.setDragDropPayload("SLOT_SWAP", data, data.length + 1);
            ImGui.text("Swapping: " + currentId);
            ImGui.endDragDropSource();
            return true;
        }
        
        // Target: accept swap
        if (ImGui.beginDragDropTarget()) {
            var payload = ImGui.acceptDragDropPayload("SLOT_SWAP");
            if (payload != null && ImGui.ImGuiPayload_IsDataType(payload, "SLOT_SWAP")) {
                var bytes = payload.Data;
                var data = haxe.io.Bytes.ofData(bytes);
                var sourceId = data.getString(0, payload.DataSize);
                if (sourceId.length > 0) {
                    onSwap(slotIndex, Std.parseInt(sourceId));
                    ImGui.endDragDropTarget();
                    return true;
                }
            }
            ImGui.endDragDropTarget();
        }
        
        return false;
    }
}
```

---

### **5. Reorderable Lists (Full Implementation)**

```haxe
// ReorderableList.hx - Complete reorderable list
package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Structs.ImVec2;
import solarflare.ui.DragDropCore;

class ReorderableList<T> {
    public var items:Array<T>;
    public var renderItem:T->Void;
    public var itemId:T->String;
    public var draggable:Bool = true;
    public var dropHighlight:Int = -1;
    
    var dragSourceIndex:Int = -1;
    
    public function new(items:Array<T>, renderItem:T->Void, itemId:T->String) {
        this.items = items;
        this.renderItem = renderItem;
        this.itemId = itemId;
    }
    
    public function draw():Void {
        if (items == null || items.length == 0) {
            ImGui.textDisabled("No items");
            return;
        }
        
        for (i in 0...items.length) {
            ImGui.pushID(i);
            
            var item = items[i];
            var id = itemId(item);
            
            // === DRAG HANDLE ===
            if (draggable) {
                // Draw drag handle
                var handlePos = ImGui.getCursorScreenPos();
                var handleSize = 16;
                ImGui.ImDrawList_AddText_Vec2(ImGui.getWindowDrawList(),
                    ImGui.vec2(handlePos.x + 2, handlePos.y + 2),
                    0x66FFFFFF, "☰");
                
                ImGui.invisibleButton("##drag_handle_" + id, ImGui.vec2(handleSize, handleSize));
                
                // Start drag source
                if (ImGui.isItemActive() && ImGui.isMouseDragging(0)) {
                    if (ImGui.beginDragDropSource()) {
                        // Store the index being dragged
                        var data = hl.Bytes.fromUTF8(Std.string(i));
                        ImGui.setDragDropPayload("LIST_REORDER", data, data.length + 1);
                        ImGui.text("Moving: " + id);
                        ImGui.endDragDropSource();
                        dragSourceIndex = i;
                    }
                }
                
                ImGui.sameLine(0, 4);
            }
            
            // === ITEM CONTENT ===
            // Highlight drop target
            if (dropHighlight == i) {
                ImGui.pushStyleColor(ImGuiCol.ChildBg, 0x22FFCC44);
            }
            
            // Render item
            renderItem(item);
            
            if (dropHighlight == i) {
                ImGui.popStyleColor();
                dropHighlight = -1;
            }
            
            // === DROP TARGET ===
            if (draggable && ImGui.beginDragDropTarget()) {
                var payload = ImGui.acceptDragDropPayload("LIST_REORDER");
                if (payload != null && ImGui.ImGuiPayload_IsDataType(payload, "LIST_REORDER")) {
                    var bytes = payload.Data;
                    var data = haxe.io.Bytes.ofData(bytes);
                    var sourceIndex = Std.parseInt(data.getString(0, payload.DataSize));
                    if (sourceIndex != null && sourceIndex != i) {
                        // Reorder items
                        var sourceItem = items[sourceIndex];
                        items.remove(sourceItem);
                        if (sourceIndex < i) i--;
                        items.insert(i, sourceItem);
                        dragSourceIndex = -1;
                    }
                }
                ImGui.endDragDropTarget();
            }
            
            ImGui.popID();
        }
    }
}

// === USAGE EXAMPLE ===
class AuraReorderableList {
    var list:ReorderableList<AuraDef>;
    
    public function new(auras:Array<AuraDef>) {
        list = new ReorderableList(
            auras,
            function(aura:AuraDef) {
                ImGui.text(aura.name);
                ImGui.sameLine();
                ImGui.textDisabled(aura.type);
            },
            function(aura:AuraDef) return aura.id
        );
    }
    
    public function draw():Void {
        list.draw();
    }
}
```

---

### **6. Visual Drag Feedback**

```haxe
// DragFeedback.hx - Visual feedback for drag & drop
package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Structs.ImVec2;

class DragFeedback {
    
    /**
     * Draw drop zone highlight
     */
    public static function dropZoneHighlight(drawList:Dynamic, pos:ImVec2, 
                                             size:ImVec2, color:Int):Void {
        // Glow border
        for (i in 0...4) {
            var t = i / 4;
            var alpha = Std.int((1 - t) * 0.3 * 255);
            var col = (color & 0x00FFFFFF) | (alpha << 24);
            var offset = t * 6;
            ImGui.ImDrawList_AddRect(drawList,
                ImGui.vec2(pos.x - offset, pos.y - offset),
                ImGui.vec2(pos.x + size.x + offset, pos.y + size.y + offset),
                col, 6, 0, 2 - t);
        }
        
        // Pulsing inner glow
        var pulse = 0.5 + 0.5 * Math.sin(ImGui.getTime() * 2);
        var alpha = Std.int(0.1 + 0.2 * pulse * 255);
        var col = (color & 0x00FFFFFF) | (alpha << 24);
        ImGui.ImDrawList_AddRectFilled(drawList,
            ImGui.vec2(pos.x + 4, pos.y + 4),
            ImGui.vec2(pos.x + size.x - 4, pos.y + size.y - 4),
            col, 4);
    }
    
    /**
     * Draw drag source ghost (while dragging)
     */
    public static function dragGhost(drawList:Dynamic, pos:ImVec2, 
                                     size:ImVec2, content:Void->Void):Void {
        // Ghost background
        ImGui.ImDrawList_AddRectFilled(drawList,
            pos,
            ImGui.vec2(pos.x + size.x, pos.y + size.y),
            0xCC1A1A2E, 4);
        
        // Border
        ImGui.ImDrawList_AddRect(drawList,
            pos,
            ImGui.vec2(pos.x + size.x, pos.y + size.y),
            0x44FFFFFF, 4, 1);
        
        // Shadow
        ImGui.ImDrawList_AddRectFilled(drawList,
            ImGui.vec2(pos.x + 4, pos.y + 4),
            ImGui.vec2(pos.x + size.x + 4, pos.y + size.y + 4),
            0x22000000, 4);
        
        // Content
        ImGui.setCursorScreenPos(ImGui.vec2(pos.x + 4, pos.y + 4));
        content();
    }
    
    /**
     * Draw drop indicator line (for between items)
     */
    public static function dropLine(drawList:Dynamic, pos:ImVec2, 
                                    width:Float, color:Int):Void {
        var pulse = 0.5 + 0.5 * Math.sin(ImGui.getTime() * 2);
        var alpha = Std.int((0.5 + 0.5 * pulse) * 255);
        var col = (color & 0x00FFFFFF) | (alpha << 24);
        
        // Main line
        ImGui.ImDrawList_AddLine(drawList,
            pos,
            ImGui.vec2(pos.x + width, pos.y),
            col, 2);
        
        // Glow line
        var glowCol = (color & 0x00FFFFFF) | (Std.int(alpha * 0.3) << 24);
        ImGui.ImDrawList_AddLine(drawList,
            ImGui.vec2(pos.x, pos.y - 2),
            ImGui.vec2(pos.x + width, pos.y - 2),
            glowCol, 4);
    }
}
```

---

### **7. Cross-Window Drag & Drop**

```haxe
// CrossWindowDrag.hx - Drag between windows
package solarflare.ui;

import imgui.ImGui;
import imgui.Structs.ImVec2;
import solarflare.ui.DragDropCore;

class CrossWindowDrag {
    
    /**
     * Drag between two different windows
     * Uses the global payload system
     */
    public static function crossWindowDrag():Void {
        // Window A: Source
        if (ImGui.begin("Aura Library")) {
            for (aura in auras) {
                // Drag source
                if (ImGui.button(aura.name)) {
                    // Click selection
                }
                
                if (ImGui.beginDragDropSource()) {
                    var data = hl.Bytes.fromUTF8(aura.id);
                    ImGui.setDragDropPayload("CROSS_AURA", data, data.length + 1);
                    ImGui.text("Moving: " + aura.name);
                    ImGui.endDragDropSource();
                }
            }
        }
        ImGui.end();
        
        // Window B: Target
        if (ImGui.begin("Action Bar")) {
            for (slot in 0...10) {
                // Drop target
                if (ImGui.beginDragDropTarget()) {
                    var payload = ImGui.acceptDragDropPayload("CROSS_AURA");
                    if (payload != null && ImGui.ImGuiPayload_IsDataType(payload, "CROSS_AURA")) {
                        var bytes = payload.Data;
                        var data = haxe.io.Bytes.ofData(bytes);
                        var auraId = data.getString(0, payload.DataSize);
                        // Assign aura to slot
                        assignAuraToSlot(slot, auraId);
                    }
                    ImGui.endDragDropTarget();
                }
            }
        }
        ImGui.end();
    }
}
```

---

### **8. Drag & Drop Flags & Customization**

```haxe
// DragFlagsDemo.hx - All drag flags demonstrated
package solarflare.ui;

class DragFlagsDemo {
    
    public static function draw():Void {
        // === BASIC DRAG ===
        if (ImGui.beginDragDropSource(0)) {
            // Default behavior
            ImGui.setDragDropPayload("TYPE", data, size);
            ImGui.text("Dragging...");
            ImGui.endDragDropSource();
        }
        
        // === NO PREVIEW TOOLTIP ===
        if (ImGui.beginDragDropSource(ImGuiDragDropFlags.SourceNoPreviewTooltip)) {
            ImGui.setDragDropPayload("TYPE", data, size);
            ImGui.text("No preview tooltip");
            ImGui.endDragDropSource();
        }
        
        // === EXTERNAL SOURCE ===
        if (ImGui.beginDragDropSource(ImGuiDragDropFlags.SourceExtern)) {
            ImGui.setDragDropPayload("TYPE", data, size);
            ImGui.text("External source");
            ImGui.endDragDropSource();
        }
        
        // === AUTO-EXPIRE PAYLOAD ===
        if (ImGui.beginDragDropTarget()) {
            var payload = ImGui.acceptDragDropPayload("TYPE", 
                ImGuiDragDropFlags.PayloadAutoExpire);
            if (payload != null) {
                // Payload auto-expires after drop
            }
            ImGui.endDragDropTarget();
        }
        
        // === ACCEPT BEFORE DELIVERY ===
        if (ImGui.beginDragDropTarget()) {
            var payload = ImGui.acceptDragDropPayload("TYPE",
                ImGuiDragDropFlags.AcceptBeforeDelivery);
            if (payload != null) {
                // Accept before delivery (preview)
            }
            ImGui.endDragDropTarget();
        }
        
        // === CUSTOM DROP RECT ===
        if (ImGui.beginDragDropTarget()) {
            var payload = ImGui.acceptDragDropPayload("TYPE",
                ImGuiDragDropFlags.AcceptNoDrawDefaultRect);
            if (payload != null) {
                // Draw custom drop rect
                var pos = ImGui.getCursorScreenPos();
                var size = ImGui.getContentRegionAvail();
                ImGui.ImDrawList_AddRect(drawList, pos, 
                    ImGui.vec2(pos.x + size.x, pos.y + size.y),
                    0xFFFF4444, 4, 2);
            }
            ImGui.endDragDropTarget();
        }
    }
}
```

---

### **9. Drag & Drop Features Summary**

| Feature | Before | After |
|---------|--------|-------|
| **Drag Source** | None | Full drag support with custom preview |
| **Drop Target** | None | Full drop support with visual feedback |
| **Payload Types** | None | Multiple payload types |
| **Cross-Window** | None | Drag between windows |
| **Reorderable** | None | Drag to reorder lists |
| **Visual Feedback** | None | Glow, highlight, ghost, line |
| **Flags** | None | 10+ drag flags |
| **Data Types** | None | Any data (Int, String, Object) |
| **Preview** | None | Custom drag preview |
| **Conditional** | None | Conditional drop acceptance |

---

### **10. Complete Example: Geaux Builder with Drag & Drop**

```haxe
// GeauxBuilderDragDrop.hx - Complete integration
package solarflare.geaux;

import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Structs.ImVec2;
import solarflare.ui.DragDropCore;
import solarflare.ui.DragFeedback;

class GeauxBuilderDragDrop {
    
    public function draw(cfg:GeauxConfig, skills:Array<Skill>):Void {
        // === SKILL CATALOG (Source) ===
        ImGui.separatorText("Skill Catalog");
        ImGui.beginChild("catalog", ImGui.vec2(200, 0));
        
        for (skill in skills) {
            // Each skill is a drag source
            if (ImGui.selectable(skill.name, false)) {
                // Click selection
            }
            
            // Drag source
            if (ImGui.beginDragDropSource()) {
                var data = hl.Bytes.fromUTF8(skill.id);
                ImGui.setDragDropPayload("SKILL_TO_GRID", data, data.length + 1);
                ImGui.text("Dragging: " + skill.name);
                ImGui.endDragDropSource();
            }
        }
        
        ImGui.endChild();
        
        ImGui.sameLine();
        
        // === GRID (Target) ===
        ImGui.separatorText("Grid");
        ImGui.beginChild("grid", ImGui.vec2(0, 0));
        
        var rows = cfg.rows.get();
        var cols = cfg.cols.get();
        var gap = 4;
        var cellSize = 48;
        var totalW = cols * (cellSize + gap) - gap;
        var totalH = rows * (cellSize + gap) - gap;
        
        for (r in 0...rows) {
            for (c in 0...cols) {
                var idx = r * cols + c;
                var x = ImGui.getCursorScreenPos().x + c * (cellSize + gap);
                var y = ImGui.getCursorScreenPos().y + r * (cellSize + gap);
                
                // Cell background
                var color = 0x44000000;
                if (DragDropCore.isDragging()) {
                    color = 0x44FFCC44;
                }
                ImGui.ImDrawList_AddRectFilled(ImGui.getWindowDrawList(),
                    ImGui.vec2(x, y),
                    ImGui.vec2(x + cellSize, y + cellSize),
                    color, 4);
                
                // Drop target
                ImGui.setCursorScreenPos(ImGui.vec2(x, y));
                ImGui.invisibleButton("cell_" + idx, ImGui.vec2(cellSize, cellSize));
                
                if (ImGui.isItemHovered() && DragDropCore.isDragging()) {
                    DragFeedback.dropZoneHighlight(ImGui.getWindowDrawList(),
                        ImGui.vec2(x, y),
                        ImGui.vec2(cellSize, cellSize),
                        0xFFFFCC44);
                }
                
                // Accept drop
                if (ImGui.beginDragDropTarget()) {
                    var payload = ImGui.acceptDragDropPayload("SKILL_TO_GRID");
                    if (payload != null && ImGui.ImGuiPayload_IsDataType(payload, "SKILL_TO_GRID")) {
                        var bytes = payload.Data;
                        var data = haxe.io.Bytes.ofData(bytes);
                        var skillId = data.getString(0, payload.DataSize);
                        cfg.assignCell(idx, skillId);
                    }
                    ImGui.endDragDropTarget();
                }
                
                // Draw assigned skill
                var skillId = cfg.slotIds[idx];
                if (skillId.length > 0) {
                    // Draw skill icon
                    var tex = GameIcons.get(skillId);
                    GameIcons.draw(ImGui.getWindowDrawList(), tex, x + 4, y + 4, cellSize - 8);
                }
            }
        }
        
        // Reserve space
        ImGui.dummy(ImGui.vec2(totalW, totalH));
        ImGui.endChild();
    }
}
```

---

## 🎯 **Drag & Drop Summary**

| Feature | Your Mod Use |
|---------|--------------|
| **Aura Library** | Drag auras to action bar slots |
| **Skill Catalog** | Drag skills to Geaux grid cells |
| **Reorderable Lists** | Reorder aura priority |
| **Cross-Window** | Drag between windows |
| **Visual Feedback** | Drop zone highlighting |
| **Custom Preview** | Aura preview while dragging |
| **Conditional Drop** | Only accept valid drops |
| **Swap Slots** | Drag to swap positions |

