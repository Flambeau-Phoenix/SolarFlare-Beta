
---

## 🔘 **NEW BUTTON CAPABILITIES**

### **1. Button Types & Variations**

| Button Type | Function | Code Example | Use Case |
|-------------|----------|--------------|----------|
| **Standard Button** | Normal clickable button | `ImGui.button("Click Me")` | Basic actions |
| **Small Button** | Compact version | `ImGui.smallButton("X")` | Close/minimize buttons |
| **Arrow Button** | Directional arrow | `ImGui.arrowButton("id", ImGuiDir.Left)` | Navigation |
| **Invisible Button** | Clickable invisible area | `ImGui.invisibleButton("id", size)` | Custom hitboxes, drag zones |
| **Image Button** | Button with image | `ImGui.imageButton(tex_id, size)` | Icon buttons, toolbar |
| **Color Button** | Color swatch button | `ImGui.colorButton("id", color)` | Color selection |
| **Radio Button** | Mutually exclusive selection | `ImGui.radioButton("Option", active)` | Settings |
| **Checkbox Button** | Toggle state | `ImGui.checkbox("Enable", enabled)` | Toggles |
| **Selectable Button** | List item selection | `ImGui.selectable("Item", selected)` | Lists, menus |
| **Menu Item** | Menu option | `ImGui.menuItem("Save", "Ctrl+S")` | Context menus |
| **Tab Item** | Tab button | `ImGui.tabItemButton("Tab")` | Tab bar actions |
| **Text Link** | Hyperlink-style button | `ImGui.textLink("Open URL")` | Links, help |
| **Arrow Button** | Direction indicator | `ImGui.arrowButton("id", dir)` | Collapse/expand |

---

### **2. Button Flags (New)**

```haxe
// All available button flags
enum ImGuiButtonFlags {
    None;                      // Default
    MouseButtonLeft;           // Left click
    MouseButtonRight;          // Right click
    MouseButtonMiddle;         // Middle click
    AllowOverlap;              // Allow overlapping other items
    EnableNav;                 // Enable keyboard navigation
    PressedOnClick;            // Trigger on click down
    PressedOnClickRelease;     // Trigger on click release (default)
    PressedOnClickReleaseAnywhere; // Trigger even if mouse leaves button
    PressedOnRelease;          // Trigger on mouse up
    PressedOnDoubleClick;      // Trigger on double click
    PressedOnDragDropHold;     // Trigger on drag-drop hold
    FlattenChildren;           // Flatten children for hit testing
    AlignTextBaseLine;         // Align text to baseline
    NoKeyModsAllowed;          // Ignore key modifiers (Ctrl, Shift, Alt)
    NoHoldingActiveId;         // Don't hold active ID
    NoNavFocus;                // Don't focus on nav
    NoHoveredOnFocus;          // Don't highlight on hover when focused
    NoSetKeyOwner;             // Don't set key owner
    NoTestKeyOwner;            // Don't test key owner
    NoFocus;                   // Prevent keyboard focus
}
```

---

### **3. New Button API**

```haxe
// === BASIC BUTTONS ===

// Standard button with custom size
ImGui.button("Label", ImGui.vec2(120, 30));

// Small button (auto-sized, compact)
ImGui.smallButton("X");

// Arrow button (directional)
ImGui.arrowButton("arrow_id", ImGuiDir.Right);

// Invisible button (clickable area only)
ImGui.invisibleButton("hitbox", ImGui.vec2(64, 64));

// === IMAGE BUTTONS ===
// Button with an image/icon
ImGui.imageButton(
    "id",           // Unique ID
    texture_id,     // ImTextureID
    ImGui.vec2(32, 32), // Size
    ImGui.vec2(0, 0),   // UV0
    ImGui.vec2(1, 1),   // UV1
    ImGui.vec4(0, 0, 0, 0), // Background color
    ImGui.vec4(1, 1, 1, 1)  // Tint color
);

// === COLOR BUTTON ===
ImGui.colorButton("color_id", color, ImGuiColorEditFlags.AlphaBar, ImGui.vec2(32, 32));

// === SELECTABLE ===
ImGui.selectable("Item", selected, ImGuiSelectableFlags.SpanAllColumns);

// === MENU ITEM ===
ImGui.menuItem("Save", "Ctrl+S", false, true);

// === TAB BUTTON ===
ImGui.tabItemButton("Tab Label", ImGuiTabItemFlags.None);

// === TEXT LINK ===
ImGui.textLink("Open Documentation");
```

---

### **4. New Button Styling & Effects**

```haxe
// === STACKED STYLING ===
// Push multiple style changes at once
ImGui.pushStyleColor(ImGuiCol.Button, ImGui.vec4(0.2, 0.4, 0.8, 1));
ImGui.pushStyleColor(ImGuiCol.ButtonHovered, ImGui.vec4(0.3, 0.5, 0.9, 1));
ImGui.pushStyleColor(ImGuiCol.ButtonActive, ImGui.vec4(0.1, 0.3, 0.7, 1));
ImGui.pushStyleVar(ImGuiStyleVar.FrameRounding, 8);
ImGui.pushStyleVar(ImGuiStyleVar.FramePadding, ImGui.vec2(8, 4));

ImGui.button("Styled Button");

ImGui.popStyleVar(2);
ImGui.popStyleColor(3);

// === DISABLED BUTTONS ===
ImGui.beginDisabled(!isEnabled);
if (ImGui.button("Disabled When False")) {
    // Action
}
ImGui.endDisabled();

// === BUTTON WITH KEYBOARD SHORTCUT ===
ImGui.setNextItemShortcut(ImGuiKey.S | ImGuiMod.Ctrl);
if (ImGui.button("Save (Ctrl+S)")) {
    save();
}

// === BUTTON WITH TOOLTIP ===
if (ImGui.button("Hover Me")) {
    // Action
}
if (ImGui.isItemHovered()) {
    ImGui.beginTooltip();
    ImGui.textWrapped("This button does something useful.");
    ImGui.endTooltip();
}
```

---

### **5. Advanced Button Behaviors**

```haxe
// === REPEAT BUTTON (Hold to repeat) ===
ImGui.pushItemFlag(ImGuiItemFlags.ButtonRepeat, true);
if (ImGui.button("Hold to Repeat")) {
    // This will fire repeatedly while held
}
ImGui.popItemFlag();

// === DOUBLE CLICK ===
if (ImGui.button("Double Click Me")) {
    // Single click
}
if (ImGui.isItemClicked(ImGuiMouseButton.Left) && ImGui.isMouseDoubleClicked(ImGuiMouseButton.Left)) {
    // Double click - custom behavior
}

// === RIGHT CLICK ===
if (ImGui.button("Right Click Me")) {
    // Left click
}
if (ImGui.isItemClicked(ImGuiMouseButton.Right)) {
    ImGui.openPopup("context_menu");
}

// === DRAG DROP SOURCE ===
if (ImGui.button("Drag Me")) {
    // Button click
}
if (ImGui.beginDragDropSource()) {
    ImGui.setDragDropPayload("ITEM_ID", data);
    ImGui.text("Dragging...");
    ImGui.endDragDropSource();
}

// === DRAG DROP TARGET ===
if (ImGui.beginDragDropTarget()) {
    var payload = ImGui.acceptDragDropPayload("ITEM_ID");
    if (payload != null) {
        // Handle drop
    }
    ImGui.endDragDropTarget();
}
```

---

### **6. Custom Button Rendering**

```haxe
// === CUSTOM BUTTON WITH GLOW ===
function drawGlowButton(label:String, color:Int, size:ImVec2):Bool {
    var pos = ImGui.getCursorScreenPos();
    var drawList = ImGui.getWindowDrawList();
    
    // Glow
    for (i in 0...5) {
        var t = i / 5;
        var alpha = 0.3 * (1 - t);
        var col = (color & 0x00FFFFFF) | (Std.int(alpha * 255) << 24);
        var offset = t * 8;
        ImGui.ImDrawList_AddRectFilled(drawList,
            ImGui.vec2(pos.x - offset, pos.y - offset),
            ImGui.vec2(pos.x + size.x + offset, pos.y + size.y + offset),
            col, 8);
    }
    
    // Button
    ImGui.pushStyleColor(ImGuiCol.Button, color);
    ImGui.pushStyleVar(ImGuiStyleVar.FrameRounding, 6);
    var result = ImGui.button(label, size);
    ImGui.popStyleVar();
    ImGui.popStyleColor();
    
    return result;
}

// === ANIMATED BUTTON ===
function drawAnimatedButton(label:String, phase:Float):Bool {
    var scale = 1 + 0.05 * Math.sin(phase);
    ImGui.pushStyleVar(ImGuiStyleVar.FramePadding, 
        ImGui.vec2(8 * scale, 4 * scale));
    var result = ImGui.button(label);
    ImGui.popStyleVar();
    return result;
}

// === GRADIENT BUTTON ===
function drawGradientButton(label:String):Bool {
    var pos = ImGui.getCursorScreenPos();
    var size = ImGui.vec2(120, 30);
    var drawList = ImGui.getWindowDrawList();
    var col1 = ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.2, 0.4, 0.8, 1));
    var col2 = ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.4, 0.6, 0.9, 1));
    
    // Draw gradient background
    ImGui.ImDrawList_AddRectFilledGradient(drawList,
        pos, ImGui.vec2(pos.x + size.x, pos.y + size.y),
        col1, col1, col2, col2);
    
    // Invisible button on top
    ImGui.setCursorScreenPos(pos);
    return ImGui.invisibleButton(label, size);
}
```

---

### **7. Button Keyboard Shortcuts**

```haxe
// === GLOBAL SHORTCUT ===
ImGui.shortcut(ImGuiKey.S | ImGuiMod.Ctrl);
if (ImGui.isKeyPressed(ImGuiKey.S, false) && ImGui.isKeyDown(ImGuiKey.LeftCtrl)) {
    save();
}

// === BUTTON-SPECIFIC SHORTCUT ===
ImGui.setNextItemShortcut(ImGuiKey.S | ImGuiMod.Ctrl);
if (ImGui.button("Save")) {
    save();
}

// === CUSTOM SHORTCUT HANDLING ===
if (ImGui.button("Custom Shortcut")) {
    ImGui.openPopup("shortcut_recorder");
}
if (ImGui.beginPopupModal("Record Shortcut")) {
    ImGui.text("Press any key...");
    // Capture key input
    ImGui.endPopup();
}
```

---

### **8. Button States & Queries**

```haxe
// === BUTTON STATE CHECKS ===
if (ImGui.button("Test")) {
    // Clicked
}

var isHovered = ImGui.isItemHovered();
var isActive = ImGui.isItemActive();
var isFocused = ImGui.isItemFocused();
var isClicked = ImGui.isItemClicked(ImGuiMouseButton.Left);
var isDoubleClicked = ImGui.isItemClicked() && ImGui.isMouseDoubleClicked();

// === BUTTON FLAGS ===
ImGui.buttonEx("Advanced", ImGui.vec2(0, 0), ImGuiButtonFlags.PressedOnDoubleClick);

// === GET BUTTON RECT ===
var min = ImGui.getItemRectMin();
var max = ImGui.getItemRectMax();
var size = ImGui.getItemRectSize();
```

---

### **9. Button Customization Properties**

| Property | Type | Description |
|----------|------|-------------|
| **FramePadding** | ImVec2 | Padding inside button |
| **FrameRounding** | Float | Corner rounding |
| **FrameBorderSize** | Float | Border thickness |
| **ButtonTextAlign** | ImVec2 | Text alignment (x, y) |
| **Colors** | ImVec4[3] | Button, Hovered, Active |
| **DisabledAlpha** | Float | Alpha when disabled |
| **ItemSpacing** | ImVec2 | Spacing between buttons |

---

### **10. Button Animation Effects**

| Effect | Method | Description |
|--------|--------|-------------|
| **Pulse** | `sin(time)` | Heartbeat effect |
| **Bounce** | `sin(time * speed) * amplitude` | Spring effect |
| **Glow** | Multiple circles with alpha | Soft glow around button |
| **Scale** | `1 + sin(time) * 0.05` | Grow/shrink |
| **Color Shift** | Lerp between colors | Smooth color transition |
| **Ripple** | Expanding circle on click | Ripple effect |
| **Slide** | Offset position | Slide in/out |
| **Fade** | Change alpha | Fade in/out |

---

## 🎯 **Practical Examples for Your Mod**

### **Example 1: Action Bar Button with Glow**

```haxe
function drawActionBarButton(skillId:String, isReady:Bool):Bool {
    var pos = ImGui.getCursorScreenPos();
    var size = ImGui.vec2(48, 48);
    
    // Glow when ready
    if (isReady) {
        var glow = 0.3 + 0.2 * Math.sin(ImGui.getTime() * 2);
        ImGui.ImDrawList_AddCircleFilled(ImGui.getWindowDrawList(),
            ImGui.vec2(pos.x + size.x/2, pos.y + size.y/2),
            size.x * 0.6,
            ImGui.colorConvertFloat4ToU32(ImGui.vec4(0, 1, 0, glow)), 16);
    }
    
    // Button
    ImGui.pushStyleColor(ImGuiCol.Button, isReady ? 0xFF44CC66 : 0xFF444444);
    ImGui.pushStyleVar(ImGuiStyleVar.FrameRounding, 6);
    var result = ImGui.invisibleButton(skillId, size);
    ImGui.popStyleVar();
    ImGui.popStyleColor();
    
    // Draw icon
    var tex = GameIcons.get(skillId);
    GameIcons.draw(ImGui.getWindowDrawList(), tex, pos.x + 4, pos.y + 4, 40);
    
    return result;
}
```

### **Example 2: Aura List with Checkbox Buttons**

```haxe
function drawAuraList(auras:Array<AuraDef>):Void {
    for (aura in auras) {
        ImGui.pushID(aura.id);
        
        // Checkbox button
        if (ImGui.checkbox("##enabled", aura.enabled)) {
            // Toggle aura
        }
        ImGui.sameLine();
        
        // Main button with aura name
        if (ImGui.button(aura.name, ImGui.vec2(150, 0))) {
            selectAura(aura);
        }
        ImGui.sameLine();
        
        // Small edit button
        if (ImGui.smallButton("✎")) {
            openEditor(aura);
        }
        ImGui.sameLine();
        if (ImGui.smallButton("✕")) {
            deleteAura(aura);
        }
        
        ImGui.popID();
    }
}
```

### **Example 3: Drag-Drop with Visual Feedback**

```haxe
function drawDraggableAuraSlot(index:Int, aura:AuraDef):Void {
    var pos = ImGui.getCursorScreenPos();
    var size = ImGui.vec2(60, 60);
    
    // Drop target highlight
    if (ImGui.isItemHovered() && ImGui.isDragDropActive()) {
        ImGui.pushStyleColor(ImGuiCol.Button, 0xFF44AA44);
    }
    
    // Invisible button as hitbox
    ImGui.invisibleButton("slot_" + index, size);
    
    if (ImGui.beginDragDropSource()) {
        // Drag payload
        var data = hl.Bytes.fromUTF8(Std.string(aura.id));
        ImGui.setDragDropPayload("AURA", data, data.length + 1);
        
        // Drag preview
        ImGui.text("Dragging: " + aura.name);
        
        ImGui.endDragDropSource();
    }
    
    if (ImGui.beginDragDropTarget()) {
        var payload = ImGui.acceptDragDropPayload("AURA");
        if (payload != null) {
            // Swap auras
            var droppedId = Std.parseInt(PayloadExt.getString(payload));
            swapAuras(index, droppedId);
        }
        ImGui.endDragDropTarget();
    }
    
    // Draw aura content
    // ...
    
    ImGui.popStyleColor();
}
```

---

## 📊 **Button Capabilities Summary**

| Capability | Before | After |
|------------|--------|-------|
| **Types** | 3 (Button, SmallButton, InvisibleButton) | 13+ types |
| **Styling** | Basic colors | Full style stack, gradients, custom rendering |
| **Flags** | 2-3 flags | 20+ flags for granular control |
| **Animations** | None | Full animation support (glow, pulse, bounce, etc.) |
| **Drag-Drop** | None | Full drag-drop source/target support |
| **Shortcuts** | None | Keyboard shortcuts per button |
| **Tooltips** | Basic | Enhanced tooltips with custom styling |
| **States** | Clicked | Hovered, Active, Focused, Clicked, Double-clicked |
| **Input** | Left click | Left, Right, Middle, Modifier keys |
| **Images** | None | Full image button support |
| **Customization** | Limited | Full custom rendering pipeline |

