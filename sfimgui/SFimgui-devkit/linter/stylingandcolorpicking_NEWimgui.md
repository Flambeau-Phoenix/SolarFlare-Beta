
---

## 🎨 **STYLING - COMPLETE GUIDE**

### **1. Style Variables Overview**

| Style Variable | Type | Description | Default |
|-----------------|------|-------------|---------|
| **Alpha** | Float | Global alpha | 1.0 |
| **DisabledAlpha** | Float | Disabled items alpha | 0.6 |
| **WindowPadding** | ImVec2 | Window padding | 8,8 |
| **WindowRounding** | Float | Window corner rounding | 0 |
| **WindowBorderSize** | Float | Window border size | 1 |
| **WindowMinSize** | ImVec2 | Minimum window size | 32,32 |
| **WindowTitleAlign** | ImVec2 | Title alignment | 0,0.5 |
| **ChildRounding** | Float | Child window rounding | 0 |
| **ChildBorderSize** | Float | Child border size | 1 |
| **PopupRounding** | Float | Popup rounding | 0 |
| **PopupBorderSize** | Float | Popup border size | 1 |
| **FramePadding** | ImVec2 | Frame padding | 4,3 |
| **FrameRounding** | Float | Frame corner rounding | 0 |
| **FrameBorderSize** | Float | Frame border size | 0 |
| **ItemSpacing** | ImVec2 | Item spacing | 8,4 |
| **ItemInnerSpacing** | ImVec2 | Inner item spacing | 4,4 |
| **CellPadding** | ImVec2 | Table cell padding | 4,2 |
| **IndentSpacing** | Float | Indent spacing | 21 |
| **ScrollbarSize** | Float | Scrollbar size | 14 |
| **ScrollbarRounding** | Float | Scrollbar rounding | 0 |
| **GrabMinSize** | Float | Grab minimum size | 10 |
| **GrabRounding** | Float | Grab rounding | 0 |
| **TabRounding** | Float | Tab rounding | 0 |
| **TabBorderSize** | Float | Tab border size | 0 |
| **TabMinWidthBase** | Float | Minimum tab width | 0 |
| **TabBarBorderSize** | Float | Tab bar border size | 0 |
| **TableAngledHeadersAngle** | Float | Angled header angle | 0 |
| **TreeLinesSize** | Float | Tree lines size | 0 |
| **TreeLinesRounding** | Float | Tree lines rounding | 0 |
| **MenuItemRounding** | Float | Menu item rounding | 0 |
| **SelectableRounding** | Float | Selectable rounding | 0 |
| **ButtonTextAlign** | ImVec2 | Button text alignment | 0.5,0.5 |
| **SelectableTextAlign** | ImVec2 | Selectable text alignment | 0,0 |
| **SeparatorSize** | Float | Separator size | 0 |
| **SeparatorTextBorderSize** | Float | Separator text border | 1.5 |
| **SeparatorTextAlign** | ImVec2 | Separator text alignment | 0,0.5 |
| **SeparatorTextPadding** | ImVec2 | Separator text padding | 2,0 |
| **DisplayWindowPadding** | ImVec2 | Window display padding | 19,19 |
| **DisplaySafeAreaPadding** | ImVec2 | Safe area padding | 3,3 |

---

### **2. Color Styles Overview**

| Color Style | Description | Default |
|-------------|-------------|---------|
| **Text** | Regular text | White |
| **TextDisabled** | Disabled text | Gray |
| **WindowBg** | Window background | Dark |
| **ChildBg** | Child window background | Darker |
| **PopupBg** | Popup background | Dark |
| **Border** | Border color | Gray |
| **BorderShadow** | Border shadow | Transparent |
| **FrameBg** | Frame background | Dark |
| **FrameBgHovered** | Frame hover | Lighter |
| **FrameBgActive** | Frame active | Light |
| **TitleBg** | Title bar background | Dark |
| **TitleBgActive** | Active title bar | Lighter |
| **TitleBgCollapsed** | Collapsed title bar | Darker |
| **MenuBarBg** | Menu bar background | Dark |
| **ScrollbarBg** | Scrollbar background | Dark |
| **ScrollbarGrab** | Scrollbar grab | Gray |
| **ScrollbarGrabHovered** | Scrollbar grab hover | Lighter |
| **ScrollbarGrabActive** | Scrollbar grab active | Light |
| **CheckMark** | Check mark | White |
| **SliderGrab** | Slider grab | Gray |
| **SliderGrabActive** | Slider grab active | Lighter |
| **Button** | Button background | Dark |
| **ButtonHovered** | Button hover | Lighter |
| **ButtonActive** | Button active | Light |
| **Header** | Header background | Dark |
| **HeaderHovered** | Header hover | Lighter |
| **HeaderActive** | Header active | Light |
| **Separator** | Separator color | Gray |
| **SeparatorHovered** | Separator hover | Lighter |
| **SeparatorActive** | Separator active | Light |
| **ResizeGrip** | Resize grip | Gray |
| **ResizeGripHovered** | Resize grip hover | Lighter |
| **ResizeGripActive** | Resize grip active | Light |
| **Tab** | Tab background | Dark |
| **TabHovered** | Tab hover | Lighter |
| **TabSelected** | Tab selected | Light |
| **TabDimmed** | Tab dimmed | Darker |
| **TabDimmedSelected** | Tab dimmed selected | Dark |
| **PlotLines** | Plot lines | Blue |
| **PlotLinesHovered** | Plot lines hover | Lighter |
| **PlotHistogram** | Plot histogram | Blue |
| **PlotHistogramHovered** | Plot histogram hover | Lighter |
| **TableHeaderBg** | Table header | Dark |
| **TableBorderStrong** | Strong border | Gray |
| **TableBorderLight** | Light border | Light gray |
| **TableRowBg** | Row background | Dark |
| **TableRowBgAlt** | Alternate row background | Darker |
| **TextSelectedBg** | Selected text | Blue |
| **DragDropTarget** | Drag drop target | Blue |
| **NavHighlight** | Navigation highlight | Blue |
| **NavWindowingHighlight** | Windowing highlight | White |
| **NavWindowingDimBg** | Windowing dim | Dark |
| **ModalWindowDimBg** | Modal dim | Dark |

---

### **3. Complete Styling System**

```haxe
// StyleManager.hx - Complete styling system
package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiStyleVar;
import imgui.Structs.ImVec2;
import imgui.Structs.ImVec4;
import imgui.Theme;

class StyleManager {
    public static var currentTheme:String = "dark";
    public static var customColors:Map<ImGuiCol, ImVec4> = new Map();
    public static var customVars:Map<ImGuiStyleVar, Dynamic> = new Map();
    
    public static function init():Void {
        applyTheme("dark");
    }
    
    public static function applyTheme(name:String):Void {
        currentTheme = name;
        switch (name) {
            case "dark": applyDarkTheme();
            case "light": applyLightTheme();
            case "classic": applyClassicTheme();
            case "cyberpunk": applyCyberpunkTheme();
            case "pastel": applyPastelTheme();
            case "custom": applyCustomTheme();
            default: applyDarkTheme();
        }
    }
    
    // === DARK THEME ===
    public static function applyDarkTheme():Void {
        var style = ImGui.getStyle();
        
        // Colors
        ImGui.pushStyleColor(ImGuiCol.Text, ImGui.vec4(0.92, 0.94, 0.96, 1.0));
        ImGui.pushStyleColor(ImGuiCol.TextDisabled, ImGui.vec4(0.6, 0.62, 0.66, 1.0));
        ImGui.pushStyleColor(ImGuiCol.WindowBg, ImGui.vec4(0.08, 0.09, 0.12, 0.95));
        ImGui.pushStyleColor(ImGuiCol.ChildBg, ImGui.vec4(0.1, 0.11, 0.14, 0.95));
        ImGui.pushStyleColor(ImGuiCol.PopupBg, ImGui.vec4(0.06, 0.07, 0.10, 0.95));
        ImGui.pushStyleColor(ImGuiCol.Border, ImGui.vec4(0.3, 0.33, 0.42, 0.5));
        ImGui.pushStyleColor(ImGuiCol.BorderShadow, ImGui.vec4(0, 0, 0, 0));
        ImGui.pushStyleColor(ImGuiCol.FrameBg, ImGui.vec4(0.12, 0.14, 0.18, 1.0));
        ImGui.pushStyleColor(ImGuiCol.FrameBgHovered, ImGui.vec4(0.18, 0.20, 0.25, 1.0));
        ImGui.pushStyleColor(ImGuiCol.FrameBgActive, ImGui.vec4(0.22, 0.25, 0.32, 1.0));
        ImGui.pushStyleColor(ImGuiCol.TitleBg, ImGui.vec4(0.15, 0.17, 0.22, 0.95));
        ImGui.pushStyleColor(ImGuiCol.TitleBgActive, ImGui.vec4(0.2, 0.22, 0.28, 0.95));
        ImGui.pushStyleColor(ImGuiCol.TitleBgCollapsed, ImGui.vec4(0.12, 0.13, 0.16, 0.95));
        ImGui.pushStyleColor(ImGuiCol.MenuBarBg, ImGui.vec4(0.08, 0.09, 0.12, 0.95));
        ImGui.pushStyleColor(ImGuiCol.ScrollbarBg, ImGui.vec4(0.1, 0.11, 0.14, 1.0));
        ImGui.pushStyleColor(ImGuiCol.ScrollbarGrab, ImGui.vec4(0.2, 0.22, 0.28, 0.8));
        ImGui.pushStyleColor(ImGuiCol.ScrollbarGrabHovered, ImGui.vec4(0.25, 0.28, 0.35, 0.9));
        ImGui.pushStyleColor(ImGuiCol.ScrollbarGrabActive, ImGui.vec4(0.3, 0.35, 0.45, 1.0));
        ImGui.pushStyleColor(ImGuiCol.CheckMark, ImGui.vec4(0.4, 0.8, 1.0, 1.0));
        ImGui.pushStyleColor(ImGuiCol.SliderGrab, ImGui.vec4(0.3, 0.5, 0.8, 1.0));
        ImGui.pushStyleColor(ImGuiCol.SliderGrabActive, ImGui.vec4(0.4, 0.6, 0.9, 1.0));
        ImGui.pushStyleColor(ImGuiCol.Button, ImGui.vec4(0.15, 0.17, 0.22, 0.8));
        ImGui.pushStyleColor(ImGuiCol.ButtonHovered, ImGui.vec4(0.2, 0.22, 0.28, 0.9));
        ImGui.pushStyleColor(ImGuiCol.ButtonActive, ImGui.vec4(0.25, 0.28, 0.35, 1.0));
        ImGui.pushStyleColor(ImGuiCol.Header, ImGui.vec4(0.12, 0.14, 0.18, 0.8));
        ImGui.pushStyleColor(ImGuiCol.HeaderHovered, ImGui.vec4(0.18, 0.20, 0.25, 0.9));
        ImGui.pushStyleColor(ImGuiCol.HeaderActive, ImGui.vec4(0.22, 0.25, 0.32, 1.0));
        ImGui.pushStyleColor(ImGuiCol.Separator, ImGui.vec4(0.3, 0.33, 0.42, 0.5));
        ImGui.pushStyleColor(ImGuiCol.SeparatorHovered, ImGui.vec4(0.4, 0.45, 0.55, 0.6));
        ImGui.pushStyleColor(ImGuiCol.SeparatorActive, ImGui.vec4(0.5, 0.55, 0.65, 0.7));
        ImGui.pushStyleColor(ImGuiCol.ResizeGrip, ImGui.vec4(0.2, 0.22, 0.28, 0.6));
        ImGui.pushStyleColor(ImGuiCol.ResizeGripHovered, ImGui.vec4(0.25, 0.28, 0.35, 0.8));
        ImGui.pushStyleColor(ImGuiCol.ResizeGripActive, ImGui.vec4(0.3, 0.35, 0.45, 1.0));
        ImGui.pushStyleColor(ImGuiCol.Tab, ImGui.vec4(0.12, 0.14, 0.18, 0.8));
        ImGui.pushStyleColor(ImGuiCol.TabHovered, ImGui.vec4(0.18, 0.20, 0.25, 0.9));
        ImGui.pushStyleColor(ImGuiCol.TabSelected, ImGui.vec4(0.2, 0.22, 0.28, 1.0));
        ImGui.pushStyleColor(ImGuiCol.TabDimmed, ImGui.vec4(0.08, 0.09, 0.12, 0.8));
        ImGui.pushStyleColor(ImGuiCol.TabDimmedSelected, ImGui.vec4(0.12, 0.14, 0.18, 1.0));
        ImGui.pushStyleColor(ImGuiCol.PlotLines, ImGui.vec4(0.3, 0.6, 0.9, 1.0));
        ImGui.pushStyleColor(ImGuiCol.PlotLinesHovered, ImGui.vec4(0.4, 0.7, 1.0, 1.0));
        ImGui.pushStyleColor(ImGuiCol.PlotHistogram, ImGui.vec4(0.3, 0.8, 0.5, 1.0));
        ImGui.pushStyleColor(ImGuiCol.PlotHistogramHovered, ImGui.vec4(0.4, 0.9, 0.6, 1.0));
        ImGui.pushStyleColor(ImGuiCol.TableHeaderBg, ImGui.vec4(0.12, 0.14, 0.18, 0.9));
        ImGui.pushStyleColor(ImGuiCol.TableBorderStrong, ImGui.vec4(0.3, 0.33, 0.42, 0.8));
        ImGui.pushStyleColor(ImGuiCol.TableBorderLight, ImGui.vec4(0.2, 0.22, 0.28, 0.5));
        ImGui.pushStyleColor(ImGuiCol.TableRowBg, ImGui.vec4(0.08, 0.09, 0.12, 0.5));
        ImGui.pushStyleColor(ImGuiCol.TableRowBgAlt, ImGui.vec4(0.1, 0.11, 0.14, 0.5));
        ImGui.pushStyleColor(ImGuiCol.TextSelectedBg, ImGui.vec4(0.2, 0.4, 0.8, 0.6));
        ImGui.pushStyleColor(ImGuiCol.DragDropTarget, ImGui.vec4(0.3, 0.6, 1.0, 0.9));
        ImGui.pushStyleColor(ImGuiCol.NavHighlight, ImGui.vec4(0.3, 0.6, 1.0, 0.5));
        ImGui.pushStyleColor(ImGuiCol.ModalWindowDimBg, ImGui.vec4(0, 0, 0, 0.6));
        
        // Style vars
        ImGui.pushStyleVar(ImGuiStyleVar.WindowRounding, 8);
        ImGui.pushStyleVar(ImGuiStyleVar.WindowBorderSize, 1);
        ImGui.pushStyleVar(ImGuiStyleVar.WindowPadding, ImGui.vec2(8, 8));
        ImGui.pushStyleVar(ImGuiStyleVar.WindowTitleAlign, ImGui.vec2(0.5, 0.5));
        ImGui.pushStyleVar(ImGuiStyleVar.ChildRounding, 4);
        ImGui.pushStyleVar(ImGuiStyleVar.ChildBorderSize, 1);
        ImGui.pushStyleVar(ImGuiStyleVar.PopupRounding, 6);
        ImGui.pushStyleVar(ImGuiStyleVar.FrameRounding, 4);
        ImGui.pushStyleVar(ImGuiStyleVar.FramePadding, ImGui.vec2(6, 4));
        ImGui.pushStyleVar(ImGuiStyleVar.ItemSpacing, ImGui.vec2(8, 4));
        ImGui.pushStyleVar(ImGuiStyleVar.ItemInnerSpacing, ImGui.vec2(4, 4));
        ImGui.pushStyleVar(ImGuiStyleVar.IndentSpacing, 20);
        ImGui.pushStyleVar(ImGuiStyleVar.ScrollbarRounding, 4);
        ImGui.pushStyleVar(ImGuiStyleVar.GrabRounding, 4);
        ImGui.pushStyleVar(ImGuiStyleVar.TabRounding, 4);
        ImGui.pushStyleVar(ImGuiStyleVar.TabBorderSize, 0);
        ImGui.pushStyleVar(ImGuiStyleVar.SeparatorTextBorderSize, 1.5);
        ImGui.pushStyleVar(ImGuiStyleVar.SeparatorTextPadding, ImGui.vec2(2, 0));
    }
    
    // === LIGHT THEME ===
    public static function applyLightTheme():Void {
        // Light theme colors
        ImGui.pushStyleColor(ImGuiCol.Text, ImGui.vec4(0.1, 0.1, 0.15, 1.0));
        ImGui.pushStyleColor(ImGuiCol.WindowBg, ImGui.vec4(0.92, 0.93, 0.95, 0.95));
        ImGui.pushStyleColor(ImGuiCol.ChildBg, ImGui.vec4(0.88, 0.89, 0.91, 0.95));
        ImGui.pushStyleColor(ImGuiCol.PopupBg, ImGui.vec4(0.94, 0.95, 0.97, 0.95));
        ImGui.pushStyleColor(ImGuiCol.Button, ImGui.vec4(0.8, 0.82, 0.86, 0.8));
        ImGui.pushStyleColor(ImGuiCol.FrameBg, ImGui.vec4(0.85, 0.87, 0.90, 1.0));
        ImGui.pushStyleColor(ImGuiCol.TitleBg, ImGui.vec4(0.85, 0.87, 0.90, 0.95));
        // ... more light colors ...
        
        // Light style vars
        ImGui.pushStyleVar(ImGuiStyleVar.WindowRounding, 8);
        ImGui.pushStyleVar(ImGuiStyleVar.WindowBorderSize, 1);
        // ... more style vars ...
    }
    
    // === CYBERPUNK THEME ===
    public static function applyCyberpunkTheme():Void {
        ImGui.pushStyleColor(ImGuiCol.Text, ImGui.vec4(0.9, 0.85, 1.0, 1.0));
        ImGui.pushStyleColor(ImGuiCol.WindowBg, ImGui.vec4(0.06, 0.04, 0.10, 0.95));
        ImGui.pushStyleColor(ImGuiCol.TitleBg, ImGui.vec4(0.2, 0.08, 0.35, 0.95));
        ImGui.pushStyleColor(ImGuiCol.TitleBgActive, ImGui.vec4(0.3, 0.12, 0.45, 0.95));
        ImGui.pushStyleColor(ImGuiCol.Button, ImGui.vec4(0.6, 0.15, 0.8, 0.8));
        ImGui.pushStyleColor(ImGuiCol.ButtonHovered, ImGui.vec4(0.7, 0.25, 0.9, 0.9));
        ImGui.pushStyleColor(ImGuiCol.ButtonActive, ImGui.vec4(0.8, 0.35, 1.0, 1.0));
        ImGui.pushStyleColor(ImGuiCol.Header, ImGui.vec4(0.4, 0.15, 0.6, 0.8));
        ImGui.pushStyleColor(ImGuiCol.HeaderHovered, ImGui.vec4(0.5, 0.25, 0.7, 0.9));
        ImGui.pushStyleColor(ImGuiCol.HeaderActive, ImGui.vec4(0.6, 0.35, 0.8, 1.0));
        ImGui.pushStyleColor(ImGuiCol.CheckMark, ImGui.vec4(1.0, 0.4, 0.8, 1.0));
        ImGui.pushStyleColor(ImGuiCol.SliderGrab, ImGui.vec4(0.8, 0.4, 1.0, 1.0));
        ImGui.pushStyleColor(ImGuiCol.SliderGrabActive, ImGui.vec4(0.9, 0.5, 1.0, 1.0));
        ImGui.pushStyleColor(ImGuiCol.PlotLines, ImGui.vec4(0.8, 0.4, 1.0, 1.0));
        ImGui.pushStyleColor(ImGuiCol.PlotHistogram, ImGui.vec4(0.8, 0.4, 1.0, 1.0));
        
        // Cyberpunk style vars
        ImGui.pushStyleVar(ImGuiStyleVar.WindowRounding, 0);
        ImGui.pushStyleVar(ImGuiStyleVar.FrameRounding, 0);
        ImGui.pushStyleVar(ImGuiStyleVar.WindowBorderSize, 2);
        ImGui.pushStyleVar(ImGuiStyleVar.FrameBorderSize, 1);
        ImGui.pushStyleVar(ImGuiStyleVar.WindowPadding, ImGui.vec2(4, 4));
        ImGui.pushStyleVar(ImGuiStyleVar.FramePadding, ImGui.vec2(4, 2));
    }
    
    // === PASTEL THEME ===
    public static function applyPastelTheme():Void {
        ImGui.pushStyleColor(ImGuiCol.Text, ImGui.vec4(0.2, 0.18, 0.25, 1.0));
        ImGui.pushStyleColor(ImGuiCol.WindowBg, ImGui.vec4(0.95, 0.92, 0.98, 0.95));
        ImGui.pushStyleColor(ImGuiCol.TitleBg, ImGui.vec4(0.75, 0.65, 0.85, 0.95));
        ImGui.pushStyleColor(ImGuiCol.TitleBgActive, ImGui.vec4(0.85, 0.75, 0.95, 0.95));
        ImGui.pushStyleColor(ImGuiCol.Button, ImGui.vec4(0.7, 0.8, 0.9, 0.8));
        ImGui.pushStyleColor(ImGuiCol.ButtonHovered, ImGui.vec4(0.8, 0.9, 1.0, 0.9));
        ImGui.pushStyleColor(ImGuiCol.ButtonActive, ImGui.vec4(0.6, 0.7, 0.8, 1.0));
        ImGui.pushStyleColor(ImGuiCol.FrameBg, ImGui.vec4(0.85, 0.82, 0.90, 1.0));
        ImGui.pushStyleColor(ImGuiCol.FrameBgHovered, ImGui.vec4(0.90, 0.87, 0.95, 1.0));
        ImGui.pushStyleColor(ImGuiCol.FrameBgActive, ImGui.vec4(0.95, 0.92, 1.0, 1.0));
        
        // Pastel style vars
        ImGui.pushStyleVar(ImGuiStyleVar.WindowRounding, 12);
        ImGui.pushStyleVar(ImGuiStyleVar.ChildRounding, 8);
        ImGui.pushStyleVar(ImGuiStyleVar.FrameRounding, 8);
        ImGui.pushStyleVar(ImGuiStyleVar.PopupRounding, 8);
        ImGui.pushStyleVar(ImGuiStyleVar.ScrollbarRounding, 8);
        ImGui.pushStyleVar(ImGuiStyleVar.GrabRounding, 8);
        ImGui.pushStyleVar(ImGuiStyleVar.TabRounding, 8);
        ImGui.pushStyleVar(ImGuiStyleVar.WindowPadding, ImGui.vec2(12, 12));
        ImGui.pushStyleVar(ImGuiStyleVar.FramePadding, ImGui.vec2(8, 6));
        ImGui.pushStyleVar(ImGuiStyleVar.ItemSpacing, ImGui.vec2(10, 6));
    }
    
    // === CUSTOM THEME ===
    public static function applyCustomTheme():Void {
        // Apply all custom colors
        for (color in customColors.keys()) {
            ImGui.pushStyleColor(color, customColors[color]);
        }
        
        // Apply all custom style vars
        for (var in customVars.keys()) {
            var value = customVars[var];
            switch (var) {
                case ImGuiStyleVar.Alpha: ImGui.pushStyleVar(var, cast(value, Float));
                case ImGuiStyleVar.DisabledAlpha: ImGui.pushStyleVar(var, cast(value, Float));
                case ImGuiStyleVar.WindowRounding: ImGui.pushStyleVar(var, cast(value, Float));
                case ImGuiStyleVar.WindowBorderSize: ImGui.pushStyleVar(var, cast(value, Float));
                case ImGuiStyleVar.ChildRounding: ImGui.pushStyleVar(var, cast(value, Float));
                case ImGuiStyleVar.ChildBorderSize: ImGui.pushStyleVar(var, cast(value, Float));
                case ImGuiStyleVar.PopupRounding: ImGui.pushStyleVar(var, cast(value, Float));
                case ImGuiStyleVar.FrameRounding: ImGui.pushStyleVar(var, cast(value, Float));
                case ImGuiStyleVar.FrameBorderSize: ImGui.pushStyleVar(var, cast(value, Float));
                case ImGuiStyleVar.IndentSpacing: ImGui.pushStyleVar(var, cast(value, Float));
                case ImGuiStyleVar.ScrollbarSize: ImGui.pushStyleVar(var, cast(value, Float));
                case ImGuiStyleVar.ScrollbarRounding: ImGui.pushStyleVar(var, cast(value, Float));
                case ImGuiStyleVar.GrabMinSize: ImGui.pushStyleVar(var, cast(value, Float));
                case ImGuiStyleVar.GrabRounding: ImGui.pushStyleVar(var, cast(value, Float));
                case ImGuiStyleVar.TabRounding: ImGui.pushStyleVar(var, cast(value, Float));
                case ImGuiStyleVar.TabBorderSize: ImGui.pushStyleVar(var, cast(value, Float));
                case ImGuiStyleVar.WindowPadding: ImGui.pushStyleVar(var, cast(value, ImVec2));
                case ImGuiStyleVar.WindowTitleAlign: ImGui.pushStyleVar(var, cast(value, ImVec2));
                case ImGuiStyleVar.FramePadding: ImGui.pushStyleVar(var, cast(value, ImVec2));
                case ImGuiStyleVar.ItemSpacing: ImGui.pushStyleVar(var, cast(value, ImVec2));
                case ImGuiStyleVar.ItemInnerSpacing: ImGui.pushStyleVar(var, cast(value, ImVec2));
                default: // Other style vars
            }
        }
    }
    
    // === THEME SELECTOR UI ===
    public static function drawThemeSelector():Void {
        var themes = ["dark", "light", "classic", "cyberpunk", "pastel", "custom"];
        var current = currentTheme;
        
        ImGui.separatorText("Theme");
        ImGui.text("Select a theme:");
        
        var cols = 3;
        for (i in 0...themes.length) {
            if (i > 0 && i % cols != 0) ImGui.sameLine();
            var name = themes[i];
            var label = name.charAt(0).toUpperCase() + name.substr(1);
            if (ImGui.button(label + (current == name ? " ✓" : ""))) {
                applyTheme(name);
            }
        }
        
        ImGui.separatorText("Style Preview");
        drawStylePreview();
    }
    
    static function drawStylePreview():Void {
        ImGui.pushStyleVar(ImGuiStyleVar.FramePadding, ImGui.vec2(6, 4));
        
        // Button preview
        ImGui.text("Buttons:");
        ImGui.sameLine();
        ImGui.button("Normal");
        ImGui.sameLine();
        ImGui.button("Hovered");
        
        // Input preview
        ImGui.text("Input:");
        var buf = new hl.Bytes(64);
        ByteUtil.fillBuf(buf, 64, "Sample text");
        ImGui.sameLine();
        ImGui.inputText("##preview_input", buf, 64);
        
        // Checkbox preview
        ImGui.text("Checkbox:");
        var check = new BoolRef(true);
        ImGui.sameLine();
        ImGui.checkbox("##preview_check", check);
        
        // Slider preview
        ImGui.text("Slider:");
        var slider = new FloatRef(0.5);
        ImGui.sameLine();
        ImGui.sliderFloat("##preview_slider", slider, 0, 1, "%.2f");
        
        ImGui.popStyleVar();
    }
}
```

---

## 🎨 **COLOR PICKING - COMPLETE GUIDE**

### **4. Color Picker Features**

| Feature | Function | Code Example | Use Case |
|---------|----------|--------------|----------|
| **RGB Picker** | RGB sliders | `colorEdit3()` | Basic colors |
| **RGBA Picker** | RGB + Alpha | `colorEdit4()` | Colors with transparency |
| **HSV Picker** | Hue/Sat/Val | `colorEdit4(flags: ImGuiColorEditFlags.DisplayHSV)` | Color selection |
| **Hex Input** | Hex color | `colorEdit4(flags: ImGuiColorEditFlags.DisplayHex)` | Exact colors |
| **Color Button** | Color swatch | `colorButton()` | Quick color selection |
| **Color Palette** | Pre-defined colors | `colorButton()` | Quick access |
| **Alpha Bar** | Alpha slider | `ImGuiColorEditFlags.AlphaBar` | Transparency |
| **HDR Support** | High dynamic range | `ImGuiColorEditFlags.HDR` | Bright colors |
| **Picker Wheel** | Hue wheel | `ImGuiColorEditFlags.PickerHueWheel` | Intuitive picking |
| **No Inputs** | Hide sliders | `ImGuiColorEditFlags.NoInputs` | Compact picker |
| **No Alpha** | Hide alpha | `ImGuiColorEditFlags.NoAlpha` | Opaque colors |
| **No Drag Drop** | Disable drag | `ImGuiColorEditFlags.NoDragDrop` | Stability |

---

### **5. Color Picker Implementation**

```haxe
// ColorPickerSystem.hx - Complete color picker system
package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiColorEditFlags;
import imgui.Enums.ImGuiCol;
import imgui.Structs.ImVec4;
import imgui.ref.ColorRef;

class ColorPickerSystem {
    static var recentColors:Array<Int> = [];
    static var maxRecentColors = 12;
    static var paletteColors:Array<Int> = [
        0xFFFFFFFF, 0xFF000000, 0xFFFF0000, 0xFF00FF00, 0xFF0000FF,
        0xFFFFFF00, 0xFFFF00FF, 0xFF00FFFF, 0xFF884400, 0xFF448800,
        0xFF004488, 0xFF880044, 0xFF448844, 0xFF884444, 0xFF444488,
        0xFFCC8844, 0xFF44CC88, 0xFF8844CC
    ];
    
    /**
     * Complete color picker with all features
     */
    public static function colorPicker4(label:String, color:hl.Bytes, 
                                        flags:Int = 0, 
                                        showRecent:Bool = true,
                                        showPalette:Bool = true):Bool {
        var changed = false;
        var baseFlags = ImGuiColorEditFlags.AlphaBar | 
                       ImGuiColorEditFlags.AlphaPreviewHalf |
                       ImGuiColorEditFlags.PickerHueWheel;
        var combinedFlags = baseFlags | flags;
        
        // Main color picker
        if (ImGui.colorEdit4(label, color, combinedFlags)) {
            changed = true;
            if (showRecent) {
                var rgba = color.getUI32(0);
                addRecentColor(rgba);
            }
        }
        
        // Recent colors
        if (showRecent && recentColors.length > 0) {
            ImGui.separatorText("Recent Colors");
            drawColorPalette(recentColors, color, function(c) {
                var col = ImGui.vec4(
                    ((c >> 0) & 0xFF) / 255.0,
                    ((c >> 8) & 0xFF) / 255.0,
                    ((c >> 16) & 0xFF) / 255.0,
                    ((c >> 24) & 0xFF) / 255.0
                );
                color.setF32(0, col.x);
                color.setF32(4, col.y);
                color.setF32(8, col.z);
                color.setF32(12, col.w);
                changed = true;
            });
        }
        
        // Color palette
        if (showPalette) {
            ImGui.separatorText("Palette");
            drawColorPalette(paletteColors, color, function(c) {
                var col = ImGui.vec4(
                    ((c >> 0) & 0xFF) / 255.0,
                    ((c >> 8) & 0xFF) / 255.0,
                    ((c >> 16) & 0xFF) / 255.0,
                    ((c >> 24) & 0xFF) / 255.0
                );
                color.setF32(0, col.x);
                color.setF32(4, col.y);
                color.setF32(8, col.z);
                color.setF32(12, col.w);
                changed = true;
            });
        }
        
        return changed;
    }
    
    /**
     * Compact color picker (just a button)
     */
    public static function colorButtonCompact(label:String, color:hl.Bytes, 
                                              size:ImVec2 = null):Bool {
        if (size == null) size = ImGui.vec2(32, 32);
        var col = ImGui.vec4(
            color.getF32(0),
            color.getF32(4),
            color.getF32(8),
            color.getF32(12)
        );
        return ImGui.colorButton(label, col, 0, size);
    }
    
    /**
     * Draw a color palette