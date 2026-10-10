package solarflare.barter;

import imgui.ImGui;
import imgui.Enums.ImGuiChildFlags;
import imgui.Enums.ImGuiTableColumnFlags;
import imgui.Enums.ImGuiTableFlags;
import imgui.Enums.ImGuiWindowFlags;
import imgui.ref.BoolRef;
import imgui.ref.IntRef;
import solarflare.aura.ConsumableCache;
import solarflare.cdb.AuraCatalog;
import solarflare.cdb.ConsumableCatalog;
import solarflare.ui.ByteUtil;
import solarflare.ui.EditorWindow;
import solarflare.ui.FeatureProfiles;
import solarflare.ui.GameIcons;
import solarflare.ui.SearchBar;
import solarflare.ui.ThemePalette;
import solarflare.ui.UiChrome;
import solarflare.ui.UiLayout;
import solarflare.ui.UiScope;
import solarflare.ui.ContextMenuSystem;

/** Selected cell is the destination for every edit; only explicit selection changes it. */
class BarTerBuilder {
 var owner:BarTer;
 public var selection = new BarTerEditingState();
 public var history = new BarTerHistory<Dynamic>();
 var boolRef = new BoolRef(false);
 var intRef = new IntRef(1);
 var skillSearch = new SearchBar("Search skills or status IDs");
 var itemSearch = new SearchBar("Search consumables");
 var catalogTab = 0;
 var inventoryOnly = new BoolRef(true);
 var nameBuf = new hl.Bytes(96);
 var dragBuf = new hl.Bytes(512);
 var colorBuf = new hl.Bytes(12);
 var nameOwner = "";
 var editEpoch:Int = 0;
 public function new(owner:BarTer) { this.owner=owner; ByteUtil.clearBytes(nameBuf,96); ByteUtil.clearBytes(dragBuf,512); }
 public function selectBar(b:BarTerBarConfig):Void { selection.selectBar(b.id,b.slotCount); nameOwner=""; }
 public function clearTransientState():Void {
  ByteUtil.clearBytes(dragBuf,512); nameOwner="";
  editEpoch++; skillSearch.clear(); itemSearch.clear(); ByteUtil.clearBytes(nameBuf,96);
 }
 public function recordChange():Void history.push(owner.dump());
 public function draw():Void {
  if (owner == null || !owner.config.open.get()) return;
  EditorWindow.drawMenuWindow("BarTer###SolarFlare.BarTer.Builder",owner.config.open,1000,860,drawBody);
 }
 function drawBody():Void {
  var cfg=owner.config;
  var bar=cfg.find(selection.barId);
  if (bar == null || !cfg.isActive(bar.id)) { selectBar(cfg.bars[0]); bar=cfg.bars[0]; }
  selection.clamp(bar.slotCount);
  UiLayout.inlineSplit("##bt_visibility",3,function(i,w) {
   boolRef.set(i == 0 ? bar.enabled && !bar.hidden : i == 1 ? bar.transparent : bar.locked);
   if (ImGui.checkbox(i == 0 ? "Show##bt_show" : i == 1 ? "Transparent##bt_transparent" : "Lock##bt_lock",boolRef)) {
    if (i == 0) { bar.enabled=boolRef.get(); bar.hidden=!boolRef.get(); cfg.enabled.set(true); cfg.hidden.set(false); }
    else if (i == 1) bar.transparent=boolRef.get(); else bar.locked=boolRef.get();
    owner.changed();
   }
  });
  UiLayout.inlineSplit("##bt_grid",4,function(i,w) {
   if (i == 0) {
    ImGui.textDisabled("Selected bar"); ImGui.setNextItemWidth(Math.min(w,220));
    combo("##bt_selected_bar",bar.name,function() {
     for (j in 0...Std.int(Math.min(cfg.activeBarCount,cfg.bars.length))) {
      var b=cfg.bars[j]; if (ImGui.selectable(b.name+"##bt_pick_"+b.id,bar.id == b.id)) selectBar(b);
     }
    });
   } else if (i == 1) {
    ImGui.textDisabled("Number of bars"); ImGui.setNextItemWidth(Math.min(w,110));
    combo("##bt_count",Std.string(cfg.activeBarCount),function() {
     for (n in 1...4) if (ImGui.selectable(Std.string(n)+"##bt_count_"+n,cfg.activeBarCount == n)) {
      recordChange(); cfg.setActiveCount(n); owner.clearTransientState(); owner.changed();
     }
    });
   } else {
    ImGui.textDisabled(i == 2 ? "Rows" : "Columns"); ImGui.setNextItemWidth(Math.min(w,130));
    intRef.set(i == 2 ? bar.rows : bar.columns);
    if (ImGui.sliderInt(i == 2 ? "##bt_rows" : "##bt_columns",intRef,1,i == 2 ? Std.int(Math.min(8,64/bar.columns)) : 16)) {
     recordChange(); bar.setGrid(i == 2 ? intRef.get() : bar.rows,i == 3 ? intRef.get() : bar.columns);
     selection.clamp(bar.slotCount); owner.changed();
    }
   }
  });
  UiChrome.centeredHeader("Selected bar · click a cell to edit",30);
  UiLayout.inlinePair("##bt_preview_row",function(w) {
   var height:Single=Math.min(220,Math.max(68,bar.rows*48+10));
   UiScope.child("##bt_preview",ImGui.vec2(w,height),function() { drawPreview(bar); },
    ImGuiChildFlags.Borders,ImGuiWindowFlags.HorizontalScrollbar);
  },function(w) {
   if (UiChrome.ghostButton("Fill empty cells##bt_populate",ImGui.vec2(w,28))) owner.requestPopulation(bar.id);
   if (UiChrome.ghostButton("Replace skills##bt_replace",ImGui.vec2(w,28))) owner.requestPopulation(bar.id,true);
   ImGui.textWrapped("Right-click a cell to clear it or clear this bar. Replacement keeps consumables and statuses.");
  },8);
  drawNativeStrip(bar);
  UiScope.table("##bt_catalogs",2,function() {
   ImGui.tableSetupColumn("Skills and statuses",ImGuiTableColumnFlags.WidthStretch,0.6);
   ImGui.tableSetupColumn("Consumables",ImGuiTableColumnFlags.WidthStretch,0.4);
   ImGui.tableNextRow(); ImGui.tableSetColumnIndex(0); drawSkillCatalog(bar);
   ImGui.tableSetColumnIndex(1); drawItems(bar);
  },ImGuiTableFlags.SizingStretchProp | ImGuiTableFlags.NoSavedSettings);
  drawDetails(bar);
  if (ImGui.collapsingHeader("Appearance and behavior##bt_appearance")) drawAppearance(bar);
  if (owner.lastStatus.length > 0) ImGui.textWrapped(owner.lastStatus);
  UiLayout.inlineSplit("##bt_history",3,function(i,w) {
   if (i < 2) {
    ImGui.beginDisabled(i == 0 ? history.past.length == 0 : history.future.length == 0);
    var clicked=UiChrome.ghostButton(i == 0 ? "Undo##bt_undo" : "Redo##bt_redo",ImGui.vec2(w,28));
    ImGui.endDisabled();
    if (clicked) {
     var state=i == 0 ? history.undo(owner.dump()) : history.redo(owner.dump());
     if (state != null) owner.restoreEditorState(state);
    }
   } else if (UiChrome.accentButton("Save##bt_save",ImGui.vec2(w,28))) solarflare.ui.UiActionQueue.save();
  });
  FeatureProfiles.drawToolbar(owner.host,"barter","barter_builder");
 }
 function combo(id:String,label:String,body:Void->Void):Void {
  if (!ImGui.beginCombo(id,label)) return;
  try body() catch (e:Dynamic) { ImGui.endCombo(); throw e; }
  ImGui.endCombo();
 }
 function drawPreview(b:BarTerBarConfig):Void {
  var snaps=owner.snapsFor(b.id);
  var p=ImGui.getCursorScreenPos(); var dl=ImGui.getWindowDrawList();
  var available=ImGui.getContentRegionAvail().x;
  var px:Single=Math.max(32,Math.min(52,(available-(b.columns-1)*4)/b.columns));
  for (i in 0...b.slotCount) {
   var x:Single=p.x+(i%b.columns)*(px+4); var y:Single=p.y+Std.int(i/b.columns)*(px+4);
   ImGui.setCursorScreenPos(ImGui.vec2(x,y));
   if (ImGui.invisibleButton("##bt_cell_"+b.id+"_"+i,ImGui.vec2(px,px))) selection.selectCell(i,b.slotCount);
   var hovered=ImGui.isItemHovered();
   var rightClicked=ImGui.isItemClicked(1);
   dragCell(b,i);
   var s=i < snaps.length ? snaps[i] : null;
   BarTerOverlay.drawCell(dl,s,x,y,px,haxe.Timer.stamp(),ImGui.getTime(),hovered,owner.config.showHotkeys.get(),b);
   if (selection.cell == i) ImGui.ImDrawList_AddRect(dl,ImGui.vec2(x,y),ImGui.vec2(x+px,y+px),
    ImGui.colorConvertFloat4ToU32(ThemePalette.current().accent),4,3);
   if (hovered && s != null) ImGui.setTooltip(BarTerOverlay.tooltip(s));
   drawCellContext(b,i,"preview",rightClicked);
  }
  ImGui.setCursorScreenPos(p); ImGui.dummy(ImGui.vec2(b.columns*(px+4)-4,b.rows*(px+4)-4));
 }
 function drawNativeStrip(b:BarTerBarConfig):Void {
  ImGui.textDisabled("Native skills · drag into any cell");
  UiScope.child("##bt_native_strip",ImGui.vec2(0,60),function() {
   var i=0;
   for (s in BarTerNativeKeys.skills) {
    if (i++ > 0) ImGui.sameLine();
    var p=ImGui.getCursorScreenPos();
    if (ImGui.invisibleButton("##bt_native_"+s.action+"_"+s.id,ImGui.vec2(42,42))) assign(b,selection.cell,"native",s.id,s.action);
    var hovered=ImGui.isItemHovered();
    beginSource("native",s.id,s.label,s.action);
    var dl=ImGui.getWindowDrawList();
    if (!GameIcons.drawKey(dl,s.icon,p.x+3,p.y+3,36,36,0xFFFFFFFF))
     ImGui.ImDrawList_AddText_Vec2(dl,p,ImGui.colorConvertFloat4ToU32(ThemePalette.current().text),s.id.substr(0,5));
    if (hovered) ImGui.setTooltip(s.label+"\n"+s.keyText);
   }
   if (i == 0) ImGui.textDisabled("Native skills are not available yet.");
  },ImGuiChildFlags.Borders,ImGuiWindowFlags.HorizontalScrollbar);
 }
 function drawSkillCatalog(b:BarTerBarConfig):Void {
  UiLayout.inlinePair("##bt_catalog_tabs",function(w) {
   if (UiChrome.ghostButton("Skills##bt_skills",ImGui.vec2(w,26))) catalogTab=0;
  },function(w) {
   if (UiChrome.ghostButton("Statuses##bt_statuses",ImGui.vec2(w,26))) catalogTab=1;
  });
  ImGui.setNextItemWidth(-36); var query=skillSearch.draw("##bt_skill_search");
  UiScope.child("##bt_skill_list",ImGui.vec2(0,190),function() {
   var shown=0;
   if (catalogTab == 1) {
    for (s in owner.statusChoices) {
     if (!AuraCatalog.matchesSearch(s.id,s.label,query)) continue;
     catalogRow(b,"status",s.id,s.label,s.icon,s.active); shown++;
     if (shown >= 200) break;
    }
    if (shown == 0) ImGui.textDisabled("No observed statuses match.");
   } else {
    for (entry in AuraCatalog.entries) {
     if (entry.kind != "skill" || !AuraCatalog.entryMatchesSearch(entry,query)) continue;
     var available=BarTerNativeKeys.find(entry.id) != null;
     catalogRow(b,"skill",entry.id,entry.name,entry.id,available); if (++shown >= 200) break;
    }
    if (shown == 0) ImGui.textDisabled("No skills match.");
    if (shown >= 200) ImGui.textDisabled("First 200 matches · refine search.");
   }
  },ImGuiChildFlags.Borders);
 }
 function catalogRow(b:BarTerBarConfig,kind:String,id:String,label:String,icon:String,available:Bool):Void {
  var p=ImGui.getCursorScreenPos();
  GameIcons.drawKey(ImGui.getWindowDrawList(),icon,p.x,p.y,22,22,available ? 0xFFFFFFFF : 0x88777777);
  ImGui.setCursorScreenPos(ImGui.vec2(p.x+27,p.y));
  if (ImGui.selectable(label+(available ? "" : " · unavailable")+"##bt_catalog_"+kind+"_"+id,false,0,ImGui.vec2(0,24)))
   assign(b,selection.cell,kind,id);
  if (ImGui.isItemHovered()) ImGui.setTooltip(id+"\nClick assigns to the selected cell; drag chooses a destination.");
  beginSource(kind,id,label);
 }
 function drawItems(b:BarTerBarConfig):Void {
  UiChrome.centeredHeader("Consumables",26);
  ImGui.checkbox("In my inventory only##bt_inventory_only",inventoryOnly);
  if (ImGui.isItemHovered()) ImGui.setTooltip("Includes carried items with no charges left. Turn off to plan from the full catalog.");
  ImGui.setNextItemWidth(-36); var query=itemSearch.draw("##bt_item_search");
  UiScope.child("##bt_items",ImGui.vec2(0,190),function() {
   var shown=0;
   for (entry in ConsumableCatalog.entries) {
    if (!AuraCatalog.matchesSearch(entry.id,entry.name,query)) continue;
    var inv=ConsumableCache.find(entry.id); var count=inv == null ? 0 : inv.count;
    if (inventoryOnly.get() && (inv == null || !inv.known || !inv.owned)) continue;
    catalogRow(b,"item",entry.id,entry.name+"  ×"+count,ConsumableCatalog.iconKey(entry.id),count > 0);
    if (++shown >= 200) break;
   }
   if (shown == 0) ImGui.textWrapped(inventoryOnly.get() ? "No matching items in your inventory. Turn off the filter to browse all consumables." : "No consumables match.");
  },ImGuiChildFlags.Borders);
 }
 function drawDetails(b:BarTerBarConfig):Void {
  UiChrome.centeredHeader("Selected cell "+(selection.cell+1),28);
  var s=b.slots[selection.cell]; var snaps=owner.snapsFor(b.id);
  var snap=selection.cell < snaps.length ? snaps[selection.cell] : null;
  UiLayout.propertyGrid("##bt_details",function() {
   UiLayout.propertyRow("Content",function() {
    ImGui.textWrapped(s.hasStatus() ? "Status · "+s.statusId : s.hasItem() ? "Consumable · "+s.itemKind : s.hasSkill() ? "Skill · "+s.skillId : "Empty");
   });
   UiLayout.propertyRow("Binding",function() {
    ImGui.textWrapped(s.hasStatus() ? "Display only" : s.hasSkill() ? (snap == null ? "Unknown" : snap.keyLabel)+" · native keyboard activation" : "No mod hotkey · uses the in-game consumable binding");
   });
  });
  UiLayout.inlineSplit("##bt_details_actions",1,function(i,w) {
    if (UiChrome.ghostButton("Clear cell##bt_clear",ImGui.vec2(w,26))) owner.clearCell(b,selection.cell);
  });
 }
 public function drawCellContext(b:BarTerBarConfig,index:Int,surface:String,rightClicked:Null<Bool>=null):Void {
  var id="##bt_context_"+surface+"_"+b.id+"_"+index;
  if (rightClicked == null) ContextMenuSystem.openForItem(id);
  else if (rightClicked) ImGui.openPopup(id);
  if (!ContextMenuSystem.begin(id)) return;
  try {
   ContextMenuSystem.separatorLabel(b.name+" · Cell "+(index+1));
   if (ContextMenuSystem.menuItem("Edit cell")) { selectBar(b); selection.selectCell(index,b.slotCount); owner.config.open.set(true); }
   if (ContextMenuSystem.menuItem("Clear cell","","",false,b.slots[index].hasContent())) owner.clearCell(b,index);
   drawBarMenu(b);
  } catch(e:Dynamic) { ContextMenuSystem.end(); throw e; }
  ContextMenuSystem.end();
 }
 public function drawBarMenu(b:BarTerBarConfig):Void {
  ContextMenuSystem.separatorLabel("This bar");
  if (ContextMenuSystem.menuItem("Fill empty cells")) owner.requestPopulation(b.id);
  if (ContextMenuSystem.menuItem("Replace skills with current loadout")) owner.requestPopulation(b.id,true);
  if (ContextMenuSystem.menuItem("Clear bar")) owner.clearBar(b);
  if (ContextMenuSystem.menuItem("Undo","","",false,history.past.length > 0)) {
   var state=history.undo(owner.dump()); if (state != null) owner.restoreEditorState(state);
  }
 }
 function drawAppearance(b:BarTerBarConfig):Void {
  if (nameOwner != b.id) { nameOwner=b.id; ByteUtil.fillBuf(nameBuf,96,b.name); }
  UiLayout.propertyGrid("##bt_appearance_grid",function() {
   UiLayout.propertyRow("Bar name",function() { ImGui.setNextItemWidth(220); if (ImGui.inputText("##bt_name",nameBuf,96)) { b.name=ByteUtil.readString(nameBuf,96,true); owner.changed(); } });
   UiLayout.propertyRow("Cell size",function() { ImGui.setNextItemWidth(160); intRef.set(b.slotSize); if (ImGui.sliderInt("##bt_size",intRef,32,128)) { b.slotSize=intRef.get(); owner.changed(); } });
   UiLayout.propertyRow("Bar colors",function() {
    ImGui.setNextItemWidth(160);
    combo("##bt_colors",b.colorMode == "theme" ? "F6 theme" : b.colorMode == "custom" ? "Custom" : "Neutral",function() {
     for (mode in ["neutral","theme","custom"]) if (ImGui.selectable((mode == "theme" ? "F6 theme" : mode == "custom" ? "Custom" : "Neutral")+"##bt_colors_"+mode,b.colorMode == mode)) {
      b.colorMode=mode; owner.changed();
     }
    });
   });
   if (b.colorMode == "custom") {
    UiLayout.propertyRow("Cell background",function() { b.fillColor=editColor("##bt_fill",b.fillColor); });
    UiLayout.propertyRow("Idle border",function() { b.borderColor=editColor("##bt_border",b.borderColor); });
    UiLayout.propertyRow("Ready / attention",function() { b.readyColor=editColor("##bt_ready",b.readyColor); });
   }
   UiLayout.propertyRow("Empty cells",function() { boolRef.set(b.showEmptyCells); if (ImGui.checkbox("Show on HUD##bt_empty",boolRef)) { b.showEmptyCells=boolRef.get(); owner.changed(); } });
   UiLayout.propertyRow("Key chips",function() { if (ImGui.checkbox("Show##bt_chips",owner.config.showHotkeys)) owner.changed(); });
   UiLayout.propertyRow("Weapon layouts",function() { if (ImGui.checkbox("Follow native skills##bt_follow",owner.config.autoSeedOnWeaponSwap)) owner.changed(); });
  });
  ImGui.textDisabled("Hidden cells and inactive bars remain saved. Maximum: 3 active bars, 64 cells each.");
 }
 function editColor(id:String,rgb:Int):Int {
  colorBuf.setF32(0,((rgb >> 16)&255)/255.0); colorBuf.setF32(4,((rgb >> 8)&255)/255.0); colorBuf.setF32(8,(rgb&255)/255.0);
  if (!ImGui.colorEdit3(id,colorBuf)) return rgb;
  var r=Std.int(Math.max(0,Math.min(1,colorBuf.getF32(0)))*255);
  var g=Std.int(Math.max(0,Math.min(1,colorBuf.getF32(4)))*255);
  var b=Std.int(Math.max(0,Math.min(1,colorBuf.getF32(8)))*255);
  owner.changed(); return (r << 16)|(g << 8)|b;
 }
 function assign(b:BarTerBarConfig,index:Int,kind:String,id:String,action:String=""):Void {
  if (index < 0 || index >= b.slotCount || id == null || id.length == 0 || id.length > 192) return;
  if (kind != "skill" && kind != "native" && kind != "item" && kind != "status") return;
  recordChange(); owner.reserve(b.id,index);
  var s=b.slots[index];
  if (kind == "item") s.assignItem(id);
  else if (kind == "status") s.assignStatus(id);
  else {
   s.assignSkill(id);
   if (kind == "native") { var n=BarTerBindingResolver.resolve(id,action,BarTerNativeKeys.skills); if (n != null) s.nativeActionId=n.action; }
  }
  owner.changed();
 }
 function beginSource(kind:String,id:String,label:String,action:String=""):Void {
  if (!ImGui.beginDragDropSource()) return;
  try {
   var payload=haxe.Json.stringify({kind:kind,id:id,action:action,epoch:editEpoch}); var length=ByteUtil.fillBuf(dragBuf,512,payload);
   if (length < 511) ImGui.setDragDropPayload("SF_BARTER_ASSIGN",dragBuf,length+1);
   ImGui.text(label);
  } catch (e:Dynamic) { ImGui.endDragDropSource(); throw e; }
  ImGui.endDragDropSource();
 }
 function dragCell(b:BarTerBarConfig,index:Int):Void {
  if (ImGui.beginDragDropSource()) {
   try {
    var payload=haxe.Json.stringify({bar:b.id,index:index,epoch:editEpoch}); var length=ByteUtil.fillBuf(dragBuf,512,payload);
    if (length < 511) ImGui.setDragDropPayload("SF_BARTER_CELL",dragBuf,length+1);
    ImGui.text(b.name+" / "+(index+1));
   } catch (e:Dynamic) { ImGui.endDragDropSource(); throw e; }
   ImGui.endDragDropSource();
  }
  if (!ImGui.beginDragDropTarget()) return;
  var cell:Dynamic=null; var assignment:Dynamic=null;
  try {
   var p=ImGui.acceptDragDropPayload("SF_BARTER_CELL");
   if (p != null && ImGui.getPayloadDataSize(p) <= 512) cell=haxe.Json.parse(ByteUtil.readString(ImGui.getPayloadData(p),ImGui.getPayloadDataSize(p),true));
   p=ImGui.acceptDragDropPayload("SF_BARTER_ASSIGN");
   if (p != null && ImGui.getPayloadDataSize(p) <= 512) assignment=haxe.Json.parse(ByteUtil.readString(ImGui.getPayloadData(p),ImGui.getPayloadDataSize(p),true));
  } catch (_:Dynamic) {}
  ImGui.endDragDropTarget();
  if (cell != null && cell.epoch == editEpoch && Std.isOfType(cell.bar,String) && Std.isOfType(cell.index,Int)) {
   var from=owner.config.find(cell.bar);
   if (from != null && owner.config.isActive(from.id) && cell.index >= 0 && cell.index < from.slotCount && !(from.id == b.id && cell.index == index)) {
    recordChange();
    promoteMovedNative(from.slots[cell.index]); promoteMovedNative(b.slots[index]);
    owner.reserve(from.id,cell.index); owner.reserve(b.id,index);
    owner.config.swap(from.id,cell.index,b.id,index); selection.selectCell(index,b.slotCount); owner.changed();
   }
  }
  if (assignment != null && assignment.epoch == editEpoch && Std.isOfType(assignment.kind,String) && Std.isOfType(assignment.id,String)) {
   assign(b,index,assignment.kind,assignment.id,Std.isOfType(assignment.action,String) ? assignment.action : ""); selection.selectCell(index,b.slotCount);
  }
 }
 function promoteMovedNative(slot:BarTerSlotConfig):Void {
  if (slot.hasSkill() && slot.nativeActionId.length == 0) {
   var native=BarTerNativeKeys.find(slot.skillId); if (native != null) slot.nativeActionId=native.action;
  }
 }
}
