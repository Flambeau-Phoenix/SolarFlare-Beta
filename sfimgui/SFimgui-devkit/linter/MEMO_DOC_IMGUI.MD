# SolarFlare ImGui Docking Branch - Agent Memory Knowledge Base

## 📋 **DOCUMENT ID**: SF-IMGUI-DOCKING-V2  
## 📅 **LAST UPDATED**: 2026-08-29  
## 🏷️ **TAGS**: `imgui`, `docking`, `ui`, `modding`, `hlx`, `hashlink`, `solarflare`

---

## 🎯 **EXECUTIVE SUMMARY**

SolarFlare has been upgraded to use the **Dear ImGui Docking Branch** (v1.92.9+). This upgrade enables professional-grade UI features including docking, drag-and-drop, advanced tables, multi-select, rich text input, custom fonts, plots, shortcuts, color pickers, tooltips, context menus, toast notifications, full styling, and performance optimization. All features are implemented in Haxe targeting HashLink via the HLX framework.

---

## 📦 **CORE UPGRADE INFORMATION**

### What Changed
| Before | After |
|--------|-------|
| Standard ImGui (master branch) | ImGui Docking Branch (v1.92.9+) |
| Basic UI components | Professional-grade UI toolkit |
| Fixed window layout | Full docking workspace |
| No drag-and-drop | Complete drag-drop system |
| Basic tables | Advanced sortable tables |
| Single selection | Multi-select with range/box selection |

### Key Version Information
- **ImGui Version**: 1.92.9+ (Docking Branch)
- **Haxe Target**: HashLink (HL)
- **Framework**: HLX Modding Framework
- **UI Renderer**: DX12 overlay in-game

---

## 🏗️ **ARCHITECTURE OVERVIEW**

### The UI System Stack
```
┌─────────────────────────────────────────┐
│         SolarFlare Mod UI              │
├─────────────────────────────────────────┤
│      Haxe ImGui Wrappers               │
├─────────────────────────────────────────┤
│      hl-imgui Native Bindings          │
├─────────────────────────────────────────┤
│    Dear ImGui Docking Branch           │
├─────────────────────────────────────────┤
│    HashLink Runtime (HLX)              │
├─────────────────────────────────────────┤
│    Farever Game Engine (Heaps/DX12)    │
└─────────────────────────────────────────┘
```

### Critical Pattern: Begin/End Pairing
**IMPORTANT**: Every `Begin*()` call MUST have a corresponding `End*()` call. This is the #1 source of bugs.
```haxe
// ✅ CORRECT
if (ImGui.begin("Window")) {
    // Content
    ImGui.end();
}

// ❌ WRONG - Causes stack corruption
if (ImGui.begin("Window")) {
    // Content
    // Missing ImGui.end()
}
```

---

## 🪟 **DOCKING SYSTEM**

### Core Concepts
| Concept | Description | Key Functions |
|---------|-------------|---------------|
| **DockSpace** | Container for docked windows | `ImGui.dockSpace()` |
| **Dock Node** | Individual docking area | Auto-created by docking |
| **Dock ID** | Unique identifier for docking | `ImGui.setNextWindowDockID()` |
| **Layout Persistence** | Auto-saved to `imgui.ini` | `ImGui.saveIniSettingsToDisk()` |

### Implementation Pattern
```haxe
// 1. Create dockspace first (per frame)
var dockSpaceId = ImGui.getID("MainDockSpace");
ImGui.dockSpace(dockSpaceId, ImGui.vec2(0, 0), 
    ImGuiDockNodeFlags.PassthruCentralNode);

// 2. Set dock ID before begin()
ImGui.setNextWindowDockID(dockSpaceId, ImGuiCond.FirstUseEver);

// 3. Create window
if (ImGui.begin("My Window", open)) {
    // Content
    ImGui.end();
}
```

### Docking Best Practices
1. **Dockspace first**: Always create the dockspace before any windows
2. **Use FirstUseEver**: Set position/size with `ImGuiCond.FirstUseEver`
3. **Save on shutdown**: Call `ImGui.saveIniSettingsToDisk()` on mod unload
4. **NoSelfDocking**: Docking a window to itself causes infinite recursion
5. **Handle dock state**: Check `ImGui.isWindowDocked()` before applying window positions

---

## 🖱️ **DRAG & DROP SYSTEM**

### Payload Types (Pre-defined)
| Payload | Description | Data Format |
|---------|-------------|-------------|
| `AURA_DATA` | Aura definition | JSON string of aura ID |
| `SKILL_DATA` | Skill information | JSON with id, name, icon |
| `ICON_DATA` | Icon identifier | String ID |
| `TEXT_DATA` | Plain text | UTF-8 string |

### Implementation Pattern
```haxe
// === SOURCE ===
if (ImGui.beginDragDropSource()) {
    // Payload data
    var data = hl.Bytes.fromUTF8(itemId);
    ImGui.setDragDropPayload("PAYLOAD_TYPE", data, data.length + 1);
    
    // Preview
    ImGui.text("Dragging: " + itemName);
    
    ImGui.endDragDropSource();
}

// === TARGET ===
if (ImGui.beginDragDropTarget()) {
    var payload = ImGui.acceptDragDropPayload("PAYLOAD_TYPE");
    if (payload != null && ImGui.ImGuiPayload_IsDataType(payload, "PAYLOAD_TYPE")) {
        // Extract data
        var bytes = payload.Data;
        var data = haxe.io.Bytes.ofData(bytes);
        var id = data.getString(0, payload.DataSize);
        // Process drop
    }
    ImGui.endDragDropTarget();
}
```

### Drag & Drop Best Practices
1. **Null check payload**: Always check `payload != null` before accessing
2. **Validate type**: Use `ImGui.ImGuiPayload_IsDataType()` before extracting
3. **Clean up**: Call `endDragDropSource()`/`endDragDropTarget()` in correct order
4. **Visual feedback**: Highlight drop zones when dragging
5. **Payload size**: Keep payload data small (use IDs, not objects)

---

## 📊 **ADVANCED TABLES**

### Table Flags
| Flag | Description |
|------|-------------|
| `ImGuiTableFlags.Sortable` | Enable column sorting |
| `ImGuiTableFlags.Resizable` | Enable column resizing |
| `ImGuiTableFlags.Reorderable` | Enable column reordering |
| `ImGuiTableFlags.Hideable` | Enable column hiding |
| `ImGuiTableFlags.Borders` | Show cell borders |
| `ImGuiTableFlags.RowBg` | Alternating row backgrounds |
| `ImGuiTableFlags.ScrollX/Y` | Enable scrolling |
| `ImGuiTableFlags.SortMulti` | Multi-column sorting |

### Sorting Implementation
```haxe
// Process sorting
var specs = ImGui.tableGetSortSpecs();
if (specs != null && ImGui.tableSortSpecsGetSpecsDirty(specs)) {
    var count = ImGui.tableSortSpecsGetSpecsCount(specs);
    for (i in 0...count) {
        var col = ImGui.tableSortSpecsGetColumnIndex(specs, i);
        var dir = ImGui.tableSortSpecsGetSortDirection(specs, i);
        // Sort data based on col and dir
    }
    ImGui.tableSortSpecsSetSpecsDirty(specs, false);
}
```

### Table Best Practices
1. **Always call `tableSetupColumn()`** before `tableHeadersRow()`
2. **Process sorting** immediately after `tableHeadersRow()`
3. **Use `tableNextColumn()`** to advance to next column
4. **Handle sorting** with `ImGuiTableSortSpecs`
5. **Freeze columns** with `tableSetupScrollFreeze()` for large tables

---

## ✅ **MULTI-SELECT SYSTEM**

### Selection Modes
| Mode | Description | Trigger |
|------|-------------|---------|
| **Single** | Select one item | Click |
| **Range** | Select contiguous range | Shift+Click |
| **Toggle** | Toggle selection | Ctrl+Click |
| **Box** | Drag selection box | Click and drag |
| **All** | Select all | Select All button |

### Implementation Pattern
```haxe
var flags = ImGuiMultiSelectFlags.None;
if (allowBoxSelect) flags |= ImGuiMultiSelectFlags.BoxSelect1d;
if (allowClearOnEscape) flags |= ImGuiMultiSelectFlags.ClearOnEscape;

var io = ImGui.beginMultiSelect(flags, -1, items.length);

for (i in 0...items.length) {
    ImGui.setNextItemSelectionUserData(i);
    if (ImGui.selectable(items[i].name, selected[i])) {
        // Selection handled by ImGui
    }
}

var endIo = ImGui.endMultiSelect();
if (endIo != null) {
    // Process selection changes from endIo.Requests
}
```

### Multi-Select Best Practices
1. **Set user data**: Always call `setNextItemSelectionUserData()` before each item
2. **Process IO**: Always check `endIo` for selection requests
3. **Use flags**: Enable `ClearOnEscape` for better UX
4. **Handle range**: Process `SetRange` requests in `endIo`
5. **Update state**: Sync your selection array after processing

---

## 📝 **INPUT TEXT**

### Input Types & Flags
| Type | Flag/Function | Use Case |
|------|---------------|----------|
| Standard | `ImGui.inputText()` | Simple text |
| With Hint | `ImGui.inputTextWithHint()` | Search bars, forms |
| Multiline | `ImGui.inputTextMultiline()` | Scripts, notes |
| Password | `ImGuiInputTextFlags.Password` | Secrets |
| Numeric | `ImGui.inputInt()` / `ImGui.inputFloat()` | Numbers |
| Auto-complete | `ImGui.inputTextWithCompletion()` | Skill/command search |

### Auto-Completion Pattern
```haxe
// 1. Input field
if (ImGui.inputTextWithHint("##search", "Search...", buf, 128)) {
    var text = ByteUtil.readString(buf, 128, true);
    updateCandidates(text);
}

// 2. Completion popup
if (showCompletion) {
    ImGui.setNextWindowPos(popupPos);
    ImGui.begin("##completion", null, 
        ImGuiWindowFlags.NoTitleBar | ImGuiWindowFlags.Tooltip);
    
    for (candidate in candidates) {
        if (ImGui.selectable(candidate)) {
            ByteUtil.fillBuf(buf, 128, candidate);
            showCompletion = false;
        }
    }
    ImGui.end();
}
```

### Input Text Best Practices
1. **Use hints**: Always use `inputTextWithHint()` for search bars
2. **Handle callbacks**: Use callbacks for live validation
3. **Buffer size**: Allocate buffer size + 1 for null terminator
4. **Clear on escape**: Enable `ImGuiInputTextFlags.EscapeClearsAll` for search
5. **Word wrap**: Enable `ImGuiInputTextFlags.WordWrap` for multiline

---

## 🔤 **FONTS**

### Font Loading Methods
| Method | Function | Use Case |
|--------|----------|----------|
| File | `AddFontFromFileTTF()` | External fonts |
| Memory | `AddFontFromMemoryTTF()` | Embedded fonts |
| Merge | `AddFontFromFileTTF(font, config.MergeMode)` | Icon fonts |
| Ranges | `AddFontFromFileTTF(font, size, config, ranges)` | CJK/Unicode |

### Icon Font Integration
```haxe
// 1. Load icon font
var iconConfig = new ImFontConfig();
iconConfig.MergeMode = true;
iconConfig.PixelSnapH = true;
var iconFont = ImGui.getIO().Fonts.AddFontFromFileTTF(
    "fonts/fontawesome.ttf", 16, iconConfig);

// 2. Use icons
ImGui.pushFont(iconFont);
ImGui.text("\uF0C7 Save");  // Font Awesome save icon
ImGui.popFont();
```

### Font Best Practices
1. **Load at init**: Load fonts during mod initialization, not per frame
2. **Cache fonts**: Store font references in a Map for reuse
3. **Use fallbacks**: Always have a fallback font
4. **Icon fonts**: Use merge mode for icon fonts
5. **Build once**: Build font atlas once, not per frame

---

## 📈 **PLOTS**

### Plot Types
| Type | Function | Use Case |
|------|----------|----------|
| Line | `plotLines()` | Continuous data (DPS, health) |
| Histogram | `plotHistogram()` | Discrete data (damage breakdown) |

### Implementation Pattern
```haxe
// Create data buffer
var values = new hl.Bytes(samples * 4);
for (i in 0...samples) {
    values.setF32(i * 4, data[i]);
}

// Draw plot
ImGui.pushStyleColor(ImGuiCol.PlotLines, 0xFF44AAFF);
ImGui.plotLines("DPS", values, samples, 0, 
    "Current: " + Std.int(dps), 0, maxValue);
ImGui.popStyleColor();
```

### Plot Best Practices
1. **Buffer reuse**: Reuse byte buffers for performance
2. **Auto-scale**: Use min/max for auto-scaling
3. **Labels**: Include meaningful labels
4. **Live data**: Use ring buffer for real-time data
5. **Colors**: Use `pushStyleColor()` for custom colors

---

## ⌨️ **SHORTCUTS**

### Key Chord System
| Modifier | Constant | Description |
|----------|----------|-------------|
| Ctrl | `ImGuiMod.Ctrl` | Control key |
| Shift | `ImGuiMod.Shift` | Shift key |
| Alt | `ImGuiMod.Alt` | Alt key |
| Super | `ImGuiMod.Super` | Windows/Command key |

### Implementation Pattern
```haxe
// Global shortcut
if (ImGui.shortcut(ImGuiKey.S | ImGuiMod.Ctrl)) {
    save();
}

// Widget shortcut
ImGui.setNextItemShortcut(ImGuiKey.S | ImGuiMod.Ctrl);
if (ImGui.button("Save")) {
    save();
}

// Custom key detection
if (ImGui.isKeyPressed(ImGuiKey.F5, false)) {
    refresh();
}
```

### Shortcut Best Practices
1. **Use chords**: Always include modifier keys for common actions
2. **Be consistent**: Use standard shortcuts (Ctrl+S = save)
3. **Document**: Show shortcuts in UI labels
4. **Avoid conflicts**: Don't use shortcuts that conflict with game
5. **Ownership**: Use `setKeyOwner()` to prevent conflicts

---

## 🎨 **COLOR PICKER**

### Color Edit Flags
| Flag | Description |
|------|-------------|
| `ImGuiColorEditFlags.AlphaBar` | Show alpha bar |
| `ImGuiColorEditFlags.AlphaPreviewHalf` | Show alpha preview |
| `ImGuiColorEditFlags.DisplayRGB` | Display RGB values |
| `ImGuiColorEditFlags.DisplayHSV` | Display HSV values |
| `ImGuiColorEditFlags.DisplayHex` | Display Hex value |
| `ImGuiColorEditFlags.PickerHueWheel` | Use hue wheel |
| `ImGuiColorEditFlags.NoInputs` | Hide input fields |

### Implementation Pattern
```haxe
// RGB picker
ImGui.colorEdit3("Color", color);

// RGBA picker
ImGui.colorEdit4("Color", color, 
    ImGuiColorEditFlags.AlphaBar | 
    ImGuiColorEditFlags.PickerHueWheel);

// Color button (swatch)
ImGui.colorButton("Swatch", color);

// HSV picker
ImGui.colorEdit4("Color", color, 
    ImGuiColorEditFlags.DisplayHSV);
```

### Color Picker Best Practices
1. **Alpha support**: Use `AlphaBar` for colors with transparency
2. **Palette**: Include a palette for quick selection
3. **Recent colors**: Store recent colors for user convenience
4. **HSV mode**: Offer HSV mode for intuitive color picking
5. **Hex input**: Include hex input for exact colors

---

## 💬 **TOOLTIPS & CONTEXT MENUS**

### Tooltip Types
| Type | Function | Use Case |
|------|----------|----------|
| Basic | `ImGui.setTooltip()` | Quick help |
| Rich | `ImGui.beginTooltip()` | Detailed info |
| Delayed | `ImGui.isItemHovered(ImGuiHoveredFlags.DelayNormal)` | Reduce clutter |
| Conditional | Check condition before showing | Context-aware help |

### Context Menu Pattern
```haxe
// Open on right-click
if (ImGui.isItemClicked(ImGuiMouseButton.Right)) {
    ImGui.openPopup("context_menu");
}

// Draw menu
if (ImGui.beginPopup("context_menu")) {
    if (ImGui.menuItem("Edit", "Ctrl+E")) {
        editItem();
    }
    if (ImGui.menuItem("Delete", "Del")) {
        deleteItem();
    }
    ImGui.endPopup();
}
```

### Tooltip & Context Best Practices
1. **Rich tooltips**: Use `beginTooltip()` for detailed info
2. **Delayed display**: Use `ImGuiHoveredFlags.DelayNormal` for non-critical tooltips
3. **Context menus**: Always open on right-click
4. **Nested menus**: Use `beginMenu()`/`endMenu()` for hierarchies
5. **Keyboard shortcuts**: Show shortcuts in menu items

---

## 🍞 **TOAST NOTIFICATIONS**

### Toast Types
| Type | Color | Use Case |
|------|-------|----------|
| Info | Blue | General information |
| Success | Green | Success confirmation |
| Warning | Yellow | Warning messages |
| Error | Red | Error messages |

### Implementation Pattern
```haxe
// Show toasts
ToastManager.info("Loading complete", 3.0);
ToastManager.success("Saved successfully", 2.0);
ToastManager.warning("Low resources", 4.0);
ToastManager.error("Failed to load", 5.0);

// Draw toasts (called every frame)
ToastManager.draw();
```

### Toast Best Practices
1. **Auto-dismiss**: Always set a duration (2-5 seconds)
2. **Stacking**: Allow multiple toasts to stack
3. **Priority**: Error messages should stay longer
4. **Non-blocking**: Toasts should not block interaction
5. **Position**: Place toasts where they don't cover important UI

---

## 🎨 **STYLING & THEMES**

### Style Variables (Key)
| Variable | Description | Default |
|----------|-------------|---------|
| `WindowRounding` | Window corner rounding | 0 |
| `FrameRounding` | Frame corner rounding | 0 |
| `WindowPadding` | Window padding | 8,8 |
| `FramePadding` | Frame padding | 4,3 |
| `ItemSpacing` | Item spacing | 8,4 |

### Theme Implementation
```haxe
// Apply dark theme
ImGui.pushStyleColor(ImGuiCol.WindowBg, ImGui.vec4(0.08, 0.09, 0.12, 0.95));
ImGui.pushStyleColor(ImGuiCol.TitleBg, ImGui.vec4(0.15, 0.17, 0.22, 0.95));
ImGui.pushStyleColor(ImGuiCol.Button, ImGui.vec4(0.15, 0.17, 0.22, 0.8));
ImGui.pushStyleVar(ImGuiStyleVar.WindowRounding, 8);
ImGui.pushStyleVar(ImGuiStyleVar.FrameRounding, 4);

// Draw UI...

ImGui.popStyleVar(2);
ImGui.popStyleColor(3);
```

### Styling Best Practices
1. **Theme manager**: Use a centralized theme system
2. **Consistency**: Maintain consistent spacing and rounding
3. **Dark theme**: Default to dark theme for gaming mods
4. **Custom colors**: Allow users to customize colors
5. **Preview**: Include a style preview in settings

---

## ⚡ **PERFORMANCE OPTIMIZATION**

### Key Techniques
| Technique | Description | Impact |
|-----------|-------------|--------|
| **Virtualization** | Render only visible items | High |
| **Caching** | Cache expensive operations | High |
| **Dirty Flags** | Only update changed items | High |
| **Throttling** | Limit update frequency | Medium |
| **Lazy Loading** | Load on demand | High |

### Implementation Pattern
```haxe
// Virtual list
var clipper = new ImGuiListClipper();
clipper.Begin(items.length, 24);
while (clipper.Step()) {
    for (i in clipper.DisplayStart...clipper.DisplayEnd) {
        renderItem(items[i]);
    }
}

// Cache expensive data
var cached = UIOptimizer.cachedUI("key", function() {
    return computeExpensiveData();
}, 0.5);

// Dirty flags
if (dirty) {
    rebuildUI();
    dirty = false;
}
```

### Optimization Best Practices
1. **Profile first**: Use performance monitor to identify bottlenecks
2. **Virtualize large lists**: Always virtualize lists > 100 items
3. **Cache expensive computations**: Cache data that doesn't change often
4. **Throttle updates**: Limit updates to 10-30 fps for non-critical UI
5. **Lazy load textures**: Load images only when visible

---

## 🏗️ **BEST PRACTICES SUMMARY**

### Architecture
1. **Separate concerns**: UI logic separate from business logic
2. **Event-driven**: Use events for state changes
3. **Singleton manager**: Use singleton pattern for managers
4. **Dependency injection**: Inject dependencies rather than hard-coding
5. **Error handling**: Always wrap ImGui calls in try/catch

### UI Development
1. **Begin/End pairing**: Always pair Begin/End calls
2. **Check return values**: Check Begin() return values
3. **Push/Pop styling**: Always pop pushed styles
4. **Window flags**: Use appropriate window flags
5. **Dirty flags**: Use dirty flags to avoid unnecessary redraws

### User Experience
1. **Feedback**: Always provide feedback (toasts, tooltips)
2. **Keyboard shortcuts**: Support keyboard shortcuts
3. **Consistency**: Maintain consistent UI patterns
4. **Accessibility**: Support large fonts and high contrast
5. **Help system**: Include context-sensitive help

### Performance
1. **Virtualization**: Use clipper for large lists
2. **Caching**: Cache expensive computations
3. **Throttling**: Limit update frequency
4. **Lazy loading**: Load resources on demand
5. **Batch drawing**: Batch draw calls when possible

---

## 📚 **REFERENCE: KEY FUNCTIONS**

### Docking
```haxe
ImGui.dockSpace(id, size, flags)
ImGui.dockSpaceOverViewport(viewport, flags)
ImGui.setNextWindowDockID(dock_id, cond)
ImGui.isWindowDocked()
ImGui.getWindowDockID()
```

### Drag & Drop
```haxe
ImGui.beginDragDropSource(flags)
ImGui.setDragDropPayload(type, data, size, cond)
ImGui.endDragDropSource()
ImGui.beginDragDropTarget()
ImGui.acceptDragDropPayload(type, flags)
ImGui.endDragDropTarget()
ImGui.getDragDropPayload()
```

### Tables
```haxe
ImGui.beginTable(id, columns, flags)
ImGui.tableSetupColumn(label, flags, width)
ImGui.tableHeadersRow()
ImGui.tableNextRow(flags, minRowHeight)
ImGui.tableNextColumn()
ImGui.tableGetSortSpecs()
ImGui.tableSortSpecsGetSpecsDirty(specs)
ImGui.tableSortSpecsGetColumnIndex(specs, i)
ImGui.tableSortSpecsGetSortDirection(specs, i)
ImGui.endTable()
```

### Multi-Select
```haxe
ImGui.beginMultiSelect(flags, selection_size, items_count)
ImGui.setNextItemSelectionUserData(data)
ImGui.endMultiSelect()
```

### Input Text
```haxe
ImGui.inputText(label, buf, size)
ImGui.inputTextWithHint(label, hint, buf, size)
ImGui.inputTextMultiline(label, buf, size, dims)
ImGui.inputInt(label, value, step, step_fast)
ImGui.inputFloat(label, value, step, step_fast)
ImGui.inputTextWithCompletion(label, buf, size, callback)
```

### Fonts
```haxe
ImGui.getIO().Fonts.AddFontFromFileTTF(filename, size, config, ranges)
ImGui.getIO().Fonts.Build()
ImGui.pushFont(font)
ImGui.popFont()
```

### Shortcuts
```haxe
ImGui.shortcut(key_chord)
ImGui.setNextItemShortcut(key_chord)
ImGui.isKeyPressed(key, repeat)
ImGui.isKeyDown(key)
ImGui.getKeyName(key)
```

### Color Picker
```haxe
ImGui.colorEdit3(label, color)
ImGui.colorEdit4(label, color, flags)
ImGui.colorButton(desc_id, color, flags, size)
```

### Tooltips
```haxe
ImGui.setTooltip(text)
ImGui.beginTooltip()
ImGui.endTooltip()
ImGui.beginItemTooltip()
ImGui.isItemHovered(flags)
```

### Context Menus
```haxe
ImGui.openPopup(id)
ImGui.beginPopup(id, flags)
ImGui.menuItem(label, shortcut, selected, enabled)
ImGui.beginMenu(label)
ImGui.endMenu()
ImGui.endPopup()
ImGui.closeCurrentPopup()
```

### Styling
```haxe
ImGui.pushStyleColor(col, value)
ImGui.pushStyleVar(var, value)
ImGui.popStyleColor(count)
ImGui.popStyleVar(count)
ImGui.getStyle()
```

### Plots
```haxe
ImGui.plotLines(label, values, count, offset, overlay, scale_min, scale_max, size)
ImGui.plotHistogram(label, values, count, offset, overlay, scale_min, scale_max, size)
```

---

## 🏷️ **TAG REFERENCE**

```
#imgui #docking #ui #modding #hlx #hashlink #solarflare
#best-practices #performance #ux #haxe
```

---

## 📌 **VERSION HISTORY**

| Version | Date | Changes |
|---------|------|---------|
| v2.0 | 2026-08-29 | Complete rewrite for Docking Branch |
| v1.0 | 2026-07-01 | Initial standard ImGui implementation |

---

## 🤝 **CONTRIBUTING**

To add to this knowledge base:
1. Update this document with new findings
2. Tag with appropriate labels
3. Include code examples
4. Reference related issues/pull requests

---

*Generated by SolarFlare Development Team*  
*For use with Mem0 Agent Memory System*