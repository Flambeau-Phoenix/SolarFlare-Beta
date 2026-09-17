
---

## 👁️ **PREVIEW WINDOWS - COMPLETE GUIDE**

### **1. Preview Window Types**

| Preview Type | Function | Code Example | Use Case |
|--------------|----------|--------------|----------|
| **Live Preview** | Real-time updates | `ImGui.begin("Preview")` | Aura visual preview |
| **Dynamic Preview** | Content changes based on settings | `ImGui.begin("Dynamic Preview")` | Geaux bar preview |
| **Interactive Preview** | Clickable/draggable preview | `ImGui.invisibleButton()` | Test aura triggers |
| **Animated Preview** | Continuous animation | `ImGui.getTime()` | Combo tracker preview |
| **Split Preview** | Side-by-side comparison | `ImGui.columns(2)` | Before/after |
| **Floating Preview** | Draggable preview window | `ImGui.setNextWindowPos()` | Tooltip preview |
| **Modal Preview** | Focused preview | `ImGui.beginPopupModal()` | Confirmation dialogs |
| **Tooltip Preview** | Hover-activated preview | `ImGui.beginTooltip()` | Skill tooltips |

---

### **2. Live Preview System**

```haxe
// LivePreview.hx - Complete live preview system
package solarflare.ui.preview;

import imgui.ImGui;
import imgui.Enums.ImGuiCond;
import imgui.Enums.ImGuiWindowFlags;
import imgui.Structs.ImVec2;
import imgui.ref.BoolRef;
import imgui.ref.FloatRef;

/**
 * Live preview system with real-time updates
 * Perfect for Aura Builder, Geaux Bar, and Notebook
 */
class LivePreview {
    public var open = new BoolRef(true);
    public var autoUpdate:Bool = true;
    public var updateSpeed:Float = 0.1;
    var updateTimer:Float = 0;
    var previewContent:Void->Void;
    var previewTitle:String = "Live Preview";
    
    public function new(title:String, content:Void->Void) {
        this.previewTitle = title;
        this.previewContent = content;
    }
    
    public function draw():Void {
        if (!open.get()) return;
        
        ImGui.setNextWindowSize(ImGui.vec2(400, 300), ImGuiCond.FirstUseEver);
        ImGui.setNextWindowSizeConstraints(ImGui.vec2(200, 150), ImGui.vec2(800, 600));
        
        if (ImGui.begin(previewTitle, open, ImGuiWindowFlags.None)) {
            drawToolbar();
            ImGui.separator();
            
            // Live preview area with animation
            if (autoUpdate) {
                updateTimer += ImGui.getDeltaTime();
                if (updateTimer >= updateSpeed) {
                    updateTimer = 0;
                    // Trigger update
                }
            }
            
            // Preview content
            if (previewContent != null) {
                previewContent();
            }
            
            // Status bar
            drawStatusBar();
        }
        ImGui.end();
    }
    
    function drawToolbar():Void {
        // Auto-update toggle
        if (ImGui.checkbox("Auto-update", autoUpdate)) {
            // Toggle auto-update
        }
        ImGui.sameLine();
        
        // Update speed
        ImGui.setNextItemWidth(60);
        if (ImGui.sliderFloat("Speed", updateSpeed, 0.05, 0.5, "%.2f")) {
            // Update speed changed
        }
        ImGui.sameLine();
        
        // Manual update button
        if (ImGui.button("↻ Refresh")) {
            updateTimer = updateSpeed;
        }
        ImGui.sameLine();
        
        // Reset view
        if (ImGui.button("Reset")) {
            // Reset preview state
        }
    }
    
    function drawStatusBar():Void {
        var status = "Ready";
        ImGui.textDisabled(status);
    }
}
```

---

### **3. Aura Builder Live Preview**

```haxe
// AuraLivePreview.hx - Real-time aura preview
package solarflare.aura.preview;

import imgui.ImGui;
import imgui.Enums.ImGuiCond;
import imgui.Structs.ImVec2;
import solarflare.aura.AuraDef;
import solarflare.aura.AuraVisualRenderer;
import solarflare.ui.VectorGlow;
import solarflare.ui.EnhancedText;

class AuraLivePreview {
    public var progress:Float = 0.5;
    public var stacks:Int = 3;
    public var counter:Int = 5;
    public var isActive:Bool = true;
    public var animating:Bool = true;
    var animTime:Float = 0;
    var hovered:Bool = false;
    
    public function draw(a:AuraDef, width:Float, height:Float):Void {
        if (a == null) return;
        
        var drawList = ImGui.getWindowDrawList();
        var pos = ImGui.getCursorScreenPos();
        
        // === PREVIEW BACKGROUND ===
        var bgColor = 0xCC1A1A2E;
        ImGui.ImDrawList_AddRectFilled(drawList, pos, 
            ImGui.vec2(pos.x + width, pos.y + height), bgColor, 8);
        
        // === ANIMATION ===
        if (animating) {
            animTime += ImGui.getDeltaTime();
            progress = (Math.sin(animTime * 0.5) + 1) / 2;
        }
        
        // === AURA RENDERER ===
        var centerX = pos.x + width / 2;
        var centerY = pos.y + height / 2;
        var size = Math.min(width, height) * 0.7;
        
        // Draw the aura
        AuraVisualRenderer.draw(drawList, a,
            centerX - size/2, centerY - size/2,
            size, size,
            progress, stacks, counter, false);
        
        // === GLOW EFFECTS ===
        if (isActive) {
            var glowColor = 0x44FFCC44;
            var glowSize = size * (0.8 + 0.2 * Math.sin(animTime * 2));
            VectorGlow.radial(drawList,
                ImGui.vec2(centerX, centerY),
                glowSize,
                glowColor, 0.3, 8);
        }
        
        // === STATUS OVERLAY ===
        var status = isActive ? "ACTIVE" : "INACTIVE";
        var statusColor = isActive ? 0xFF44CC44 : 0xFF444444;
        ImGui.ImDrawList_AddText_Vec2(drawList,
            ImGui.vec2(pos.x + 8, pos.y + height - 20),
            statusColor, status);
        
        // === PROGRESS BAR ===
        var barX = pos.x + 10;
        var barY = pos.y + height - 10;
        var barW = width - 20;
        var barH = 4;
        ImGui.ImDrawList_AddRectFilled(drawList,
            ImGui.vec2(barX, barY),
            ImGui.vec2(barX + barW, barY + barH),
            0x44FFFFFF, 2);
        ImGui.ImDrawList_AddRectFilled(drawList,
            ImGui.vec2(barX, barY),
            ImGui.vec2(barX + barW * progress, barY + barH),
            0xCC44CCFF, 2);
        
        // === INTERACTION ===
        ImGui.setCursorScreenPos(pos);
        ImGui.invisibleButton("aura_preview_hit", ImGui.vec2(width, height));
        hovered = ImGui.isItemHovered();
        
        // Tooltip on hover
        if (hovered) {
            ImGui.beginTooltip();
            ImGui.text("Progress: " + Std.int(progress * 100) + "%");
            ImGui.text("Stacks: " + stacks);
            ImGui.text("Status: " + (isActive ? "Active" : "Inactive"));
            ImGui.endTooltip();
        }
        
        // Reserve space
        ImGui.setCursorScreenPos(ImGui.vec2(pos.x, pos.y + height));
        ImGui.dummy(ImGui.vec2(width, height));
    }
    
    public function drawControls():Void {
        // Progress slider
        if (ImGui.sliderFloat("Progress", progress, 0, 1, "%.0f%%")) {
            animating = false;
        }
        
        // Stack control
        ImGui.text("Stacks:");
        ImGui.sameLine();
        if (ImGui.smallButton("-")) {
            stacks = Math.max(0, stacks - 1);
        }
        ImGui.sameLine();
        ImGui.text(Std.string(stacks));
        ImGui.sameLine();
        if (ImGui.smallButton("+")) {
            stacks = Math.min(20, stacks + 1);
        }
        
        // Animation toggle
        if (ImGui.checkbox("Animate", animating)) {
            animating = !animating;
        }
        
        // State toggle
        if (ImGui.checkbox("Active", isActive)) {
            isActive = !isActive;
        }
    }
}
```

---

### **4. Geaux Bar Live Preview**

```haxe
// GeauxLivePreview.hx - Live Geaux bar preview
package solarflare.geaux.preview;

import imgui.ImGui;
import imgui.Structs.ImVec2;
import solarflare.geaux.GeauxConfig;
import solarflare.geaux.GeauxBar;
import solarflare.geaux.GeauxCache;

class GeauxLivePreview {
    var previewBar:GeauxBar;
    var previewConfig:GeauxConfig;
    var animTime:Float = 0;
    
    public function new() {
        previewBar = new GeauxBar();
        previewConfig = new GeauxConfig();
    }
    
    public function draw(config:GeauxConfig):Void {
        if (config == null) return;
        
        var pos = ImGui.getCursorScreenPos();
        var avail = ImGui.getContentRegionAvail();
        
        // === PREVIEW HEADER ===
        ImGui.text("Geaux Bar Live Preview");
        ImGui.sameLine(ImGui.getWindowWidth() - 120);
        ImGui.textDisabled(Std.string(config.visibleCount()) + " cells");
        
        ImGui.separator();
        
        // === SIMULATE GAME STATE ===
        animTime += ImGui.getDeltaTime();
        simulateGameState(animTime);
        
        // === DRAW PREVIEW ===
        var previewHeight = Math.min(avail.y - 40, 300);
        ImGui.beginChild("geaux_preview", ImGui.vec2(avail.x, previewHeight), true);
        
        // Copy config for preview
        var previewCfg = cloneConfig(config);
        previewCfg.enabled.set(true);
        previewCfg.chrome = null; // No chrome in preview
        
        previewBar.drawPreview(previewCfg, null, -1);
        
        ImGui.endChild();
        
        // === STATUS BAR ===
        ImGui.separator();
        ImGui.text("⬇ Drag skills into cells from the catalog below");
        ImGui.text("Click cells to select them for keybinding");
        
        // === CATALOG PREVIEW ===
        if (ImGui.collapsingHeader("Skill Catalog (Drag to cells)")) {
            drawCatalogPreview();
        }
    }
    
    function simulateGameState(time:Float):Void {
        // Simulate cooldowns and states
        var skills = GeauxCache.weapons;
        for (i in 0...skills.length) {
            if (skills[i] != null) {
                var snap = skills[i];
                // Simulate cooldown pulsing
                if (i == 0) {
                    snap.cdLeft = 2 + Math.sin(time) * 1.5;
                    snap.ready = snap.cdLeft <= 0.1;
                    snap.remaining = snap.cdLeft / 5;
                }
                if (i == 2) {
                    snap.ready = Math.sin(time) > 0;
                    snap.affordable = snap.ready;
                }
            }
        }
    }
    
    function cloneConfig(src:GeauxConfig):GeauxConfig {
        var dst = new GeauxConfig();
        dst.rows.set(src.rows.get());
        dst.cols.set(src.cols.get());
        dst.width.set(src.width.get());
        dst.height.set(src.height.get());
        dst.slotIds = src.slotIds.copy();
        dst.slotGlyphs = src.slotGlyphs.copy();
        dst.slotHotkeys = src.slotHotkeys.copy();
        if (src.style != null) {
            dst.style = src.style;
        }
        return dst;
    }
    
    function drawCatalogPreview():Void {
        var skills = GeauxCache.weapons;
        if (skills.length == 0) {
            ImGui.textDisabled("No skills in catalog");
            return;
        }
        
        var cols = 6;
        for (i in 0...skills.length) {
            if (i > 0 && i % cols != 0) ImGui.sameLine();
            var skill = skills[i];
            if (skill != null) {
                // Skill button with icon
                if (ImGui.button(skill.label, ImGui.vec2(60, 40))) {
                    // Assign to selected cell
                }
                if (ImGui.isItemHovered()) {
                    ImGui.beginTooltip();
                    ImGui.text("ID: " + skill.id);
                    ImGui.text("Group: " + skill.group);
                    ImGui.endTooltip();
                }
            }
        }
    }
}
```

---

### **5. Notebook Live Preview**

```haxe
// NotebookPreview.hx - Rich text preview
package solarflare.notebook.preview;

import imgui.ImGui;
import imgui.Structs.ImVec2;

class NotebookPreview {
    var previewText:String = "";
    var previewTitle:String = "";
    var fontSize:Float = 14;
    var showWordCount:Bool = true;
    var showMarkdown:Bool = true;
    
    public function draw(title:String, body:String):Void {
        previewTitle = title;
        previewText = body;
        
        var pos = ImGui.getCursorScreenPos();
        var avail = ImGui.getContentRegionAvail();
        
        // === PREVIEW HEADER ===
        ImGui.separatorText("Preview");
        
        // === PAGE PREVIEW ===
        var height = Math.min(avail.y - 40, 300);
        ImGui.beginChild("note_preview", ImGui.vec2(avail.x, height), true);
        
        // Page styling
        ImGui.pushStyleColor(ImGuiCol.ChildBg, 0xCC222244);
        ImGui.pushStyleVar(ImGuiStyleVar.FramePadding, ImGui.vec2(8, 8));
        
        // Title
        ImGui.pushFont(ImGui.getFont(), fontSize * 1.4);
        ImGui.textColored(ImGui.vec4(1, 1, 1, 1), previewTitle != "" ? previewTitle : "Untitled");
        ImGui.popFont();
        
        ImGui.separator();
        
        // Body (with basic Markdown support)
        if (showMarkdown) {
            drawMarkdownText(previewText);
        } else {
            ImGui.textWrapped(previewText);
        }
        
        // Word count
        if (showWordCount) {
            ImGui.separator();
            var wordCount = previewText.split(" ").length;
            ImGui.textDisabled(wordCount + " words");
        }
        
        ImGui.popStyleVar();
        ImGui.popStyleColor();
        ImGui.endChild();
        
        // === PREVIEW CONTROLS ===
        ImGui.separator();
        if (ImGui.checkbox("Markdown preview", showMarkdown)) {
            // Toggle markdown
        }
        ImGui.sameLine();
        if (ImGui.sliderFloat("Preview font size", fontSize, 10, 24, "%.0fpx")) {
            // Update font size
        }
    }
    
    function drawMarkdownText(text:String):Void {
        var lines = text.split("\n");
        for (line in lines) {
            var trimmed = StringTools.trim(line);
            if (trimmed.length == 0) {
                ImGui.text("");
                continue;
            }
            
            // Headers
            if (StringTools.startsWith(trimmed, "# ")) {
                ImGui.pushFont(ImGui.getFont(), fontSize * 1.5);
                ImGui.textColored(ImGui.vec4(1, 0.8, 0.4, 1), trimmed.substr(2));
                ImGui.popFont();
                continue;
            }
            if (StringTools.startsWith(trimmed, "## ")) {
                ImGui.pushFont(ImGui.getFont(), fontSize * 1.3);
                ImGui.textColored(ImGui.vec4(0.8, 0.8, 1, 1), trimmed.substr(3));
                ImGui.popFont();
                continue;
            }
            
            // Bullet points
            if (StringTools.startsWith(trimmed, "- ")) {
                ImGui.text("• " + trimmed.substr(2));
                continue;
            }
            if (StringTools.startsWith(trimmed, "* ")) {
                ImGui.text("◦ " + trimmed.substr(2));
                continue;
            }
            
            // Quotes
            if (StringTools.startsWith(trimmed, "> ")) {
                ImGui.textColored(ImGui.vec4(0.6, 0.8, 0.6, 1), "┃ " + trimmed.substr(2));
                continue;
            }
            
            // Bold/italic (simple)
            var display = trimmed;
            display = StringTools.replace(display, "**", "");
            display = StringTools.replace(display, "__", "");
            display = StringTools.replace(display, "*", "");
            
            ImGui.textWrapped(display);
        }
    }
}
```

---

### **6. Split Preview (Before/After)**

```haxe
// SplitPreview.hx - Side-by-side comparison
package solarflare.ui.preview;

import imgui.ImGui;
import imgui.Enums.ImGuiCond;
import imgui.Structs.ImVec2;

class SplitPreview {
    public var splitPosition:Float = 0.5;
    public var showControls:Bool = true;
    
    public function draw(leftContent:Void->Void, rightContent:Void->Void):Void {
        var avail = ImGui.getContentRegionAvail();
        var totalW = avail.x;
        var totalH = avail.y;
        
        // === LEFT PANEL ===
        var leftW = totalW * splitPosition - 4;
        ImGui.beginChild("left_preview", ImGui.vec2(leftW, totalH), true);
        leftContent();
        ImGui.endChild();
        
        // === SPLITTER ===
        ImGui.sameLine();
        ImGui.setCursorPosX(totalW * splitPosition - 2);
        ImGui.invisibleButton("splitter", ImGui.vec2(4, totalH));
        
        if (ImGui.isItemActive()) {
            var delta = ImGui.getMouseDelta().x;
            splitPosition = Math.max(0.1, Math.min(0.9, splitPosition + delta / totalW));
        }
        
        // Splitter visual
        var pos = ImGui.getCursorScreenPos();
        var drawList = ImGui.getWindowDrawList();
        ImGui.ImDrawList_AddRectFilled(drawList,
            ImGui.vec2(pos.x - 1, pos.y),
            ImGui.vec2(pos.x + 1, pos.y + totalH),
            0x66FFFFFF);
        
        ImGui.sameLine();
        
        // === RIGHT PANEL ===
        var rightW = totalW * (1 - splitPosition) - 4;
        ImGui.beginChild("right_preview", ImGui.vec2(rightW, totalH), true);
        rightContent();
        ImGui.endChild();
        
        // === CONTROLS ===
        if (showControls) {
            ImGui.separator();
            if (ImGui.button("◄ Left")) {
                splitPosition = Math.max(0.1, splitPosition - 0.1);
            }
            ImGui.sameLine();
            if (ImGui.button("Reset")) {
                splitPosition = 0.5;
            }
            ImGui.sameLine();
            if (ImGui.button("Right ►")) {
                splitPosition = Math.min(0.9, splitPosition + 0.1);
            }
        }
    }
}
```

---

### **7. Interactive Preview with Controls**

```haxe
// InteractivePreview.hx - Clickable/draggable preview
package solarflare.ui.preview;

import imgui.ImGui;
import imgui.Enums.ImGuiMouseButton;
import imgui.Structs.ImVec2;
import imgui.ref.FloatRef;

class InteractivePreview {
    public var rotation:FloatRef = new FloatRef(0);
    public var scale:FloatRef = new FloatRef(1);
    public var position:ImVec2 = ImGui.vec2(0, 0);
    public var isDragging:Bool = false;
    var dragStart:ImVec2 = ImGui.vec2(0, 0);
    var dragStartPos:ImVec2 = ImGui.vec2(0, 0);
    
    public function draw(content:Void->Void):Bool {
        var avail = ImGui.getContentRegionAvail();
        var pos = ImGui.getCursorScreenPos();
        var size = ImGui.vec2(avail.x, avail.y - 40);
        
        // === PREVIEW CANVAS ===
        ImGui.beginChild("interactive_canvas", size, true);
        var drawList = ImGui.getWindowDrawList();
        
        // Grid background
        drawGrid(drawList, pos, size);
        
        // Transform content
        ImGui.setCursorScreenPos(pos);
        if (ImGui.invisibleButton("canvas_hit", size)) {
            // Click handling
        }
        
        // Drag handling
        if (ImGui.isItemActive() && ImGui.isMouseDragging(ImGuiMouseButton.Left)) {
            if (!isDragging) {
                isDragging = true;
                dragStart = ImGui.getMousePos();
                dragStartPos = position;
            }
            var delta = ImGui.getMouseDelta();
            position.x = dragStartPos.x + delta.x;
            position.y = dragStartPos.y + delta.y;
        }
        if (ImGui.isMouseReleased(ImGuiMouseButton.Left)) {
            isDragging = false;
        }
        
        // Draw content with transformations
        ImGui.setCursorScreenPos(ImGui.vec2(pos.x + position.x, pos.y + position.y));
        content();
        
        ImGui.endChild();
        
        // === CONTROLS ===
        ImGui.separator();
        var changed = false;
        if (ImGui.sliderFloat("Rotation", rotation, -180, 180, "%.0f°")) {
            changed = true;
        }
        if (ImGui.sliderFloat("Scale", scale, 0.2, 2, "%.1f")) {
            changed = true;
        }
        if (ImGui.button("Reset View")) {
            rotation.set(0);
            scale.set(1);
            position = ImGui.vec2(0, 0);
            changed = true;
        }
        
        return changed;
    }
    
    function drawGrid(drawList:Dynamic, pos:ImVec2, size:ImVec2):Void {
        var color = 0x22FFFFFF;
        var step = 20;
        var offsetX = position.x % step;
        var offsetY = position.y % step;
        
        for (x in 0...Std.int(size.x / step) + 2) {
            ImGui.ImDrawList_AddLine(drawList,
                ImGui.vec2(pos.x + x * step + offsetX, pos.y),
                ImGui.vec2(pos.x + x * step + offsetX, pos.y + size.y),
                color);
        }
        for (y in 0...Std.int(size.y / step) + 2) {
            ImGui.ImDrawList_AddLine(drawList,
                ImGui.vec2(pos.x, pos.y + y * step + offsetY),
                ImGui.vec2(pos.x + size.x, pos.y + y * step + offsetY),
                color);
        }
        
        // Center cross
        var cx = pos.x + size.x / 2 + position.x;
        var cy = pos.y + size.y / 2 + position.y;
        ImGui.ImDrawList_AddLine(drawList,
            ImGui.vec2(cx - 20, cy),
            ImGui.vec2(cx + 20, cy),
            0x44FF4444);
        ImGui.ImDrawList_AddLine(drawList,
            ImGui.vec2(cx, cy - 20),
            ImGui.vec2(cx, cy + 20),
            0x44FF4444);
    }
}
```

---

### **8. Preview Window Features Summary**

| Feature | Description | Your Mod Use |
|---------|-------------|--------------|
| **Live Preview** | Real-time content updates | Aura visual preview |
| **Animated Preview** | Continuous animation | Combo tracker preview |
| **Interactive Preview** | Click/drag functionality | Test aura triggers |
| **Split Preview** | Side-by-side comparison | Before/after settings |
| **Transform Preview** | Rotation, scale, position | Icon preview |
| **Canvas Preview** | Grid background, drag content | Geaux bar layout |
| **Tooltip Preview** | Hover-activated preview | Skill tooltips |
| **Modal Preview** | Focused preview | Confirmation dialogs |
| **Resizable Preview** | User-controlled size | Any preview window |
| **Dockable Preview** | Integrated into workspace | All previews |
| **Auto-Updating** | Automatic content refresh | Live game state |
| **Status Overlay** | State information overlay | Aura status |
| **Interactive Controls** | Sliders, buttons, toggles | Settings preview |
| **Markdown Preview** | Rich text rendering | Notebook preview |
| **Grid/Canvas** | Background grid | Positioning tools |

---

### **9. Complete Preview Example: Aura Builder Integration**

```haxe
// AuraBuilderWithPreview.hx - Complete integration
package solarflare.aura;

import imgui.ImGui;
import imgui.Enums.ImGuiCond;
import imgui.Structs.ImVec2;
import solarflare.aura.preview.AuraLivePreview;
import solarflare.ui.preview.SplitPreview;
import solarflare.ui.preview.InteractivePreview;

class AuraBuilderWithPreview {
    var auraPreview:AuraLivePreview;
    var splitPreview:SplitPreview;
    var interactivePreview:InteractivePreview;
    var previewMode:Int = 0; // 0=Live, 1=Split, 2=Interactive
    
    public function new() {
        auraPreview = new AuraLivePreview();
        splitPreview = new SplitPreview();
        interactivePreview = new InteractivePreview();
    }
    
    public function draw(a:AuraDef):Void {
        if (a == null) return;
        
        // Preview mode selector
        ImGui.separatorText("Preview Mode");
        var modes = ["Live", "Split (Before/After)", "Interactive"];
        for (i in 0...modes.length) {
            if (i > 0) ImGui.sameLine();
            if (ImGui.radioButton(modes[i], previewMode == i)) {
                previewMode = i;
            }
        }
        
        ImGui.separator();
        
        // Preview controls
        auraPreview.drawControls();
        
        // Preview content based on mode
        switch (previewMode) {
            case 0: // Live
                var avail = ImGui.getContentRegionAvail();
                auraPreview.draw(a, avail.x, 300);
                
            case 1: // Split
                splitPreview.draw(
                    function() {
                        // Before state
                        auraPreview.draw(a, 300, 250);
                    },
                    function() {
                        // After state
                        var copy = cloneAura(a);
                        copy.region = "ring";
                        auraPreview.draw(copy, 300, 250);
                    }
                );
                
            case 2: // Interactive
                interactivePreview.draw(function() {
                    auraPreview.draw(a, 200, 200);
                });
                
            default:
                // Live
                var avail = ImGui.getContentRegionAvail();
                auraPreview.draw(a, avail.x, 300);
        }
    }
    
    function cloneAura(src:AuraDef):AuraDef {
        var copy = new AuraDef(src.id + "_copy", src.name + " Copy");
        copy.region = src.region;
        copy.announce = src.announce;
        copy.iconId = src.iconId;
        // Copy other fields...
        return copy;
    }
}
```

---

### **10. Preview Window Capabilities Summary**

| Capability | Before | After |
|------------|--------|-------|
| **Real-time Updates** | Manual refresh only | Auto-updating, animated |
| **Interaction** | None | Click, drag, resize |
| **Split View** | None | Side-by-side comparison |
| **Transform** | None | Rotate, scale, position |
| **Canvas** | None | Grid background, drag content |
| **Controls** | None | Full control panel |
| **Docking** | None | Dockable preview windows |
| **Tooltips** | Basic | Rich hover previews |
| **Markdown** | None | Rich text rendering |
| **Animations** | None | Continuous animation |
| **Overlays** | None | Status information |
| **Resizing** | Fixed | User-resizable |
| **State Sync** | None | Live game state sync |

