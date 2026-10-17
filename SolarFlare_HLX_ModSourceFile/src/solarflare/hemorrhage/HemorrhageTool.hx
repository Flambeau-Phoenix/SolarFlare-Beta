package solarflare.hemorrhage;

import imgui.ImGui;
import imgui.Enums.ImGuiTableFlags;
import imgui.Enums.ImGuiTableColumnFlags;
import imgui.ref.BoolRef;
import solarflare.ui.ByteUtil;
import solarflare.ui.CursorCaptureFix;
import solarflare.ui.EditorWindow;
import solarflare.ui.ImGuiLists;
import solarflare.ui.UiActionQueue;
import solarflare.ui.UiChrome;
import solarflare.ui.UiLayout;
import solarflare.ui.UiScope;

/** Independent editor. Read snapshots here; execute requests during observation. */
class HemorrhageTool {
	public var open = new BoolRef(false);
	var labelBuf = new hl.Bytes(321);
	var notesBuf = new hl.Bytes(4097);
	var tab:Int = 0;
	var inspecting:Int = 0;
	var pendingDelete:String = "";
	var drawnRevision:Int = -1;
	var autoScroll:BoolRef;
	var body:Void->Void;
	var startAction:Void->Void;
	static var tabs = ["Summary##hem_summary_tab","Abilities##hem_abilities_tab","Events##hem_events_tab","Saved Runs##hem_saved_tab"];
	public function new() {
		ByteUtil.clearBytes(labelBuf,321); ByteUtil.clearBytes(notesBuf,4097);
		body=drawBody;
		startAction=function() HemorrhageService.start(ByteUtil.readString(labelBuf,321,true),ByteUtil.readString(notesBuf,4097));
	}
	public function clearTransientState():Void {
		pendingDelete = "";
		// ImGui clears entry focus at camera transition. Keep draft notes for the next test.
	}
	public function draw(autoScroll:BoolRef):Void {
		if(!open.get() || !CursorCaptureFix.cursorFree) return;
		this.autoScroll=autoScroll;
		EditorWindow.drawMenuWindow("Hemorrhage Tool###SolarFlare.HemorrhageTool",open,940,720,body);
	}
	function drawBody():Void {
		UiChrome.sectionHeader("Hemorrhage build tests");
		ImGui.textUnformatted(HemorrhageService.hudStatus);
		UiLayout.propertyGrid("##hem_test_details",function() {
			UiLayout.propertyRow("Build label",function() { ImGui.inputText("##hem_build",labelBuf,321); });
			UiLayout.propertyRow("Test notes",function() { ImGui.inputText("##hem_notes",notesBuf,4097); },"Record target, rotation, talents and other changed stats. Saved when Start is pressed.");
		});
		if(!HemorrhageService.active()) {
			if(UiChrome.accentButton("Start##hem_start",ImGui.vec2(100,28))) UiActionQueue.custom(startAction);
		} else if(HemorrhageService.run.state=="Recording" || HemorrhageService.run.state=="Armed") {
			if(UiChrome.accentButton("Finish##hem_finish",ImGui.vec2(100,28))) UiActionQueue.custom(HemorrhageService.finish);
		} else ImGui.textDisabled("Collecting remaining ticks…");
		ImGui.textWrapped(HemorrhageService.message);
		if(HemorrhageService.archive!=null && HemorrhageService.archive.error!="") {
			ImGui.textWrapped(HemorrhageService.archive.error);
			if(UiChrome.ghostButton("Retry save##hem_retry",ImGui.vec2(110,26))) UiActionQueue.custom(HemorrhageService.retrySave);
		}
		ImGui.separator();
		UiLayout.inlineSplit("##hem_tabs",4,function(i:Int,w:Single) { if(UiChrome.navButton(tabs[i],tab==i,ImGui.vec2(w,28))) tab=i; });
		UiScope.child("##hem_content",ImGui.vec2(0,0),drawContent);
	}
	function drawContent():Void switch(tab) {
		case 1: drawAbilities();
		case 2: drawEvents();
		case 3: drawSaved();
		default: drawSummary();
	}
	function drawSummary():Void {
		var v=inspectedView();
		if(inspecting!=0 && UiChrome.ghostButton("Show current test##hem_current",ImGui.vec2(160,26))) inspecting=0;
		ImGui.textUnformatted(v.title); ImGui.textWrapped(v.quality);
		UiLayout.propertyGrid("##hem_summary",function() { for(row in v.rows) UiLayout.propertyRow(row.label,function() ImGui.textUnformatted(row.value)); },0,245);
		ImGui.textWrapped("Observed crit frequency counts positive direct damage events, including attacks that may not be able to crit. It differs from character-sheet crit chance. Repeat comparable tests; no optimal crit target is inferred.");
	}
	function drawAbilities():Void {
		UiScope.table("##hem_abilities",4,function() {
			ImGui.tableSetupColumn("Ability",ImGuiTableColumnFlags.WidthStretch,2);
			ImGui.tableSetupColumn("Events",ImGuiTableColumnFlags.WidthStretch,1);
			ImGui.tableSetupColumn("Damage",ImGuiTableColumnFlags.WidthStretch,1);
			ImGui.tableSetupColumn("Bleed",ImGuiTableColumnFlags.WidthStretch,1);
			ImGui.tableHeadersRow();
			for(a in inspectedView().abilities) { ImGui.tableNextRow(); cell(a.label); cell(a.hits); cell(a.damage); cell(a.bleed); }
		},ImGuiTableFlags.SizingStretchProp|ImGuiTableFlags.RowBg);
		ImGui.textWrapped("Talent procs remain under their recorded ability. Bleed totals include physical and Spark Hemorrhage ticks. No hypothetical multiplier contribution is added.");
	}
	function drawEvents():Void {
		UiScope.table("##hem_events",4,function() {
			ImGui.tableSetupColumn("Enemy",ImGuiTableColumnFlags.WidthStretch,1);
			ImGui.tableSetupColumn("Ability",ImGuiTableColumnFlags.WidthStretch,1.5);
			ImGui.tableSetupColumn("Kind",ImGuiTableColumnFlags.WidthStretch,1);
			ImGui.tableSetupColumn("Damage",ImGuiTableColumnFlags.WidthStretch,1);
			ImGui.tableHeadersRow();
			ImGuiLists.forVisible(HemorrhageCache.count,drawEvent);
		},ImGuiTableFlags.SizingStretchProp|ImGuiTableFlags.RowBg);
		if(HemorrhageCache.count==0) ImGui.textDisabled("Start a test to collect damage. Only the latest test retains event details.");
		if(autoScroll.get() && drawnRevision!=HemorrhageCache.revision) ImGui.setScrollFromPosY(ImGui.getCursorPosY(),1);
		drawnRevision=HemorrhageCache.revision;
	}
	function drawEvent(i:Int):Void {
		var r=HemorrhageCache.rowAt(i); if(r==null) return;
		ImGui.tableNextRow(); cell(r.enemy); cell(r.ability); cell(r.kindText); cell(r.amountText);
	}
	function drawSaved():Void {
  ImGui.textUnformatted(HemorrhageService.countLabel);
  if(HemorrhageService.saved.length==0) {
   ImGui.textWrapped("Complete a test to save its summary automatically. Saved tests belong to this character and remain separate from profiles.");
   return;
  }
  UiLayout.propertyGrid("##hem_compare_picks",function() {
   UiLayout.propertyRow("Baseline A",function() drawChoice(true));
   UiLayout.propertyRow("Comparison B",function() drawChoice(false));
  });
  if(UiChrome.ghostButton("Export selected CSV##hem_export",ImGui.vec2(180,26))) UiActionQueue.custom(HemorrhageService.exportSelected);
  ImGui.textDisabled("Rate differences are percentage points (pp); Change is relative to A.");
  if(HemorrhageService.comparison.length>0) UiScope.table("##hem_compare",5,function() {
   ImGui.tableSetupColumn("Metric",ImGuiTableColumnFlags.WidthStretch,1.8);
   ImGui.tableSetupColumn("A",ImGuiTableColumnFlags.WidthStretch,1);
   ImGui.tableSetupColumn("B",ImGuiTableColumnFlags.WidthStretch,1);
   ImGui.tableSetupColumn("B − A",ImGuiTableColumnFlags.WidthStretch,1);
   ImGui.tableSetupColumn("Change",ImGuiTableColumnFlags.WidthStretch,1);
   ImGui.tableHeadersRow();
   for(r in HemorrhageService.comparison) { ImGui.tableNextRow(); cell(r.label); cell(r.a); cell(r.b); cell(r.delta); cell(r.percent); }
  },ImGuiTableFlags.SizingStretchProp|ImGuiTableFlags.RowBg);
  drawSelected(true); drawSelected(false);
 }
 function drawChoice(a:Bool):Void {
  var selected=a ? HemorrhageService.selectedA : HemorrhageService.selectedB;
  if(ImGui.beginCombo(a ? "##hem_pick_a" : "##hem_pick_b",selected==null ? "Select a saved test" : selected.label)) {
   for(item in HemorrhageService.saved) if(ImGui.selectable(item.choiceLabel,selected!=null && item.id==selected.id)) {
    if(a) HemorrhageService.compareA=item.id; else HemorrhageService.compareB=item.id;
    UiActionQueue.custom(HemorrhageService.refreshComparison);
   }
   ImGui.endCombo();
  }
 }
 function drawSelected(a:Bool):Void {
  var item=a ? HemorrhageService.selectedA : HemorrhageService.selectedB;
  if(item==null) return;
  UiChrome.subHeader(a ? "Baseline A" : "Comparison B");
  ImGui.textUnformatted(item.label);
  ImGui.textWrapped(item.run.notes);
  ImGui.textWrapped(item.view.quality);
  ImGui.textWrapped(item.metadata);
  if(UiChrome.ghostButton(a ? "Inspect A##hem_inspect_a" : "Inspect B##hem_inspect_b",ImGui.vec2(120,26))) { inspecting=a ? 1 : 2; tab=0; }
  ImGui.sameLine();
  if(UiChrome.ghostButton(a ? "Delete A##hem_delete_a" : "Delete B##hem_delete_b",ImGui.vec2(110,26))) pendingDelete=item.id;
  if(pendingDelete==item.id) {
   ImGui.textWrapped("Delete this saved test permanently?");
   if(UiChrome.ghostButton(a ? "Confirm delete##hem_confirm_a" : "Confirm delete##hem_confirm_b",ImGui.vec2(130,26))) {
    var id=item.id; UiActionQueue.custom(function() HemorrhageService.deleteRun(id)); pendingDelete="";
   }
   ImGui.sameLine();
   if(UiChrome.ghostButton(a ? "Cancel##hem_cancel_a" : "Cancel##hem_cancel_b",ImGui.vec2(90,26))) pendingDelete="";
  }
 }
 function inspectedView():HemorrhageView {
  if(inspecting==1 && HemorrhageService.selectedA!=null) return HemorrhageService.selectedA.view;
  if(inspecting==2 && HemorrhageService.selectedB!=null) return HemorrhageService.selectedB.view;
  return HemorrhageService.view;
 }
	static inline function cell(text:String):Void { ImGui.tableNextColumn(); ImGui.textUnformatted(text); }
}
