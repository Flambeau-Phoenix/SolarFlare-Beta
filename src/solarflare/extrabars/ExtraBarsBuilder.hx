package solarflare.extrabars;

import imgui.ImGui;
import imgui.Enums.ImGuiWindowFlags;
import imgui.Enums.ImGuiChildFlags;
import imgui.Enums.ImGuiTableFlags;
import imgui.Enums.ImGuiTableColumnFlags;
import imgui.Enums.ImGuiStyleVar;
import imgui.Enums.ImGuiCol;
import imgui.ref.BoolRef;
import imgui.ref.IntRef;
import imgui.ref.FloatRef;
import solarflare.ui.EditorWindow;
import solarflare.ui.UiLayout;
import solarflare.ui.UiScope;
import solarflare.ui.UiChrome;
import solarflare.ui.ByteUtil;
import solarflare.ui.SearchBar;
import solarflare.ui.SettingsStore;
import solarflare.ui.UndoManager;
import solarflare.ui.ContextMenuSystem;
import solarflare.extrabars.ExtraBarsConfig.ExtraBarsBarConfig;
using solarflare.ui.DragDropHelper.PayloadExt;

/** Resizable release editor. All refs and text/payload buffers have persistent owners. */
class ExtraBarsBuilder {
 var owner:ExtraBars;
 var selectedBar = "bar1";
 var selectedCell = 0;
 var history = new UndoManager<Dynamic>(50);
 var boolRef = new BoolRef(false);
 var intRef = new IntRef(1);
 var floatRef = new FloatRef(1);
 var allBars = new BoolRef(false);
 var inventoryOnly = new BoolRef(true);
 var search = new SearchBar("Search consumables");
 var nameBuf = new hl.Bytes(192);
 var sparkHotkeyBuf = new hl.Bytes(192);
 var sparkHotkeySynced = false;
 var pendingSparkHotkey = "";
 var dragBuf = new hl.Bytes(512);
 var nameOwner = "";
 var pendingName = "";
 var gestureBefore:Dynamic;
 var gestureAction = "";
 public function new(owner:ExtraBars) { this.owner = owner; ByteUtil.clearBytes(nameBuf,192); ByteUtil.clearBytes(sparkHotkeyBuf,192); ByteUtil.clearBytes(dragBuf,512); }
 public function clearTransientState():Void { nameOwner = ""; sparkHotkeySynced = false; gestureBefore = null; gestureAction = ""; }
 public function clearHistory():Void { history = new UndoManager<Dynamic>(50); clearTransientState(); }
 public function selectBar(id:String):Void { selectedBar = id; selectedCell = 0; nameOwner = ""; }
 public function change(action:String, mutate:Void->Void):Void {
  history.push(action,owner.model.dump()); mutate(); changed();
 }
 function changed():Void { owner.clearTransientState(); SettingsStore.markDirty(); solarflare.ObserveDemand.markStatusDemandDirty(); }
 function restore(data:Dynamic):Void { owner.model.apply(data); changed(); }
 function check(label:String,value:Bool,set:Bool->Void):Void {
  boolRef.set(value); if (ImGui.checkbox(label,boolRef)) change(label,function() set(boolRef.get()));
 }
 // A drag or typed slider edit is one undo step, even when it spans many frames.
 function slider(label:String,value:Int,min:Int,max:Int,set:Int->Void):Void {
  intRef.set(value); var before = owner.model.dump();
  ImGui.setNextItemWidth(Math.min(260,ImGui.getContentRegionAvail().x));
  if (ImGui.sliderInt(label,intRef,min,max)) {
   if (gestureBefore == null) { gestureBefore = before; gestureAction = label; }
   set(intRef.get()); SettingsStore.markDirty();
  }
  if (gestureBefore != null && !ImGui.isAnyItemActive()) {
   history.push(gestureAction,gestureBefore); gestureBefore = null; changed();
  }
 }
 public function draw():Void {
  if (!owner.open.get()) return;
  EditorWindow.drawMenuWindow("ExtraBars###SolarFlare.ExtraBars.Builder",owner.open,980,840,drawReadableBody);
 }
 function drawReadableBody():Void {
  var theme=solarflare.ui.ThemePalette.current();
  var font=ImGui.getFont();
  if (font!=null) ImGui.pushFont(font,Math.max(16,ImGui.getFontSize()*1.15));
  // Calm property groups: section structure carries hierarchy instead of alternating stripes.
  ImGui.pushStyleColor(ImGuiCol.TableRowBg,ImGui.vec4(0,0,0,0));
  ImGui.pushStyleColor(ImGuiCol.TableRowBgAlt,ImGui.vec4(0,0,0,0));
  ImGui.pushStyleColor(ImGuiCol.TableBorderLight,ImGui.vec4(0,0,0,0));
  ImGui.pushStyleColor(ImGuiCol.TableBorderStrong,ImGui.vec4(0,0,0,0));
  ImGui.pushStyleColor(ImGuiCol.TextDisabled,ImGui.vec4(
   theme.text.x*0.8+theme.windowBg.x*0.2,theme.text.y*0.8+theme.windowBg.y*0.2,theme.text.z*0.8+theme.windowBg.z*0.2,1));
  ImGui.pushStyleVar(ImGuiStyleVar.FramePadding,ImGui.vec2(8,5));
  try {
   UiChrome.heading("ExtraBars",1.45);
   owner.drawCapture();
   history.drawButtons(owner.model.dump(),restore);
   ImGui.sameLine(); if (ImGui.button("Save")) solarflare.ui.UiActionQueue.save();
   ImGui.sameLine(); if (ImGui.button("Close editors and test")) owner.closeEditors();
   ImGui.textWrapped(owner.characterAvailable
    ? owner.characterLabel + " / Setup saved automatically for this character."
    : "Character unavailable. Keeping the last setup until a character is identified.");
   ImGui.spacing();
   drawPages();
   drawBuilderContext();
  } catch(e:Dynamic) {
   ImGui.popStyleVar(); ImGui.popStyleColor(5); if (font!=null) ImGui.popFont(); throw e;
  }
  ImGui.popStyleVar(); ImGui.popStyleColor(5); if (font!=null) ImGui.popFont();
 }
 function focusPanel(id:String,title:String,draw:Void->Void):Void {
  var theme=solarflare.ui.ThemePalette.current();
  ImGui.pushStyleColor(ImGuiCol.ChildBg,theme.windowBg);
  ImGui.pushStyleColor(ImGuiCol.Border,theme.accent);
  ImGui.pushStyleVar(ImGuiStyleVar.ChildRounding,8);
  ImGui.pushStyleVar(ImGuiStyleVar.ChildBorderSize,1.2);
  ImGui.pushStyleVar(ImGuiStyleVar.WindowPadding,ImGui.vec2(12,12));
  try {
   UiScope.child(id,ImGui.vec2(0,0),function() {
    UiChrome.centeredHeader(title,40); draw(); drawBuilderContext();
   },ImGuiChildFlags.Borders|ImGuiChildFlags.AutoResizeY|ImGuiChildFlags.AlwaysUseWindowPadding);
  } catch(e:Dynamic) { ImGui.popStyleVar(3); ImGui.popStyleColor(2); throw e; }
  ImGui.popStyleVar(3); ImGui.popStyleColor(2);
 }
 function modeChoice(mode:String,width:Single):Void {
  var theme=solarflare.ui.ThemePalette.current();
  var selected=owner.model.mode==mode;
  var clicked=ImGui.invisibleButton("##extra_mode_"+mode,ImGui.vec2(width,68));
  var hovered=ImGui.isItemHovered(); var pos=ImGui.getItemRectMin(); var max=ImGui.getItemRectMax();
  var dl=ImGui.getWindowDrawList();
  var tint:Single=selected?0.16:(hovered?0.08:0);
  ImGui.ImDrawList_AddRectFilled(dl,pos,max,ImGui.colorConvertFloat4ToU32(ImGui.vec4(
   theme.cellBg.x*(1-tint)+theme.accent.x*tint,theme.cellBg.y*(1-tint)+theme.accent.y*tint,theme.cellBg.z*(1-tint)+theme.accent.z*tint,1)),6);
  ImGui.ImDrawList_AddRect(dl,pos,max,ImGui.colorConvertFloat4ToU32(selected||hovered?theme.accent:theme.border),6,selected?2:1);
  var font=ImGui.getFont();
  if (font!=null) ImGui.pushFont(font,ImGui.getFontSize()*1.35);
  try {
   var title=ExtraBarsActivationConfig.modeLabel(mode); var ts=ImGui.calcTextSize(title);
   ImGui.ImDrawList_AddText_Vec2(dl,ImGui.vec2(pos.x+(width-ts.x)/2,pos.y+8),ImGui.colorConvertFloat4ToU32(theme.text),title);
  } catch(e:Dynamic) { if (font!=null) ImGui.popFont(); throw e; }
  if (font!=null) ImGui.popFont();
  var hint=mode=="hold"?"While held":"Press to switch"; var ts=ImGui.calcTextSize(hint);
  ImGui.ImDrawList_AddText_Vec2(dl,ImGui.vec2(pos.x+(width-ts.x)/2,pos.y+39),ImGui.colorConvertFloat4ToU32(theme.text),hint);
  if (selected) ImGui.ImDrawList_AddLine(dl,ImGui.vec2(pos.x+12,max.y-4),ImGui.vec2(max.x-12,max.y-4),ImGui.colorConvertFloat4ToU32(theme.accent),2);
  if (clicked && !selected) change("Mode",function() owner.model.mode=mode);
 }
 function prominentButton(label:String,width:Single):Bool {
  var theme=solarflare.ui.ThemePalette.current();
  ImGui.pushStyleColor(ImGuiCol.Border,theme.accent);
  ImGui.pushStyleVar(ImGuiStyleVar.FrameBorderSize,1.5);
  var clicked=false;
  try { clicked=ImGui.button(label,ImGui.vec2(width,42)); }
  catch(e:Dynamic) { ImGui.popStyleVar(); ImGui.popStyleColor(); throw e; }
  ImGui.popStyleVar(); ImGui.popStyleColor();
  return clicked;
 }
	function hasItems(bar:ExtraBarsBarConfig):Bool {
	 if (bar == null) return false;
	 for (slot in bar.slots) if (slot.itemKind.length > 0) return true;
	 return false;
	}
	function clearItem(bar:ExtraBarsBarConfig, index:Int):Void {
	 if (bar == null || index < 0 || index >= bar.slotCount || bar.slots[index].itemKind.length == 0) return;
	 change("Clear Item",function() owner.model.clearItem(bar.id,index));
	}
	function clearAll(bar:ExtraBarsBarConfig):Void {
	 if (!hasItems(bar)) return;
	 change("Clear All Items",function() owner.model.clearItems(bar.id));
	}
	function drawCellContext(bar:ExtraBarsBarConfig, index:Int, popup:String):Void {
	 if (!ContextMenuSystem.begin(popup)) return;
	 try {
	  ImGui.textDisabled(bar.name+" / Cell "+(index+1));
	  if (ContextMenuSystem.menuItem("Record Key", "", "", false, index >= 0 && index < bar.slotCount)) owner.startCapture(bar.id,index);
	  if (ContextMenuSystem.menuItem("Clear Item", "", "", false, bar.slots[index].itemKind.length > 0)) clearItem(bar,index);
	  if (ContextMenuSystem.menuItem("Clear Key", "", "", false, bar.slots[index].keyCode != 0 || bar.slots[index].modifiers != 0))
	   change("Clear Key",function() { bar.slots[index].keyCode=0; bar.slots[index].modifiers=0; });
	  ImGui.separator();
	  if (ContextMenuSystem.menuItem("Clear All Items in This Bar", "", "", false, hasItems(bar))) clearAll(bar);
	 } catch(e:Dynamic) { ContextMenuSystem.end(); throw e; }
	 ContextMenuSystem.end();
	}
	function drawBuilderContext():Void {
	 if (!ImGui.beginPopupContextWindow("##extra_builder_context",
	   imgui.Enums.ImGuiPopupFlags.MouseButtonRight | imgui.Enums.ImGuiPopupFlags.NoOpenOverItems)) return;
	 try {
	  var bar = owner.model.find(selectedBar);
	  var valid = bar != null && selectedCell >= 0 && selectedCell < bar.slotCount;
	  if (ImGui.menuItem("Clear Item", null, false, valid && bar.slots[selectedCell].itemKind.length > 0)) clearItem(bar,selectedCell);
	  if (ImGui.menuItem("Clear All Items in This Bar", null, false, hasItems(bar))) clearAll(bar);
	  ImGui.separator();
	  if (ImGui.menuItem("Undo", null, false, history.canUndo())) { var data=history.undo(owner.model.dump()); if (data!=null) restore(data); }
	  if (ImGui.menuItem("Redo", null, false, history.canRedo())) { var data=history.redo(owner.model.dump()); if (data!=null) restore(data); }
	  if (ImGui.menuItem("Save")) solarflare.ui.UiActionQueue.save();
	 } catch(e:Dynamic) { ImGui.endPopup(); throw e; }
	 ImGui.endPopup();
	}
 function drawPages():Void {
  if (ImGui.beginTabBar("##extra_pages",imgui.Enums.ImGuiTabBarFlags.DrawSelectedOverline)) {
   try {
    for (i in [0,2,3]) {
     var label=["Bars","Activation","Spark Cube","Diagnostics"][i];
     if (beginPageTab(label+"##extra_page_"+i)) {
      try {
       switch(i) {
        case 0: drawBars();
        case 2: drawSpark();
        default: drawDiagnostics();
       }
      } catch(e:Dynamic) { ImGui.endTabItem(); throw e; }
      ImGui.endTabItem();
     }
    }
   } catch(e:Dynamic) { ImGui.endTabBar(); throw e; }
   ImGui.endTabBar();
  }
 }
 function beginPageTab(label:String):Bool return UiChrome.beginTabItem(label);
 function drawDiagnostics():Void {
  UiChrome.subHeader("Runtime status");
  ImGui.textWrapped(owner.gate.length>0?owner.gate:"Gameplay eligible.");
  ImGui.textWrapped(owner.lastResult);
  ImGui.textWrapped("Prefix: "+ExtraBarsActivationConfig.prefixLabel(owner.model.prefix)+" / Mode: "+ExtraBarsActivationConfig.modeLabel(owner.model.mode));
  drawBarOverview();
 }
 function drawBarOverview():Void {
  UiChrome.subHeader("Configured bars");
  UiScope.child("##extra_bar_overview",ImGui.vec2(0,Math.max(100,ImGui.getContentRegionAvail().y)),function() {
   for (bar in owner.model.bars) {
    var assigned=0; for (i in 0...bar.slotCount) if (bar.slots[i].itemKind.length>0) assigned++;
    ImGui.text(bar.name+" / "+(bar.enabled?"Enabled":"Disabled")+(bar.hidden?" / Hidden":""));
    ImGui.textDisabled(assigned+" of "+bar.slotCount+" cells assigned / "+bar.rows+" x "+bar.columns);
    ImGui.separator();
   }
   if (owner.model.bars.length==0) ImGui.textDisabled("No bars. Add one on the Bars tab.");
  });
 }
 function drawActivation():Void {
   UiLayout.inlinePair("##extra_mode_choices",function(w:Single) modeChoice("hold",w),function(w:Single) modeChoice("toggle",w),8);
   ImGui.textWrapped(owner.model.mode=="hold"
    ? "Hold the activation modifier, then press a cell's key."
    : owner.model.mode=="toggle" ? "Press the activation modifier once, then use cell keys. Press it again to turn the bars off."
    : "Choose Hold or Toggle to replace the retired Long-press mode.");
   UiLayout.propertyGrid("##extra_activation",function() {
    UiLayout.propertyRow("All bars enabled",function() check("##extra_master",owner.model.enabled,function(v) owner.model.enabled=v));
    var activeBar=owner.model.find(selectedBar);
    if (activeBar!=null) UiLayout.propertyRow("This bar enabled",function() check("##bar_enabled",activeBar.enabled,function(v) activeBar.enabled=v));
    UiLayout.propertyRow("Modifier key",function() {
     ImGui.setNextItemWidth(Math.min(220,ImGui.getContentRegionAvail().x));
     if (ImGui.beginCombo("##extra_prefix",ExtraBarsActivationConfig.prefixLabel(owner.model.prefix))) {
      try { for (prefix in ExtraBarsActivationConfig.prefixes) if (ImGui.selectable(ExtraBarsActivationConfig.prefixLabel(prefix),owner.model.prefix==prefix)) change("Prefix",function() owner.model.prefix=prefix); }
      catch(e:Dynamic) { ImGui.endCombo(); throw e; } ImGui.endCombo();
     }
    });
   });
   if (!owner.model.enabled || owner.model.prefix=="off") ImGui.textWrapped("Bars are off. Enable them and choose an activation modifier to use cell keys.");
   else { var activeBar=owner.model.find(selectedBar); if (activeBar!=null && !activeBar.enabled) ImGui.textWrapped("This bar is disabled. Enable it above to use its cells."); }
 }
 function drawKeybind(bar:ExtraBarsBarConfig):Void {
  if (bar==null || selectedBar!=bar.id || selectedCell<0 || selectedCell>=bar.slotCount) {
   ImGui.textWrapped("Add a bar, then select a preview cell to record its key."); return;
  }
  var slot=bar.slots[selectedCell]; var frozen=owner.views.get(bar.id);
  UiChrome.heading(ExtraBarsKeyMap.label(slot.keyCode,slot.modifiers),1.65);
  ImGui.textWrapped("Cell "+(selectedCell+1)+" / "+bar.name);
  UiLayout.inlinePair("##extra_cell_actions",function(w:Single) {
   if (prominentButton("Record Key##extra_record_key",w)) owner.startCapture(bar.id,selectedCell);
  },function(w:Single) {
   if (ImGui.button("Clear Key##extra_clear_key",ImGui.vec2(w,42))) change("Clear key",function() { slot.keyCode=0; slot.modifiers=0; });
  },8);
  if (owner.captureMessage.length>0) ImGui.textWrapped(owner.captureMessage);
  if (frozen!=null && frozen[selectedCell].reason.length>0 && frozen[selectedCell].reason!=owner.gate) ImGui.textWrapped(frozen[selectedCell].reason);
  if (slot.keyCode!=0 && owner.model.enabled && owner.model.prefix!="off") ImGui.textWrapped("Use "+ExtraBarsActivationConfig.prefixLabel(owner.model.prefix)
   +(owner.model.mode=="hold"?" + ":" then ")+ExtraBarsKeyMap.label(slot.keyCode,slot.modifiers)+" ("+ExtraBarsActivationConfig.modeLabel(owner.model.mode)+").");
  else if (slot.keyCode!=0) ImGui.textWrapped("Activation is off. This key assignment is kept.");
  else ImGui.textWrapped("Select a preview cell, then record a plain key.");
  if (owner.suggestions.length>0) ImGui.textWrapped("Unbound alternatives: "+owner.suggestions);
 }
 function drawBars():Void {
   var bar = owner.model.find(selectedBar);
   if (bar == null && owner.model.bars.length > 0) { selectBar(owner.model.bars[0].id); bar = owner.model.bars[0]; }
   UiLayout.inlineSplit("##extra_bar_actions",3,function(i,w) {
    if (i==0) {
     if (ImGui.beginCombo("##extra_bar",bar!=null?bar.name:"No bars")) {
      try { for (candidate in owner.model.bars) if (ImGui.selectable(candidate.name+"###select_"+candidate.id,selectedBar==candidate.id)) selectBar(candidate.id); }
      catch(e:Dynamic) { ImGui.endCombo(); throw e; } ImGui.endCombo();
     }
    } else if (i==1) { if (ImGui.button("Add bar",ImGui.vec2(w,0))) change("Add bar",function() selectBar(owner.model.addBar().id)); }
    else if (bar!=null && ImGui.button("Remove bar",ImGui.vec2(w,0))) change("Remove bar",function() { owner.model.removeBar(bar.id); selectedBar=""; });
   });
   // Navigation can select another bar in this frame.
   bar = owner.model.find(selectedBar);
   if (bar!=null && selectedCell>=bar.slotCount) selectedCell=bar.slotCount-1;
   if (UiChrome.groupHeader("Activation and cell keybind##extra_setup_group",true)) {
    if (ImGui.getContentRegionAvail().x>=720) {
     UiLayout.inlinePair("##extra_primary_setup",function(_:Single) {
      focusPanel("##extra_activation_focus","Activation / all bars",drawActivation);
     },function(_:Single) {
      focusPanel("##extra_keybind_focus","Cell keybind",function() drawKeybind(bar));
     },12);
    } else {
     focusPanel("##extra_activation_focus","Activation / all bars",drawActivation);
     focusPanel("##extra_keybind_focus","Cell keybind",function() drawKeybind(bar));
    }
   }
   ImGui.spacing();
   if (bar != null) {
    if (selectedCell >= bar.slotCount) selectedCell = bar.slotCount-1;
    var available=ImGui.getContentRegionAvail();
    if (available.x>=720) {
     var height:Single=Math.max(260,available.y-4);
     UiScope.table("##extra_bar_workspace",2,function() {
      ImGui.tableSetupColumn("Layout",ImGuiTableColumnFlags.WidthStretch,0.42);
      ImGui.tableSetupColumn("Cell",ImGuiTableColumnFlags.WidthStretch,0.58);
      ImGui.tableNextRow(); ImGui.tableSetColumnIndex(0);
      UiScope.child("##extra_layout",ImGui.vec2(0,height),function() { drawBarLayout(bar); drawBuilderContext(); });
      ImGui.tableSetColumnIndex(1);
      UiScope.child("##extra_cell_editor",ImGui.vec2(0,height),function() { drawCell(bar); drawBuilderContext(); });
     },ImGuiTableFlags.SizingStretchProp|ImGuiTableFlags.NoSavedSettings);
    } else {
     drawBarLayout(bar);
     drawCell(bar);
    }
   }
 }
 function drawBarLayout(bar:ExtraBarsBarConfig):Void {
  UiChrome.centeredHeader("Layout & look",36);
  UiLayout.propertyGrid("##extra_bar_geometry",function() {
   UiLayout.propertyRow("Cells",function() {
    if (ImGui.beginCombo("##bar_cells",Std.string(bar.slotCount))) {
     try { for (n in 1...11) if (ImGui.selectable(Std.string(n),bar.slotCount==n)) change("Cell count",function() bar.setCount(n)); }
     catch(e:Dynamic) { ImGui.endCombo(); throw e; } ImGui.endCombo();
    }
   });
   UiLayout.propertyRow("Rows",function() slider("##bar_rows",bar.rows,1,bar.slotCount,function(v) bar.setRows(v)));
   UiLayout.propertyRow("Columns",function() slider("##bar_columns",bar.columns,1,bar.slotCount,function(v) bar.setColumns(v)));
  });
  ImGui.textWrapped("Move the sliders to shape this bar. Rows and columns are linked.");
  UiLayout.inlineSplit("##bar_presets",4,function(i,w) {
   var cols=[bar.slotCount,Std.int(Math.ceil(bar.slotCount/2)),2,1][i]; cols=Std.int(Math.min(cols,bar.slotCount));
   var rows=ExtraBarsLayout.rows(bar.slotCount,cols);
   if (ImGui.button(rows+" x "+cols+"##preset_"+i,ImGui.vec2(w,0))) change("Layout preset",function() bar.setColumns(cols));
  });
  ImGui.checkbox("Show all bars for swapping",allBars);
  ImGui.textWrapped("Select a cell below to edit its key and item. Right-click for actions.");
  var height=ExtraBarsLayout.rows(bar.slotCount,bar.columns)*44+8;
  if (allBars.get()) height=180;
  UiScope.child("##extra_previews",ImGui.vec2(0,height),function() {
   if (allBars.get()) { for (candidate in owner.model.bars) { ImGui.text(candidate.name); preview(candidate); } }
   else preview(bar);
  },0,ImGuiWindowFlags.HorizontalScrollbar);
  ImGui.spacing(); UiChrome.centeredHeader("Appearance",32);
  drawProperties(bar);
  ImGui.textWrapped("Hidden cells retain their assignments. Hidden bars retain keybinds.");
 }
 function drawSpark():Void {
   if (!sparkHotkeySynced) { ByteUtil.fillBuf(sparkHotkeyBuf,192,owner.model.sparkHotkeyLabel); pendingSparkHotkey=owner.model.sparkHotkeyLabel; sparkHotkeySynced=true; }
   UiChrome.heading("Spark Cube tracker");
   UiLayout.propertyGrid("##extra_spark",function() {
    UiLayout.propertyRow("Show tracker",function() check("##spark_enabled",owner.model.sparkEnabled,function(v) owner.model.sparkEnabled=v));
    UiLayout.propertyRow("Size",function() slider("##spark_size",owner.model.sparkSize,40,120,function(v) owner.model.sparkSize=v));
    UiLayout.propertyRow("Lock position",function() check("##spark_lock",owner.model.sparkLocked,function(v) owner.model.sparkLocked=v));
    UiLayout.propertyRow("Transparent",function() check("##spark_trans",owner.model.sparkTransparent,function(v) owner.model.sparkTransparent=v));
    UiLayout.propertyRow("Show hotkey",function() check("##spark_show_hotkey",owner.model.sparkShowHotkey,function(v) owner.model.sparkShowHotkey=v));
    UiLayout.propertyRow("Hotkey label",function() {
     if (ImGui.inputText("##spark_hotkey_label",sparkHotkeyBuf,192)) pendingSparkHotkey=ExtraBarsConfig.cleanHotkeyLabel(ByteUtil.readString(sparkHotkeyBuf,192));
     if (ImGui.isItemDeactivatedAfterEdit() && pendingSparkHotkey!=owner.model.sparkHotkeyLabel)
      change("Spark hotkey label",function() owner.model.sparkHotkeyLabel=pendingSparkHotkey);
    },"Display only. Type your in-game hotkey, such as Q or Ctrl+Q (up to 32 characters).");
   });
   ImGui.spacing();
   UiLayout.inlinePair("##extra_spark_cols",function(_:Single) {
    UiChrome.subHeader("Current observation");
    UiLayout.propertyGrid("##extra_spark_observation",function() {
     UiLayout.propertyRow("Cube",function() ImGui.text(owner.spark.label));
     UiLayout.propertyRow("Damage dealt",function() ImGui.text(owner.spark.state.started>=0 ? Std.string(owner.spark.state.observedDamage)+(owner.spark.state.partial?" *":"") : "Waiting for a Spark surge."));
     UiLayout.propertyRow("Last burst",function() ImGui.text(owner.spark.state.burstAt>=0 ? Std.string(owner.spark.state.burstDamage) : "Waiting for a burst."));
    });
   },function(_:Single) {
    UiChrome.subHeader("How it works");
    ImGui.textWrapped("Charged or empty. Click to use; refill at the Obelisks' waters. During Spark surge, see the countdown and damage dealt; afterward, see the burst result. Hover for details.");
    ImGui.textDisabled("These are observed game values. * indicates a partial observation. The tracker can stay enabled when the consumable bars are off.");
   },16);
 }
 function drawProperties(bar:ExtraBarsBarConfig):Void {
  if (nameOwner != bar.id) { ByteUtil.fillBuf(nameBuf,192,bar.name); pendingName=bar.name; nameOwner=bar.id; }
  UiLayout.propertyGrid("##extra_bar_properties",function() {
   UiLayout.propertyRow("Name",function() {
    if (ImGui.inputText("##extra_name",nameBuf,192)) pendingName=ByteUtil.readString(nameBuf,192,true);
    if (ImGui.isItemDeactivatedAfterEdit() && pendingName.length>0 && pendingName!=bar.name) change("Rename bar",function() bar.name=pendingName);
   });
   UiLayout.propertyRow("Visibility",function() check("Hidden##bar_hidden",bar.hidden,function(v) bar.hidden=v),"Keybinds still activate while this bar is hidden.");
   UiLayout.propertyRow("Cell size",function() slider("##bar_size",bar.slotSize,24,96,function(v) bar.slotSize=v));
   UiLayout.propertyRow("Lock position",function() check("##bar_lock",bar.locked,function(v) bar.locked=v));
   UiLayout.propertyRow("Transparent",function() check("##bar_trans",bar.transparent,function(v) bar.transparent=v));
   UiLayout.propertyRow("Opacity",function() {
    floatRef.set(bar.opacity); var before=owner.model.dump();
    ImGui.setNextItemWidth(Math.min(260,ImGui.getContentRegionAvail().x));
    if (ImGui.sliderFloat("##bar_opacity",floatRef,0.15,1,"%.2f")) {
     if (gestureBefore==null) { gestureBefore=before; gestureAction="Opacity"; }
     bar.opacity=floatRef.get(); SettingsStore.markDirty();
    }
    if (gestureBefore!=null && !ImGui.isAnyItemActive()) { history.push(gestureAction,gestureBefore); gestureBefore=null; changed(); }
   });
  });
 }
 function preview(bar:ExtraBarsBarConfig):Void {
  var slots = owner.views.get(bar.id); var p=ImGui.getCursorScreenPos(); var dl=ImGui.getWindowDrawList();
  var px = 40;
  for (i in 0...bar.slotCount) {
   var x:Single=p.x+(i%bar.columns)*(px+4); var y:Single=p.y+Std.int(i/bar.columns)*(px+4);
   ImGui.setCursorScreenPos(ImGui.vec2(x,y));
   if (ImGui.invisibleButton("##preview_"+bar.id+"_"+i,ImGui.vec2(px,px))) { selectedBar=bar.id; selectedCell=i; nameOwner=""; }
   var hovered=ImGui.isItemHovered();
   var popup="##extra_cell_context_"+bar.id+"_"+i;
   if (ContextMenuSystem.openForItem(popup)) { selectedBar=bar.id; selectedCell=i; nameOwner=""; }
   // Bind drag/drop and context actions to the cell before icon decorations replace LastItem.
   dragCell(bar,i);
   drawCellContext(bar,i,popup);
   if (slots!=null) ExtraBarsPrototypeBar.drawItem(dl,slots[i],x,y,px);
   else { ImGui.ImDrawList_AddRect(dl,ImGui.vec2(x,y),ImGui.vec2(x+px,y+px),0xFF777777,4,1); ExtraBarsPrototypeBar.drawLabel(dl,Std.string(i+1),x,y+12,px,0xFFFFFFFF); }
   if (selectedBar==bar.id && selectedCell==i) ImGui.ImDrawList_AddRect(dl,ImGui.vec2(x-1,y-1),ImGui.vec2(x+px+1,y+px+1),0xFF37AFD4,4,2);
   if (hovered) ImGui.setTooltip("Cell "+(i+1)+": select to edit; right-click for actions; drag to swap item and binding.");
  }
  ImGui.setCursorScreenPos(p); ImGui.dummy(ImGui.vec2(ExtraBarsLayout.width(bar.columns,px),ExtraBarsLayout.rows(bar.slotCount,bar.columns)*(px+4)));
 }
 function dragCell(bar:ExtraBarsBarConfig,index:Int):Void {
  if (ImGui.beginDragDropSource()) {
   try {
    var payload = haxe.Json.stringify({bar:bar.id,index:index,generation:owner.generation});
    var length = ByteUtil.fillBuf(dragBuf,512,payload);
    if (length < 511) ImGui.setDragDropPayload("SF_EXTRA_CELL",dragBuf,length+1);
    ImGui.text(bar.name+" / "+(index+1));
   } catch(e:Dynamic) { ImGui.endDragDropSource(); throw e; } ImGui.endDragDropSource();
  }
  if (ImGui.beginDragDropTarget()) {
   var data:Dynamic = null;
   var itemData:Dynamic = null;
   try {
    var payload=ImGui.acceptDragDropPayload("SF_EXTRA_CELL"); if (payload!=null) data=haxe.Json.parse(payload.getString());
    var itemPayload=ImGui.acceptDragDropPayload("SF_EXTRA_ITEM"); if (itemPayload!=null) itemData=haxe.Json.parse(itemPayload.getString());
   }
   catch(_:Dynamic) {} ImGui.endDragDropTarget();
   var itemId=ExtraBarsItemDropPolicy.itemId(owner.model,bar.id,index,itemData,owner.generation,function(id) {
    for (item in owner.catalog) if (item.id==id) return true;
    return false;
   });
   if (itemId!=null) change("Assign item",function() {
    bar.slots[index].itemKind=itemId; selectBar(bar.id); selectedCell=index;
   });
   if (data!=null && data.generation==owner.generation) {
    var from = owner.model.find(data.bar); var indexFrom:Int = data.index;
    if (from!=null && indexFrom>=0 && indexFrom<from.slotCount && !(from.id==bar.id && indexFrom==index))
     change("Swap cells",function() owner.model.swap(from.id,indexFrom,bar.id,index));
   }
  }
 }
 function drawCell(bar:ExtraBarsBarConfig):Void {
  // A preview click can navigate to another bar, resolved next frame.
  if (selectedBar!=bar.id || selectedCell < 0 || selectedCell >= bar.slotCount) return;
  var slot=bar.slots[selectedCell]; var frozen=owner.views.get(bar.id);
  UiChrome.centeredHeader("Cell "+(selectedCell+1)+" / Item",36);
  ImGui.textWrapped(frozen!=null?frozen[selectedCell].name:(slot.itemKind.length>0?slot.itemKind:"Empty"));
  UiLayout.inlinePair("##extra_item_actions",function(w:Single) {
   ImGui.beginDisabled(slot.itemKind.length == 0);
   var clicked=false;
   try { clicked=ImGui.button("Clear Item##extra_clear_item",ImGui.vec2(w,28)); }
   catch(e:Dynamic) { ImGui.endDisabled(); throw e; } ImGui.endDisabled();
   if (clicked) clearItem(bar,selectedCell);
  },function(w:Single) {
   ImGui.beginDisabled(!hasItems(bar));
   var clicked=false;
   try { clicked=ImGui.button("Clear All##extra_clear_all",ImGui.vec2(w,28)); }
   catch(e:Dynamic) { ImGui.endDisabled(); throw e; } ImGui.endDisabled();
   if (ImGui.isItemHovered(imgui.Enums.ImGuiHoveredFlags.AllowWhenDisabled)) ImGui.setTooltip("Clear every saved item in this bar, including hidden cells. Keeps all keybinds. Undo restores assignments.");
   if (clicked) clearAll(bar);
  });
  ImGui.textWrapped("Choose an item below, or drag it onto a preview cell.");
  UiLayout.propertyGrid("##extra_catalog_filters",function() {
   UiLayout.propertyRow("In inventory only",function() ImGui.checkbox("##extra_inventory_only",inventoryOnly),"Includes carried items with no charges left. Turn off to plan assignments from the full catalog.");
  });
  var query=search.draw("##extra_search");
  UiScope.child("##extra_catalog",ImGui.vec2(0,Math.max(180,ImGui.getContentRegionAvail().y-4)),function() {
   var shown=0; var inventoryKnown=false;
   for (item in owner.catalog) {
    if (item.known) inventoryKnown=true;
    if (inventoryOnly.get() && (!item.known || !item.owned)) continue;
    if (query.length>0 && (item.name+" "+item.category+" "+item.id).toLowerCase().indexOf(query)<0) continue;
    shown++;
    var p=ImGui.getCursorScreenPos();
    var label=item.name+"  ["+item.category+"]  "+(item.known?Std.string(item.count):"?");
    var rowHeight:Single=Math.max(30,ImGui.getFontSize()+8);
    if (ImGui.selectable("###catalog_"+item.id,slot.itemKind==item.id,0,ImGui.vec2(0,rowHeight))) change("Assign item",function() slot.itemKind=item.id);
    var hovered=ImGui.isItemHovered(); var rowMax=ImGui.getItemRectMax(); var dl=ImGui.getWindowDrawList();
    if (ImGui.beginDragDropSource()) {
     try {
      var payload=haxe.Json.stringify({item:item.id,generation:owner.generation});
      var length=ByteUtil.fillBuf(dragBuf,512,payload);
      if (length<511) ImGui.setDragDropPayload("SF_EXTRA_ITEM",dragBuf,length+1);
      ImGui.text(item.name);
     } catch(e:Dynamic) { ImGui.endDragDropSource(); throw e; }
     ImGui.endDragDropSource();
    }
    solarflare.ui.GameIcons.drawKey(dl,item.icon,p.x+2,p.y+(rowHeight-24)/2,24,24);
    // Pixel geometry reserves the thumbnail and a 6px gap at every font size.
    var textX:Single=p.x+32;
    ImGui.ImDrawList_PushClipRect(dl,ImGui.vec2(textX,p.y),ImGui.vec2(Math.max(textX,rowMax.x),p.y+rowHeight),true);
    try { ImGui.ImDrawList_AddText_Vec2(dl,ImGui.vec2(textX,p.y+(rowHeight-ImGui.getFontSize())/2),ImGui.colorConvertFloat4ToU32(solarflare.ui.ThemePalette.current().text),label); }
    catch(e:Dynamic) { ImGui.ImDrawList_PopClipRect(dl); throw e; }
    ImGui.ImDrawList_PopClipRect(dl);
    if (hovered) ImGui.setTooltip(label);
   }
   if (shown==0) ImGui.textWrapped(inventoryOnly.get() && !inventoryKnown ? "Waiting for inventory data. Turn off the filter to browse all items." : "No matching items. Try clearing search or turning off the inventory filter.");
  });
 }
}
