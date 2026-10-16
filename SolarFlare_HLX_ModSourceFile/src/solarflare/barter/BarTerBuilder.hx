package solarflare.barter;

import imgui.ImGui;
import imgui.Enums.ImGuiChildFlags;
import imgui.Enums.ImGuiTableColumnFlags;
import imgui.Enums.ImGuiTableFlags;
import imgui.Enums.ImGuiWindowFlags;
import imgui.Enums.ImGuiStyleVar;
import imgui.ref.BoolRef;
import imgui.ref.IntRef;
import imgui.ref.FloatRef;
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
 var glowNumberRef=new FloatRef(1);
 static var readyModes=["None","Pulse","Bright","Aura glow"];
 static var cooldownModes=["None","Dim","Outline"];
 static var auraStyles=["proc","soft","pulse"];
 var glowEditBefore:Dynamic=null;
 var editGlowSkill:String="";
 var previewMode:Int=0;
 var previewSnap=new BarTerSnap();
 static var behaviors=["Off","Flash when ready","Continuous while usable"];
 static var animations=["Steady","Pulsing"];
 static var endings=["Fade","Abrupt stop"];
 static var procs=["Off","Existing glimmer","Steady outline","Continuous pulse"];
 static var previewModes=["Ready","Cooldown","Near ready","Resource-starved","Charged","Proc","Unavailable"];
 public function editSkillGlow(b:BarTerBarConfig,index:Int):Void {
  var snaps=owner.snapsFor(b.id);
  var id=index<snaps.length && snaps[index].baseSkillId.length>0 ? snaps[index].baseSkillId : b.slots[index].skillId;
  if(id.length==0) return;
  editGlowSkill=id; selectBar(b); selection.selectCell(index,b.slotCount); owner.config.open.set(true);
 }
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
  glowEditBefore=null; editGlowSkill="";
  ByteUtil.clearBytes(dragBuf,512); nameOwner="";
  editEpoch++; skillSearch.clear(); itemSearch.clear(); ByteUtil.clearBytes(nameBuf,96);
 }
 public function recordChange():Void history.push(owner.editorSnapshot());
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
  UiLayout.propertyGrid("##bt_position",function() cfg.chromeFor(bar.id).drawPositionRow("bt_pos_"+bar.id));
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
  UiChrome.centeredHeader("Selected bar Â· click a cell to edit",30);
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
  ImGui.textDisabled("Weapon arrangement Â· "+owner.comboLabel);
  if (!owner.managedEditsReady) ImGui.textDisabled("Resolving weapon change Â· native cell moves are paused.");
  UiLayout.inlinePair("##bt_native_tools",function(w) {
   ImGui.beginDisabled(!owner.managedEditsReady);
   try { if (UiChrome.ghostButton("Repair native skill cells##bt_repair",ImGui.vec2(w,28))) owner.requestRepair(); }
   catch(e:Dynamic) { ImGui.endDisabled(); throw e; }
   ImGui.endDisabled();
  },function(w) { if (UiChrome.ghostButton("Check native skills##bt_check_native",ImGui.vec2(w,28))) owner.requestNativeCheck(); });
  if(owner.nativeCheckSummary.length>0) ImGui.textWrapped(owner.nativeCheckSummary);
  if(owner.nativeCheckReport.length>0 && UiChrome.groupHeader("Native skill check##bt_native_report",false)) {
   if(UiChrome.ghostButton("Copy report##bt_copy_native_report",ImGui.vec2(160,26))) solarflare.ui.UiActionQueue.copyText(owner.nativeCheckReport);
   ImGui.textWrapped(owner.nativeCheckReport);
  }
  UiScope.table("##bt_catalogs",2,function() {
   ImGui.tableSetupColumn("Skills and statuses",ImGuiTableColumnFlags.WidthStretch,0.6);
   ImGui.tableSetupColumn("Consumables",ImGuiTableColumnFlags.WidthStretch,0.4);
   ImGui.tableNextRow(); ImGui.tableSetColumnIndex(0); drawSkillCatalog(bar);
   ImGui.tableSetColumnIndex(1); drawItems(bar);
  },ImGuiTableFlags.SizingStretchProp | ImGuiTableFlags.NoSavedSettings);
  drawDetails(bar);
  if (ImGui.collapsingHeader("Appearance and behavior##bt_appearance")) drawAppearance(bar);
  if(editGlowSkill.length>0) drawGlow(bar);
  if(owner.config.glowDiagnostics.get()) { ImGui.textWrapped(owner.glowDiagnosticReport); if(UiChrome.ghostButton("Copy glow diagnostics##bt_copy_glow",ImGui.vec2(170,26))) solarflare.ui.UiActionQueue.copyText(owner.glowDiagnosticReport); }
  if (owner.lastStatus.length > 0) ImGui.textWrapped(owner.lastStatus);
  UiLayout.inlineSplit("##bt_history",3,function(i,w) {
   if (i < 2) {
    ImGui.beginDisabled(i == 0 ? history.past.length == 0 : history.future.length == 0);
    var clicked=UiChrome.ghostButton(i == 0 ? "Undo##bt_undo" : "Redo##bt_redo",ImGui.vec2(w,28));
    ImGui.endDisabled();
    if (clicked) {
     var list=i==0 ? history.past : history.future;
     var scope=list.length>0 && Std.isOfType(list[list.length-1].editorKey,String) ? list[list.length-1].editorKey : null;
     var state=i == 0 ? history.undo(owner.editorSnapshot(scope)) : history.redo(owner.editorSnapshot(scope));
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
  var margin:Single=b.glow.reach(52);
  var px:Single=Math.max(32,Math.min(52,(available-margin*2-(b.columns-1)*4)/b.columns));
  for (i in 0...b.slotCount) {
   var x:Single=p.x+margin+(i%b.columns)*(px+4); var y:Single=p.y+margin+Std.int(i/b.columns)*(px+4);
   ImGui.setCursorScreenPos(ImGui.vec2(x,y));
   if (ImGui.invisibleButton("##bt_cell_"+b.id+"_"+i,ImGui.vec2(px,px))) selection.selectCell(i,b.slotCount);
   var hovered=ImGui.isItemHovered();
   var rightClicked=ImGui.isItemClicked(1);
   dragCell(b,i);
   var s=i < snaps.length ? snaps[i] : null;
   BarTerOverlay.drawCell(dl,s,x,y,px,haxe.Timer.stamp(),ImGui.getTime(),hovered,owner.config.showHotkeys.get(),b);
   if (selection.cell == i) ImGui.ImDrawList_AddRect(dl,ImGui.vec2(x,y),ImGui.vec2(x+px,y+px),
    ImGui.colorConvertFloat4ToU32(ThemePalette.current().accent),4,3);
   if (hovered && s != null) BarTerOverlay.drawTooltip(s);
   drawCellContext(b,i,"preview",rightClicked);
  }
  ImGui.setCursorScreenPos(p); ImGui.dummy(ImGui.vec2(b.columns*(px+4)-4+margin*2,b.rows*(px+4)-4+margin*2));
 }
 function drawNativeStrip(b:BarTerBarConfig):Void {
  var picker=owner.nativePicker;
  ImGui.textDisabled(picker.caption);
  ImGui.beginDisabled(picker.signatureIndex<0);
  var revealSignature=ImGui.smallButton("Show signature##bt_show_signature");
  ImGui.endDisabled();
  ImGui.sameLine(); ImGui.textDisabled(picker.signatureSummary);
  if (picker.signatureTooltip.length>0 && ImGui.isItemHovered()) ImGui.setTooltip(picker.signatureTooltip);
  ImGui.pushStyleVar(ImGuiStyleVar.WindowPadding,ImGui.vec2(BarTerNativePickerLayout.PADDING,BarTerNativePickerLayout.PADDING));
  ImGui.pushStyleVar(ImGuiStyleVar.ScrollbarSize,BarTerNativePickerLayout.SCROLLBAR);
  try {
  UiScope.child("##bt_native_strip",ImGui.vec2(0,BarTerNativePickerLayout.HEIGHT),function() {
   var origin=ImGui.getCursorScreenPos();
   var i=0;
   for (s in picker.rows) {
    ImGui.setCursorScreenPos(ImGui.vec2(origin.x+BarTerNativePickerLayout.x(i++),origin.y));
    var p=ImGui.getCursorScreenPos();
    if (ImGui.invisibleButton("##bt_native_"+s.action,ImGui.vec2(BarTerNativePickerLayout.CELL,BarTerNativePickerLayout.CELL))) assign(b,selection.cell,"native",s.id,s.action);
    var hovered=ImGui.isItemHovered();
    if (revealSignature && s.action=="SignatureSkill") ImGui.setScrollHereX(0.5);
    beginSource("native",s.id,s.label,s.action);
    var dl=ImGui.getWindowDrawList();
    if (!GameIcons.drawKey(dl,s.icon,p.x+3,p.y+3,36,36,0xFFFFFFFF))
     ImGui.ImDrawList_AddText_Vec2(dl,p,ImGui.colorConvertFloat4ToU32(ThemePalette.current().text),s.id.substr(0,5));
    if (hovered) ImGui.setTooltip(s.label+"\n"+s.keyText);
   }
   if (i == 0) ImGui.textDisabled("Native skills are not available yet.");
   else { ImGui.setCursorScreenPos(origin); ImGui.dummy(ImGui.vec2(BarTerNativePickerLayout.width(i),BarTerNativePickerLayout.CELL)); }
  },ImGuiChildFlags.Borders,ImGuiWindowFlags.HorizontalScrollbar);
  } catch(e:Dynamic) { ImGui.popStyleVar(2); throw e; }
  ImGui.popStyleVar(2);
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
     var available=BarTerNativeKeys.find(entry.id) != null || solarflare.geaux.GeauxCache.inBook(entry.id);
     catalogRow(b,"skill",entry.id,entry.name,entry.id,available); if (++shown >= 200) break;
    }
    if (shown == 0) ImGui.textDisabled("No skills match.");
    if (shown >= 200) ImGui.textDisabled("First 200 matches Â· refine search.");
   }
  },ImGuiChildFlags.Borders);
 }
 function catalogRow(b:BarTerBarConfig,kind:String,id:String,label:String,icon:String,available:Bool):Void {
  var p=ImGui.getCursorScreenPos();
  GameIcons.drawKey(ImGui.getWindowDrawList(),icon,p.x,p.y,22,22,available ? 0xFFFFFFFF : 0x88777777);
  ImGui.setCursorScreenPos(ImGui.vec2(p.x+27,p.y));
  if (ImGui.selectable(label+(available ? "" : " Â· unavailable")+"##bt_catalog_"+kind+"_"+id,false,0,ImGui.vec2(0,24)))
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
    catalogRow(b,"item",entry.id,entry.name+"  Ã—"+count,ConsumableCatalog.iconKey(entry.id),count > 0);
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
    ImGui.textWrapped(s.hasStatus() ? "Status Â· "+s.statusId : s.hasItem() ? "Consumable Â· "+s.itemKind : s.nativeActionId.length>0 ? s.nativeActionId+" Â· "+(snap==null ? "Resolvingâ€¦" : snap.label) : s.hasSkill() ? "Pinned skill Â· "+s.skillId : "Empty");
   });
   UiLayout.propertyRow("Binding",function() {
    ImGui.textWrapped(s.hasStatus() ? "Display only" : s.hasSkill() ? (snap == null ? "Unknown" : snap.keyLabel)+" Â· native keyboard activation" : "No mod hotkey Â· uses the in-game consumable binding");
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
   ContextMenuSystem.separatorLabel(b.name+" Â· Cell "+(index+1));
   if (ContextMenuSystem.menuItem("Edit cell")) { selectBar(b); selection.selectCell(index,b.slotCount); owner.config.open.set(true); }
   if (ContextMenuSystem.menuItem("Clear cell","","",false,b.slots[index].hasContent())) owner.clearCell(b,index);
   if(b.slots[index].hasSkill() && ContextMenuSystem.menuItem("Skill glow override")) editSkillGlow(b,index);
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
   UiLayout.propertyRow("Weapon layouts",function() {
    if (ImGui.checkbox("Follow native skills##bt_follow",owner.config.autoSeedOnWeaponSwap)) owner.changed();
    if (ImGui.isItemHovered()) ImGui.setTooltip("Restore remembered weapon positions and fill missing native actions on weapon changes. Native-action cells show their current skill; assign from the catalog to pin a specific skill.");
   });
  });
  if(editGlowSkill.length==0) drawGlow(b);
  ImGui.textDisabled("Hidden cells and inactive bars remain saved. Maximum: 3 active bars, 64 cells each.");
 }
 function drawGlow(b:BarTerBarConfig):Void {
  if (!UiChrome.groupHeader("Glow##bt_glow",editGlowSkill.length>0)) return;
  var cfg=owner.config;
  var g=editGlowSkill.length>0 ? cfg.glowFor(editGlowSkill,b) : b.glow;
  if(editGlowSkill.length>0) {
   ImGui.textWrapped("Skill glow override Â· "+editGlowSkill);
   var own=cfg.glowOverrides.exists(editGlowSkill);
   UiLayout.inlinePair("##bt_glow_override_actions",function(w) {
    if(UiChrome.ghostButton(own ? "Use bar defaults##bt_glow_inherit" : "Create override##bt_glow_create",ImGui.vec2(w,26))) {
     recordChange();
     if(own) cfg.glowOverrides.remove(editGlowSkill);
     else { var style=new solarflare.geaux.SkillAttentionStyle(); style.apply(b.glow.dump()); cfg.glowOverrides.set(editGlowSkill,style); }
     owner.changed();
    }
   },function(w) { if(UiChrome.ghostButton("Edit bar defaults##bt_glow_bar",ImGui.vec2(w,26))) editGlowSkill=""; });
   if(!own) { ImGui.textDisabled("Uses this bar's defaults. Create an override to edit this skill independently."); return; }
  }
  UiLayout.propertyGrid("##bt_glow_properties",function() {
   glowChoice("Ready behavior","##bt_glow_behavior",behaviors,g.behavior,function(v) g.behavior=v);
   UiLayout.propertyRow("Flash duration",function() g.flashDuration=glowNumber("##bt_glow_duration",g.flashDuration,60,0.1));
   glowChoice("Flash ending","##bt_glow_ending",endings,g.fade ? 0 : 1,function(v) g.fade=v==0);
   glowChoice("Animation","##bt_glow_animation",animations,g.pulsing ? 1 : 0,function(v) g.pulsing=v==1);
   UiLayout.propertyRow("Animation speed",function() g.speed=glowNumber("##bt_glow_speed",g.speed,4,0.1));
   UiLayout.propertyRow("Near-ready warning",function() {
    boolRef.set(g.nearEnabled); if(ImGui.checkbox("Enabled##bt_glow_near",boolRef)) { recordChange(); g.nearEnabled=boolRef.get(); owner.changed(); }
   });
   UiLayout.propertyRow("Warning threshold",function() g.nearThreshold=glowNumber("##bt_glow_threshold",g.nearThreshold,10,0.1));
   glowChoice("Proc highlight","##bt_glow_proc",procs,g.procMode,function(v) g.procMode=v);
   UiLayout.propertyRow("Ready glow",function() {
    combo("##bt_glow_ready",readyModes[g.readyMode],function() {
     for(i in 0...readyModes.length) if(ImGui.selectable(readyModes[i],g.readyMode==i)) { recordChange(); g.readyMode=i; owner.changed(); }
    });
   },"Artwork is independent of the ready trigger and duration.");
   UiLayout.propertyRow("Cooldown",function() {
    combo("##bt_glow_cooldown",cooldownModes[g.cooldownMode],function() {
     for(i in 0...cooldownModes.length) if(ImGui.selectable(cooldownModes[i],g.cooldownMode==i)) { recordChange(); g.cooldownMode=i; owner.changed(); }
    });
   });
   UiLayout.propertyRow("Glow color",function() {
    colorBuf.setF32(0,((g.color>>16)&255)/255.); colorBuf.setF32(4,((g.color>>8)&255)/255.); colorBuf.setF32(8,(g.color&255)/255.);
    var changed=ImGui.colorEdit3("##bt_glow_color",colorBuf);
    if(ImGui.isItemActivated()) glowEditBefore=owner.editorSnapshot();
    if(changed) { g.color=(Std.int(colorBuf.getF32(0)*255)<<16)|(Std.int(colorBuf.getF32(4)*255)<<8)|Std.int(colorBuf.getF32(8)*255); owner.changed(); }
    finishGlowEdit();
   });
   UiLayout.propertyRow("Strength",function() g.strength=glowNumber("##bt_glow_strength",g.strength,2));
   ImGui.beginDisabled(g.readyMode!=solarflare.geaux.SkillAttentionPolicy.AURA);
   try {
    UiLayout.propertyRow("Aura style",function() {
     combo("##bt_glow_style",g.auraStyle,function() {
      for(style in auraStyles) if(ImGui.selectable(style,g.auraStyle==style)) { recordChange(); g.auraStyle=style; owner.changed(); }
     });
    });
    UiLayout.propertyRow("Outside spread",function() g.outer=glowNumber("##bt_glow_outer",g.outer,96));
    UiLayout.propertyRow("Inside spread",function() g.inner=glowNumber("##bt_glow_inner",g.inner,96));
   } catch(e:Dynamic) { ImGui.endDisabled(); throw e; }
   ImGui.endDisabled();
   glowChoice("Preview state","##bt_glow_preview",previewModes,previewMode,function(v) previewMode=v,false);
   UiLayout.propertyRow("Diagnostics",function() { if(ImGui.checkbox("Record glow state##bt_glow_diagnostics",cfg.glowDiagnostics)) owner.changed(); });
  });
  drawGlowPreview(b,g);
 }
 function glowChoice(label:String,id:String,values:Array<String>,value:Int,set:Int->Void,persist:Bool=true):Void {
  UiLayout.propertyRow(label,function() combo(id,values[value],function() {
   for(i in 0...values.length) if(ImGui.selectable(values[i],value==i)) { if(persist) recordChange(); set(i); if(persist) owner.changed(); }
  }));
 }
 function drawGlowPreview(b:BarTerBarConfig,g:solarflare.geaux.SkillAttentionStyle):Void {
  var s=previewSnap; s.clear(); s.kind="skill"; s.present=true; s.available=previewMode!=6;
  s.ready=previewMode==0 || previewMode==3 || previewMode==4 || previewMode==5;
  s.cooldownValid=true; s.affordable=previewMode!=3; s.procValid=true; s.procReady=previewMode==5;
  var now=haxe.Timer.stamp(); s.readyAt=now-g.flashDuration*0.2; s.readyFlashUntil=now+14; s.procStart=now-((now%2.6));
  if(previewMode==1 || previewMode==2 || previewMode==4) { s.cdLeft=previewMode==2 ? Math.min(0.8,g.nearThreshold*0.8) : 8; s.remaining=0.4; s.onCd=true; }
  if(previewMode==4) { s.chargesMax=3; s.charges=1; }
  s.glow=g; s.label="Preview";
  var snaps=owner.snapsFor(b.id); if(selection.cell>=0 && selection.cell<snaps.length) s.iconKey=snaps[selection.cell].iconKey;
  var pos=ImGui.getCursorScreenPos(); var margin:Single=g.reach(52);
  BarTerOverlay.drawCell(ImGui.getWindowDrawList(),s,pos.x+margin,pos.y+margin,52,now,ImGui.getTime(),false,false,b);
  ImGui.dummy(ImGui.vec2(52+margin*2,52+margin*2));
 }
 function finishGlowEdit():Void {
  if(ImGui.isItemDeactivatedAfterEdit() && glowEditBefore!=null) { history.push(glowEditBefore); glowEditBefore=null; }
 }
 function glowNumber(id:String,value:Float,max:Float,min:Float=0):Float {
  glowNumberRef.set(value);
  var changed=ImGui.sliderFloat(id,glowNumberRef,min,max,"%.2f");
  if(ImGui.isItemActivated()) glowEditBefore=owner.editorSnapshot();
  if(changed) owner.changed();
  finishGlowEdit(); return changed ? glowNumberRef.get() : value;
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
  if (!owner.managedEditsReady && (kind=="native" || b.slots[index].nativeActionId.length>0)) { owner.lastStatus="Wait for the weapon change to finish."; return; }
  var native=kind=="native" ? BarTerNativeKeys.action(action) : null;
  if (kind=="native" && (native==null || native.fresh==false)) return;
  recordChange(); owner.reserve(b.id,index);
  var s=b.slots[index];
  if (kind == "item") s.assignItem(id);
  else if (kind == "status") s.assignStatus(id);
  else {
   s.assignSkill(id);
   if (kind == "native") {
    for (bar in owner.config.bars) for (slot in bar.slots) if (slot!=s && slot.nativeActionId==native.action) slot.clearContent();
    s.assignNative(native.action,native.baseId);
   }
  }
  owner.changed(true);
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
    if (!owner.managedEditsReady && (from.slots[cell.index].nativeActionId.length>0 || b.slots[index].nativeActionId.length>0)) { owner.lastStatus="Wait for the weapon change to finish."; return; }
    recordChange();
    owner.reserve(from.id,cell.index); owner.reserve(b.id,index);
    owner.config.swap(from.id,cell.index,b.id,index); selection.selectCell(index,b.slotCount); owner.changed(true);
   }
  }
  if (assignment != null && assignment.epoch == editEpoch && Std.isOfType(assignment.kind,String) && Std.isOfType(assignment.id,String)) {
   assign(b,index,assignment.kind,assignment.id,Std.isOfType(assignment.action,String) ? assignment.action : ""); selection.selectCell(index,b.slotCount);
  }
 }
}
