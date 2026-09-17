
---

## 🚀 **NEW FEATURES FROM UPGRADED IMGUI**

### **1. DOCKING & WORKSPACE (MAJOR UPGRADE)**

| Feature | Description | How It Helps Your Mod |
|---------|-------------|----------------------|
| **DockSpace** | Create a central docking area | Users can arrange Aura Builder, Geaux, Settings, Notebook, and Action Bar in a custom layout |
| **DockSpaceOverViewport** | Dock space fills entire viewport | Professional IDE-like workspace |
| **SetNextWindowDockID** | Programmatically dock windows | Your F6 hub can have default docking positions for each module |
| **IsWindowDocked** | Check if window is docked | Adapt UI behavior when docked vs floating |
| **GetWindowDockID** | Get current dock ID | Save/restore exact docking configurations |
| **Docking Persistence** | Auto-saves layout to `imgui.ini` | User's workspace layout survives game restarts |
| **DockNodeFlags** | Control docking behavior (split, resize, etc.) | Fine-tune how windows behave when docked |

**Impact:** Users can now have a single, unified workspace for all Solar Flare tools instead of overlapping windows.

---

### **2. DRAG & DROP (COMPLETE)**

| Feature | Description | How It Helps Your Mod |
|---------|-------------|----------------------|
| **BeginDragDropSource** | Start dragging an item | Drag auras from library to action bar |
| **SetDragDropPayload** | Attach data to drag operation | Transfer aura ID, skill ID, or arbitrary data |
| **AcceptDragDropPayload** | Accept dropped items | Reorder auras, assign skills to Geaux cells, swap action bar slots |
| **IsDragDropActive** | Check if drag is in progress | Show drop zone highlights |
| **GetDragDropPayload** | Access dropped data | Extract the dragged aura/skill data |
| **DragDropFlags** | Customize drag behavior | Control preview, accept conditions, payload expiration |

**Impact:** Drag auras between grids, reorder action bar buttons, assign skills to Geaux cells - all with visual feedback.

---

### **3. TAB BARS & TABS (ENHANCED)**

| Feature | Description | How It Helps Your Mod |
|---------|-------------|----------------------|
| **BeginTabBar** | Create tab container | F6 hub tabs (Resources, Geaux, Auras, Notebook, etc.) |
| **BeginTabItem** | Individual tab | Each module as a tab |
| **EndTabBar** | Close tab container | Clean tab management |
| **TabItemFlags** | Control tab behavior | Close buttons, reordering, tooltips |
| **SetTabItemClosed** | Programmatically close tab | Close tabs from code |
| **TabBarFlags** | Tab bar options | Reorderable tabs, popup list, auto-select new tabs |

**Impact:** Your F6 hub can now have professional tabbed navigation with reorderable tabs.

---

### **4. TABLES (ADVANCED)**

| Feature | Description | How It Helps Your Mod |
|---------|-------------|----------------------|
| **TableSortSpecs** | Column sorting | Sort auras by name, type, cooldown, etc. |
| **TableSortSpecsGetSpecsCount** | Get sort count | Multi-column sorting support |
| **TableSortSpecsGetColumnIndex** | Get sorted column | Know which column is being sorted |
| **TableSortSpecsGetSortDirection** | Get sort direction | Ascending or descending |
| **TableSetColumnSortDirection** | Set sort direction | Programmatic sorting |
| **TableAngledHeadersRow** | Angled headers | Compact table headers |
| **TableGetHoveredColumn** | Detect hovered column | Interactive table headers |
| **TableSetColumnEnabled** | Enable/disable columns | User can hide columns they don't need |

**Impact:** Sortable aura library, Geaux skill catalog, and action bar button list.

---

### **5. MULTI-SELECT (NEW)**

| Feature | Description | How It Helps Your Mod |
|---------|-------------|----------------------|
| **BeginMultiSelect** | Start multi-select mode | Select multiple auras at once |
| **EndMultiSelect** | End multi-select mode | Process selection changes |
| **SetNextItemSelectionUserData** | Tag items | Identify which items are selected |
| **MultiSelectFlags** | Control selection behavior | Single select, range select, box select, clear on escape |

**Impact:** Batch delete, enable/disable, or export multiple auras at once.

---

### **6. PROGRESS BARS (NEW)**

| Feature | Description | How It Helps Your Mod |
|---------|-------------|----------------------|
| **ProgressBar** | Full progress bar widget | Health bars, loading screens, cooldown progress, resource tracking |

**Impact:** Your Geaux cooldown indicators and resource bars are now built-in widgets.

---

### **7. INPUT TEXT (ENHANCED)**

| Feature | Description | How It Helps Your Mod |
|---------|-------------|----------------------|
| **InputTextWithHint** | Text input with placeholder | Search bars with "Search..." hint |
| **InputTextMultiline** | Multi-line text input | Notebook editor, aura script editor |
| **InputTextFlags** | More flags | Password mode, auto-select all, word wrap, callbacks |
| **InputTextCallback** | Real-time text validation | Live script validation in aura condition editor |

**Impact:** Better search bars, notebook editor, and script editing experience.

---

### **8. CHILD WINDOWS (ENHANCED)**

| Feature | Description | How It Helps Your Mod |
|---------|-------------|----------------------|
| **ChildFlags** | New child window flags | Resizable child windows, auto-resize, frame style |
| **BeginChild** | Enhanced child windows | Your three-pane Geaux builder layout |

**Impact:** Better responsive layouts and resize behavior.

---

### **9. SELECTABLES (ENHANCED)**

| Feature | Description | How It Helps Your Mod |
|---------|-------------|----------------------|
| **SelectableFlags** | More flags | Span all columns, disabled, highlight, allow double-click |
| **IsItemToggledSelection** | Check selection toggle | Track selection state in lists |

**Impact:** Better aura and skill list interaction.

---

### **10. COLOR PICKER (ENHANCED)**

| Feature | Description | How It Helps Your Mod |
|---------|-------------|----------------------|
| **ColorEditFlags** | More options | Alpha bar, HDR, no inputs, color markers |
| **ColorPicker4** | Full color picker | Custom aura colors, Geaux style colors |
| **ColorButton** | Color swatch button | Quick color selection |

**Impact:** Better theme customization and visual state configuration.

---

### **11. STYLING (EXPANDED)**

| Feature | Description | How It Helps Your Mod |
|---------|-------------|----------------------|
| **ImGuiStyleVar** | More style variables | Tab rounding, tree lines, separator sizes, selectable rounding |
| **PushStyleVar/PopStyleVar** | More style types | Table angled headers, menu item rounding |
| **Theme System** | Full theme support | Dark Pastel, Classic, Light themes |
| **StyleVarInfo** | Get style information | Debug and introspection |

**Impact:** More polished, professional-looking UI with finer control.

---

### **12. DRAW LIST (ENHANCED)**

| Feature | Description | How It Helps Your Mod |
|---------|-------------|----------------------|
| **AddBezierCubic** | Bezier curves | Smooth connector lines in visual condition builder |
| **AddBezierQuadratic** | Quadratic curves | Smoother graph lines |
| **AddEllipse** | Ellipse drawing | Circular combo indicators |
| **AddNgon** | Polygon drawing | Custom shapes for skill icons |
| **AddLineH/V** | Horizontal/Vertical lines | Decorative separators |
| **AddConcavePolyFilled** | Concave polygons | Complex shape rendering |
| **AddImageRounded** | Rounded images | Rounded icon corners |

**Impact:** Professional visual effects, combo trackers, and custom widgets.

---

### **13. PLOTTING (ENHANCED)**

| Feature | Description | How It Helps Your Mod |
|---------|-------------|----------------------|
| **PlotLines** | Line graphs | DPS/HPS history, resource tracking |
| **PlotHistogram** | Bar charts | Damage breakdown, cooldown usage |

**Impact:** Performance monitoring, resource tracking graphs.

---

### **14. SHORTCUTS & KEYBOARD**

| Feature | Description | How It Helps Your Mod |
|---------|-------------|----------------------|
| **Shortcut** | Keyboard shortcut system | Custom key bindings for actions |
| **SetNextItemShortcut** | Per-item shortcuts | Keyboard shortcuts for buttons |
| **SetKeyOwner** | Key ownership system | Prevent key conflicts between mods |

**Impact:** Power user keyboard shortcuts for all actions.

---

### **15. VIEWPORT & SCALING**

| Feature | Description | How It Helps Your Mod |
|---------|-------------|----------------------|
| **GetMainViewport** | Get viewport info | Responsive layouts |
| **SetNextWindowViewport** | Set viewport for window | Multi-monitor support |
| **GetWindowViewport** | Get window's viewport | Docking across monitors |

**Impact:** Better multi-monitor support and responsive layouts.

---

### **16. TOOLTIPS (ENHANCED)**

| Feature | Description | How It Helps Your Mod |
|---------|-------------|----------------------|
| **BeginItemTooltip** | Item-specific tooltips | Help text for UI elements |
| **BeginTooltipEx** | Extended tooltip control | Custom tooltip positioning, flags |
| **SetItemTooltip** | Quick tooltip | Simple hover help |

**Impact:** Better user education and discoverability.

---

### **17. LOGGING & DEBUG (ENHANCED)**

| Feature | Description | How It Helps Your Mod |
|---------|-------------|----------------------|
| **ShowDebugLogWindow** | Debug log viewer | See internal log messages |
| **ShowMetricsWindow** | Performance metrics | FPS, draw calls, memory usage |
| **ShowIDStackTool** | ID stack debugger | Debug UI ID conflicts |
| **DebugLog** | Logging API | Send debug messages |
| **DebugCheckVersionAndDataLayout** | Version check | Ensure DLL compatibility |

**Impact:** Better debugging and performance monitoring.

---

### **18. FONTS & TEXT (ENHANCED)**

| Feature | Description | How It Helps Your Mod |
|---------|-------------|----------------------|
| **PushFont/PopFont** | Font stacks | Different font sizes in the same window |
| **AddFontFromFileTTF** | Load custom fonts | Custom fonts, icon fonts, CJK support |
| **AddFontFromMemoryTTF** | Load fonts from memory | Embedded font support |
| **FontFlags** | Font options | Bold, italic, no hinting |

**Impact:** Custom fonts, icon fonts, better readability.

---

### **19. COMBO BOX (ENHANCED)**

| Feature | Description | How It Helps Your Mod |
|---------|-------------|----------------------|
| **BeginCombo** | Enhanced combo box | Better dropdowns with preview |
| **ComboFlags** | More flags | Height control, no arrow, no preview, width fit |
| **EndCombo** | Close combo | Cleaner combo management |

**Impact:** Better dropdown menus for settings.

---

### **20. LIST BOX (ENHANCED)**

| Feature | Description | How It Helps Your Mod |
|---------|-------------|----------------------|
| **BeginListBox** | Enhanced list box | Better list selection UI |
| **EndListBox** | Close list box | Clean list management |

**Impact:** Better aura and skill selection lists.

---

## 📊 **SUMMARY TABLE - FEATURES BY CATEGORY**

| Category | New Features | Priority for Your Mod |
|----------|--------------|----------------------|
| **Docking** | 7 features | 🔴 HIGH |
| **Drag & Drop** | 6 features | 🔴 HIGH |
| **Tables** | 8 features | 🔴 HIGH |
| **Multi-Select** | 4 features | 🟡 MEDIUM |
| **Progress Bars** | 1 feature | 🟡 MEDIUM |
| **Input Text** | 4 features | 🟡 MEDIUM |
| **Color Picker** | 3 features | 🟢 LOW |
| **Styling** | 4 features | 🟢 LOW |
| **Draw List** | 7 features | 🟢 LOW |
| **Plots** | 2 features | 🟢 LOW |
| **Shortcuts** | 3 features | 🟡 MEDIUM |
| **Fonts** | 4 features | 🟢 LOW |

---

## 🎯 **WHAT YOU CAN NOW BUILD**

1. **IDE-Style Workspace** - Dockable tool windows with tabs
2. **Drag & Drop UI** - Reorder auras, assign skills, swap action bar buttons
3. **Professional Tables** - Sortable, filterable, resizable data views
4. **Batch Operations** - Select and act on multiple auras at once
5. **Visual Effects** - Glowing rings, pulsing borders, animated icons
6. **Custom Widgets** - Combo trackers, progress rings, health bars
7. **Keyboard Shortcuts** - Full keyboard navigation
8. **Custom Themes** - Multiple color schemes and visual styles
9. **Better Input** - Autocomplete, multi-line editing, password fields
10. **Performance Metrics** - FPS counter, draw call monitor

