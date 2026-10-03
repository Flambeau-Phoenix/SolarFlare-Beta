package solarflare.extrabars;

import imgui.ImGui;
import imgui.Enums.ImGuiWindowFlags;
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
  EditorWindow.drawMenuWindow("ExtraBars###SolarFlare.ExtraBars.Builder",owner.open,800,720,function() {
   owner.drawCapture();
   history.drawButtons(owner.model.dump(),restore);
   ImGui.sameLine(); if (ImGui.button("Save")) solarflare.ui.UiActionQueue.save();
   ImGui.sameLine(); if (ImGui.button("Close editors and test")) owner.closeEditors();
   ImGui.spacing();
   drawPages();
  });
 }
 function drawPages():Void {
  if (ImGui.beginTabBar("##extra_pages",imgui.Enums.ImGuiTabBarFlags.DrawSelectedOverline)) {
   try {
    for (i in 0...4) {
     var label=["Bars","Activation","Spark Cube","Diagnostics"][i];
     if (beginPageTab(label+"##extra_page_"+i)) {
      try {
       switch(i) {
        case 0: drawBars();
        case 1: drawActivation();
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
 function beginPageTab(label:String):Bool {
  var theme = solarflare.ui.ThemePalette.current();
  // Flat native tabs with an accent overline distinguish navigation from actions.
  ImGui.pushStyleVar(ImGuiStyleVar.TabRounding,3);
  ImGui.pushStyleVar(ImGuiStyleVar.FramePadding,ImGui.vec2(14,8));
  ImGui.pushStyleColor(ImGuiCol.Tab,theme.windowBg);
  ImGui.pushStyleColor(ImGuiCol.TabSelected,theme.cellBg);
  ImGui.pushStyleColor(ImGuiCol.TabHovered,theme.border);
  ImGui.pushStyleColor(ImGuiCol.TabSelectedOverline,theme.accent);
  var shown=false;
  try { shown=ImGui.beginTabItem(label); }
  catch(e:Dynamic) { ImGui.popStyleColor(4); ImGui.popStyleVar(2); throw e; }
  ImGui.popStyleColor(4); ImGui.popStyleVar(2);
  return shown;
 }
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
   UiChrome.heading("Activation");
   UiLayout.propertyGrid("##extra_activation",function() {
    UiLayout.propertyRow("Bars enabled",function() check("##extra_master",owner.model.enabled,function(v) owner.model.enabled=v));
    UiLayout.propertyRow("Prefix",function() {
     if (ImGui.beginCombo("##extra_prefix",ExtraBarsActivationConfig.prefixLabel(owner.model.prefix))) {
      try { for (prefix in ExtraBarsActivationConfig.prefixes) if (ImGui.selectable(ExtraBarsActivationConfig.prefixLabel(prefix),owner.model.prefix==prefix)) change("Prefix",function() owner.model.prefix=prefix); }
      catch(e:Dynamic) { ImGui.endCombo(); throw e; } ImGui.endCombo();
     }
    });
    UiLayout.propertyRow("Mode",function() {
     if (ImGui.beginCombo("##extra_mode",ExtraBarsActivationConfig.modeLabel(owner.model.mode))) {
      try { for (mode in ["hold","toggle"]) if (ImGui.selectable(ExtraBarsActivationConfig.modeLabel(mode),owner.model.mode==mode)) change("Mode",function() owner.model.mode=mode); }
      catch(e:Dynamic) { ImGui.endCombo(); throw e; } ImGui.endCombo();
     }
    },"Ctrl, Alt and Shift keep their native actions. Off disables the bars; hidden bars keep hotkeys.");
   });
   ImGui.textWrapped("Hold keeps the bars active while the prefix is held. Toggle switches them on or off with each prefix press. Press a cell's assigned key while the bars are active.");
   drawBarOverview();
 }
 function drawBars():Void {
   UiChrome.heading("Your bars");
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
   if (bar != null) {
    if (selectedCell >= bar.slotCount) selectedCell = bar.slotCount-1;
    var available=ImGui.getContentRegionAvail();
    if (available.x>=720) {
     var height:Single=Math.max(260,available.y-4);
     UiScope.table("##extra_bar_workspace",2,function() {
      ImGui.tableSetupColumn("Layout",ImGuiTableColumnFlags.WidthStretch,0.42);
      ImGui.tableSetupColumn("Cell",ImGuiTableColumnFlags.WidthStretch,0.58);
      ImGui.tableNextRow(); ImGui.tableSetColumnIndex(0);
      UiScope.child("##extra_layout",ImGui.vec2(0,height),function() drawBarLayout(bar));
      ImGui.tableSetColumnIndex(1);
      UiScope.child("##extra_cell_editor",ImGui.vec2(0,height),function() drawCell(bar));
     },ImGuiTableFlags.SizingStretchProp|ImGuiTableFlags.NoSavedSettings);
    } else {
     drawBarLayout(bar);
     drawCell(bar);
    }
   }
 }
 function drawBarLayout(bar:ExtraBarsBarConfig):Void {
  UiChrome.subHeader("Layout and appearance");
  drawProperties(bar);
  UiChrome.subHeader("Bar preview");
  ImGui.checkbox("Show all bar previews for swapping",allBars);
  ImGui.textDisabled("Select a cell to edit; drag cells to swap.");
  var height=ExtraBarsLayout.rows(bar.slotCount,bar.columns)*44+8;
  if (allBars.get()) height=180;
  UiScope.child("##extra_previews",ImGui.vec2(0,height),function() {
   if (allBars.get()) { for (candidate in owner.model.bars) { ImGui.text(candidate.name); preview(candidate); } }
   else preview(bar);
  },0,ImGuiWindowFlags.HorizontalScrollbar);
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
   ImGui.textWrapped("Charged or empty. Click to use; refill at the Obelisks' waters. During Spark surge, see the countdown and damage dealt; afterward, see the burst result. Hover for details.");
   UiChrome.subHeader("Current observation");
   UiLayout.propertyGrid("##extra_spark_observation",function() {
    UiLayout.propertyRow("Cube",function() ImGui.text(owner.spark.label));
    UiLayout.propertyRow("Damage dealt",function() ImGui.text(owner.spark.state.started>=0 ? Std.string(owner.spark.state.observedDamage)+(owner.spark.state.partial?" *":"") : "Waiting for a Spark surge."));
    UiLayout.propertyRow("Last burst",function() ImGui.text(owner.spark.state.burstAt>=0 ? Std.string(owner.spark.state.burstDamage) : "Waiting for a burst."));
   });
   ImGui.textWrapped("These are observed game values. * indicates a partial observation. The tracker can stay enabled when the consumable bars are off.");
 }
 function drawProperties(bar:ExtraBarsBarConfig):Void {
  if (nameOwner != bar.id) { ByteUtil.fillBuf(nameBuf,192,bar.name); pendingName=bar.name; nameOwner=bar.id; }
  UiLayout.propertyGrid("##extra_bar_properties",function() {
   UiLayout.propertyRow("Name",function() {
    if (ImGui.inputText("##extra_name",nameBuf,192)) pendingName=ByteUtil.readString(nameBuf,192,true);
    if (ImGui.isItemDeactivatedAfterEdit() && pendingName.length>0 && pendingName!=bar.name) change("Rename bar",function() bar.name=pendingName);
   });
   UiLayout.propertyRow("Enabled",function() check("##bar_enabled",bar.enabled,function(v) bar.enabled=v));
   UiLayout.propertyRow("Hidden",function() check("##bar_hidden",bar.hidden,function(v) bar.hidden=v));
   UiLayout.propertyRow("Cells",function() {
    if (ImGui.beginCombo("##bar_cells",Std.string(bar.slotCount))) {
     try { for (n in 1...11) if (ImGui.selectable(Std.string(n),bar.slotCount==n)) change("Cell count",function() bar.setCount(n)); }
     catch(e:Dynamic) { ImGui.endCombo(); throw e; } ImGui.endCombo();
    }
   },"Assignments outside the visible cells stay saved and inactive.");
   UiLayout.propertyRow("Rows",function() slider("##bar_rows",bar.rows,1,bar.slotCount,function(v) bar.setRows(v)));
   UiLayout.propertyRow("Columns",function() slider("##bar_columns",bar.columns,1,bar.slotCount,function(v) bar.setColumns(v)),"Rows and columns are linked. A partial last row keeps the chosen cell count.");
   UiLayout.propertyRow("Cell size",function() slider("##bar_size",bar.slotSize,24,96,function(v) bar.slotSize=v));
   UiLayout.propertyRow("Lock position",function() check("##bar_lock",bar.locked,function(v) bar.locked=v));
   UiLayout.propertyRow("Transparent",function() check("##bar_trans",bar.transparent,function(v) bar.transparent=v));
   UiLayout.propertyRow("Opacity",function() {
    floatRef.set(bar.opacity); var before=owner.model.dump();
    if (ImGui.sliderFloat("##bar_opacity",floatRef,0.15,1,"%.2f")) {
     if (gestureBefore==null) { gestureBefore=before; gestureAction="Opacity"; }
     bar.opacity=floatRef.get(); SettingsStore.markDirty();
    }
    if (gestureBefore!=null && !ImGui.isAnyItemActive()) { history.push(gestureAction,gestureBefore); gestureBefore=null; changed(); }
   });
  });
  UiLayout.inlineSplit("##bar_presets",4,function(i,w) {
   var cols = [bar.slotCount,Std.int(Math.ceil(bar.slotCount/2)),2,1][i]; cols=Std.int(Math.min(cols,bar.slotCount));
   var rows = ExtraBarsLayout.rows(bar.slotCount,cols);
   if (ImGui.button(rows+" x "+cols+"##preset_"+i,ImGui.vec2(w,0))) change("Layout preset",function() bar.setColumns(cols));
  });
 }
 function preview(bar:ExtraBarsBarConfig):Void {
  var slots = owner.views.get(bar.id); var p=ImGui.getCursorScreenPos(); var dl=ImGui.getWindowDrawList();
  var px = 40;
  for (i in 0...bar.slotCount) {
   var x:Single=p.x+(i%bar.columns)*(px+4); var y:Single=p.y+Std.int(i/bar.columns)*(px+4);
   ImGui.setCursorScreenPos(ImGui.vec2(x,y));
   if (ImGui.invisibleButton("##preview_"+bar.id+"_"+i,ImGui.vec2(px,px))) { selectedBar=bar.id; selectedCell=i; nameOwner=""; }
   if (slots!=null) ExtraBarsPrototypeBar.drawItem(dl,slots[i],x,y,px);
   else { ImGui.ImDrawList_AddRect(dl,ImGui.vec2(x,y),ImGui.vec2(x+px,y+px),0xFF777777,4,1); ExtraBarsPrototypeBar.drawLabel(dl,Std.string(i+1),x,y+12,px,0xFFFFFFFF); }
   if (selectedBar==bar.id && selectedCell==i) ImGui.ImDrawList_AddRect(dl,ImGui.vec2(x-1,y-1),ImGui.vec2(x+px+1,y+px+1),0xFF37AFD4,4,2);
   if (ImGui.isItemHovered()) ImGui.setTooltip("Cell "+(i+1)+": select to edit; drag to swap item and binding.");
   dragCell(bar,i);
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
   try { var payload=ImGui.acceptDragDropPayload("SF_EXTRA_CELL"); if (payload!=null) data=haxe.Json.parse(payload.getString()); }
   catch(_:Dynamic) {} ImGui.endDragDropTarget();
   if (data!=null && data.generation==owner.generation) {
    var from = owner.model.find(data.bar); var indexFrom:Int = data.index;
    if (from!=null && indexFrom>=0 && indexFrom<from.slotCount && !(from.id==bar.id && indexFrom==index))
     change("Swap cells",function() owner.model.swap(from.id,indexFrom,bar.id,index));
   }
  }
 }
 function drawCell(bar:ExtraBarsBarConfig):Void {
  // A preview click can navigate to another bar, resolved next frame.
  if (selectedBar!=bar.id) return;
  var slot=bar.slots[selectedCell]; var frozen=owner.views.get(bar.id);
  UiChrome.subHeader("Cell "+(selectedCell+1)+" / Item and binding");
  ImGui.textWrapped(frozen!=null?frozen[selectedCell].name:(slot.itemKind.length>0?slot.itemKind:"Empty"));
  ImGui.textWrapped(frozen!=null?frozen[selectedCell].binding:"Waiting for observation.");
  if (frozen!=null && frozen[selectedCell].reason.length>0) ImGui.textWrapped(frozen[selectedCell].reason);
  UiLayout.inlineSplit("##extra_cell_actions",3,function(i,w) {
   if (i==0 && ImGui.button("Record key",ImGui.vec2(w,0))) owner.startCapture(bar.id,selectedCell);
   if (i==1 && ImGui.button("Clear key",ImGui.vec2(w,0))) change("Clear key",function() { slot.keyCode=0; slot.modifiers=0; });
   if (i==2 && ImGui.button("Clear item",ImGui.vec2(w,0))) change("Clear item",function() slot.itemKind="");
  });
  if (owner.captureMessage.length>0) ImGui.textWrapped(owner.captureMessage);
  if (owner.suggestions.length>0) ImGui.textWrapped("Checked unbound alternatives: "+owner.suggestions);
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
