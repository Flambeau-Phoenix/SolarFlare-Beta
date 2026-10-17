package solarflare.stacks;

import haxe.Json;
import imgui.ImGui;
import imgui.Enums.ImGuiWindowFlags;
import imgui.ref.FloatRef;
import imgui.ref.IntRef;
import imgui.ref.BoolRef;
import solarflare.ui.ByteUtil;
import solarflare.ui.BuilderSlider;
import solarflare.ui.ConfigPanel;
import solarflare.ui.EditorWindow;
import solarflare.ui.FeatureProfiles;
import solarflare.ui.ImGuiLists;
import solarflare.ui.SettingsStore;
import solarflare.ui.ThemePalette;
import solarflare.ui.UiChrome;
import solarflare.ui.UiLayout;
import solarflare.ui.UiScope;
import solarflare.ui.UndoManager;
import solarflare.cdb.AuraCatalog;
import solarflare.stacks.StackConfig.StackTrackerConfig;

private typedef CatalogEntry={id:String,name:String,kind:String,searchKey:String};

/** Independent editor. All preview values and text buffers belong to the builder. */
class StackBuilder {
	var owner:Stacks;
	var host:ConfigPanel;
	var selectedId:String="";
	var nameBuf=new hl.Bytes(128);
	var statusBuf=new hl.Bytes(256);
	var iconBuf=new hl.Bytes(256);
	var searchBuf=new hl.Bytes(128);
	var query:String="";
	var picker:String="status";
	var candidates:Array<CatalogEntry>=[];
	var statusCandidates:Array<CatalogEntry>=[];
	var numbers:Map<String,FloatRef>=new Map();
	var toggle=new BoolRef(false);
	var previewCount=new IntRef(3);
	var previewUnknown=new BoolRef(false);
	var previewState=new StackState();
	var activeBuf=new hl.Bytes(16);
	var emptyBuf=new hl.Bytes(16);
	var history=new UndoManager<String>(40);
	var bodyFn:Void->Void;
	var snapshotFn:Void->Void;
	public function new(owner:Stacks,host:ConfigPanel) {
		this.owner=owner; this.host=host; bodyFn=body; snapshotFn=snapshot;
		ByteUtil.clearBytes(nameBuf,128); ByteUtil.clearBytes(statusBuf,256); ByteUtil.clearBytes(iconBuf,256); ByteUtil.clearBytes(searchBuf,128);
	}
	public function clearHistory():Void history=new UndoManager<String>(40);
	public function clearTransientState():Void {
		selectedId=""; picker="status"; query=""; candidates.resize(0); numbers.clear();
		ByteUtil.clearBytes(searchBuf,128); BuilderSlider.clearPreciseState();
	}
	public function select(id:String):Void {
		selectedId=id; numbers.clear(); BuilderSlider.clearPreciseState();
		var t=owner.config.find(id); if(t==null) return;
		ByteUtil.fillBuf(nameBuf,128,t.name); ByteUtil.fillBuf(statusBuf,256,t.statusId); ByteUtil.fillBuf(iconBuf,256,t.iconId);
		query=""; ByteUtil.clearBytes(searchBuf,128); refreshCandidates();
	}
	function historyState():String return Json.stringify({stacks:owner.dump(),uiLayouts:host.uiLayouts.dumpCurrent(host)});
	function restoreHistory(s:String):Void { var d:Dynamic=Json.parse(s); owner.apply(d.stacks,true); host.uiLayouts.load(host,d.uiLayouts,[]); }
	function snapshot():Void history.push("Edit Stacks",historyState());
	function changed():Void { SettingsStore.markDirty(); solarflare.ObserveDemand.markStatusDemandDirty(); }
	public function draw():Void {
		if(!owner.open.get()) return;
		EditorWindow.drawMenuWindow("Stacks###SolarFlare.StackBuilder",owner.open,980,760,bodyFn);
	}
	function body():Void {
		FeatureProfiles.drawToolbar(host,"stacks","stacks_builder");
		UiChrome.gap();
		ImGui.beginDisabled(owner.config.trackers.length>=64);
		if(UiChrome.accentButton("Add tracker##st_add")) {
			snapshot(); var t=owner.config.add(); t.name="Stacks "+owner.config.trackers.length; owner.rebuild(); select(t.id); changed();
		}
		ImGui.endDisabled(); ImGui.sameLine();
		ImGui.beginDisabled(!history.canUndo());
		if(UiChrome.ghostButton("Undo##st_undo")) { var s=history.undo(historyState()); if(s!=null) { restoreHistory(s); changed(); } }
		ImGui.endDisabled(); ImGui.sameLine();
		ImGui.beginDisabled(!history.canRedo());
		if(UiChrome.ghostButton("Redo##st_redo")) { var s=history.redo(historyState()); if(s!=null) { restoreHistory(s); changed(); } }
		ImGui.endDisabled();
		if(owner.config.trackers.length==0) { ImGui.textWrapped("Add a tracker, choose a status, and arrange one cell for each stack."); return; }
		if(owner.config.find(selectedId)==null) select(owner.config.trackers[0].id);
		UiChrome.gap();
		var avail=ImGui.getContentRegionAvail().x;
		if(avail>=780) {
			UiScope.child("##st_list",ImGui.vec2(190,0),drawList);
			ImGui.sameLine(0,8);
			UiScope.child("##st_editor",ImGui.vec2(0,0),drawEditor);
		} else {
			UiScope.child("##st_list",ImGui.vec2(0,110),drawList);
			UiScope.child("##st_editor",ImGui.vec2(0,0),drawEditor);
		}
	}
	function drawList():Void {
		for(t in owner.config.trackers) if(ImGui.selectable(t.name+"###st_"+t.id,t.id==selectedId)) select(t.id);
	}
	function drawEditor():Void {
		var t=owner.config.find(selectedId); if(t==null) return;
		var v=owner.view(t.id); if(v==null) return;
		UiChrome.sectionHeader("Tracker");
		UiLayout.propertyGrid("##st_target",function() {
			UiLayout.propertyRow("Name",function() { if(ImGui.inputText("##st_name",nameBuf,128)) { t.name=ByteUtil.readBytes(nameBuf,128); changed(); } });
			UiLayout.propertyRow("Status ID",function() { if(ImGui.inputText("##st_status",statusBuf,256)) { t.statusId=ByteUtil.readBytes(statusBuf,256); v.state.reset(); changed(); } });
			UiLayout.propertyRow("Enabled",function() { toggle.set(t.enabled); if(ImGui.checkbox("##st_enabled",toggle)) { snapshot(); t.enabled=toggle.get(); changed(); } });
			UiLayout.propertyRow("Showing",function() { toggle.set(!t.hidden); if(ImGui.checkbox("##st_show",toggle)) { snapshot(); t.hidden=!toggle.get(); changed(); } });
		});
		picker="status"; drawPicker(t);
		UiChrome.sectionHeader("Preview");
		UiLayout.propertyGrid("##st_preview_props",function() {
			UiLayout.propertyRow("Stacks",function() { ImGui.inputInt("##st_preview_count",previewCount,1,10); previewCount.set(Std.int(Math.max(0,previewCount.get()))); });
			UiLayout.propertyRow("Unavailable",function() { ImGui.checkbox("##st_preview_unknown",previewUnknown); });
		});
		previewState.set(!previewUnknown.get(),true,true,previewCount.get());
		UiScope.child("##st_preview",ImGui.vec2(0,Math.min(240,StackLayout.height(t)+20)),function() StackRenderer.draw(t,previewState),0,ImGuiWindowFlags.HorizontalScrollbar);
		UiChrome.sectionHeader("Layout and appearance");
		UiLayout.propertyGrid("##st_layout",function() {
			numberRow(t,"Capacity","capacity",1,128,"%.0f");
			UiLayout.propertyRow("Arrangement",function() { var picked=UiLayout.stringCombo("##st_layout_kind",t.layout,StackConfig.layouts,choiceLabel); if(picked!=null) { snapshot(); t.layout=picked; changed(); } });
			if(t.layout=="grid") {
				UiLayout.propertyRow("Wrap by",function() { var picked=UiLayout.stringCombo("##st_wrap_by",t.wrapBy,StackConfig.axes,choiceLabel); if(picked!=null) { snapshot(); t.wrapBy=picked; changed(); } });
				numberRow(t,t.wrapBy=="rows" ? "Rows" : "Columns","wrap",1,128,"%.0f");
			}
			UiLayout.propertyRow("Reverse fill",function() { toggle.set(t.reverse); if(ImGui.checkbox("##st_reverse",toggle)) { snapshot(); t.reverse=toggle.get(); changed(); } });
			numberRow(t,"Cell size","cellSize",8,128,"%.0f px"); numberRow(t,"Spacing","gap",0,32,"%.0f px");
			UiLayout.propertyRow("Visual",function() { var picked=UiLayout.stringCombo("##st_shape",t.shape,StackConfig.shapes,choiceLabel); if(picked!=null) { snapshot(); t.shape=picked; changed(); } });
			UiLayout.propertyRow("Active color",function() color(t,true));
			UiLayout.propertyRow("Empty color",function() color(t,false));
			UiLayout.propertyRow("Count text",function() { toggle.set(t.showCount); if(ImGui.checkbox("##st_count",toggle)) { snapshot(); t.showCount=toggle.get(); changed(); } });
			UiLayout.propertyRow("Hide at zero",function() { toggle.set(t.hideAtZero); if(ImGui.checkbox("##st_zero",toggle)) { snapshot(); t.hideAtZero=toggle.get(); changed(); } });
		});
		ImGui.textDisabled(StackLayout.columns(t)+" columns × "+StackLayout.rows(t)+" rows");
		if(t.shape=="icon") {
			UiLayout.propertyGrid("##st_icon_props",function() {
				UiLayout.propertyRow("Icon ID",function() { if(ImGui.inputText("##st_icon",iconBuf,256)) { t.iconId=ByteUtil.readBytes(iconBuf,256); changed(); } });
			});
			picker="icon"; drawPicker(t);
		}
		UiChrome.sectionHeader("Window");
		UiLayout.propertyGrid("##st_window",function() {
			UiLayout.propertyRow("Lock",function() { if(ImGui.checkbox("##st_lock",v.chrome.locked)) changed(); });
			UiLayout.propertyRow("Transparent",function() { if(ImGui.checkbox("##st_trans",v.chrome.transparent)) changed(); });
			v.chrome.drawPositionRow("st_pos");
		});
		ImGui.beginDisabled(owner.config.trackers.length>=64);
		if(UiChrome.ghostButton("Duplicate tracker##st_duplicate")) { snapshot(); var copy=owner.config.duplicate(t.id); owner.rebuild(); select(copy.id); changed(); }
		ImGui.endDisabled(); ImGui.sameLine();
		if(UiChrome.ghostButton("Delete this tracker##st_delete")) { snapshot(); host.uiLayouts.forgetWidget("stacks:"+t.id); owner.config.remove(t.id); owner.rebuild(); selectedId=""; changed(); }
	}
	function numberRow(t:StackTrackerConfig,label:String,key:String,min:Single,max:Single,format:String):Void {
		if(!numbers.exists(key)) numbers.set(key,new FloatRef(0));
		var ref=numbers.get(key); ref.set(Reflect.field(t,key));
		UiLayout.propertyRow(label,function() {
			if(BuilderSlider.precise("##st_num_"+key,ref,min,max,format,snapshotFn)) {
				if(key=="capacity" || key=="wrap") Reflect.setField(t,key,Std.int(ref.get())); else Reflect.setField(t,key,ref.get());
				changed();
			}
		});
	}
	function color(t:StackTrackerConfig,active:Bool):Void {
		var theme=ThemePalette.current(); var n=active ? t.activeColor : t.emptyColor;
		var col=n==null ? (active ? theme.accent : theme.cellBg) : ImGui.colorConvertU32ToFloat4(n);
		var buf=active ? activeBuf : emptyBuf;
		buf.setF32(0,col.x); buf.setF32(4,col.y); buf.setF32(8,col.z); buf.setF32(12,col.w);
		ImGui.setNextItemWidth(120);
		if(ImGui.colorEdit4(active ? "##st_lit" : "##st_dim",buf)) {
			var value=ImGui.colorConvertFloat4ToU32(ImGui.vec4(buf.getF32(0),buf.getF32(4),buf.getF32(8),buf.getF32(12)));
			snapshot(); if(active) t.activeColor=value; else t.emptyColor=value; changed();
		}
		ImGui.sameLine(); if(UiChrome.ghostButton(active ? "Theme##st_lit_theme" : "Theme##st_dim_theme")) { snapshot(); if(active) t.activeColor=null; else t.emptyColor=null; changed(); }
	}
	static function choiceLabel(s:String):String return s;
	function refreshCandidates():Void {
		candidates.resize(0); statusCandidates.resize(0);
		for(e in AuraCatalog.entries) if(AuraCatalog.entryMatchesSearch(e,query)) { candidates.push(e); if(AuraCatalog.matchesSubject(e.kind,"status")) statusCandidates.push(e); }
	}
	function drawPicker(t:StackTrackerConfig):Void {
		if(!UiChrome.groupHeader(picker=="icon" ? "Choose game icon##st_icons" : "Choose status##st_statuses")) return;
		ImGui.pushID_Str(picker);
		if(ImGui.inputText("Search##st_search",searchBuf,128)) { query=ByteUtil.readBytes(searchBuf,128); refreshCandidates(); }
		UiScope.child("##st_choices",ImGui.vec2(0,160),function() {
			var choices=picker=="status" ? statusCandidates : candidates;
			ImGuiLists.forVisible(choices.length,function(index:Int) {
				var e=choices[index];
				if(ImGui.selectable(e.name+" ["+e.id+"]##st_choice_"+e.id,picker=="icon" ? t.iconId==e.id : t.statusId==e.id)) {
					snapshot();
					if(picker=="icon") { t.iconId=e.id; ByteUtil.fillBuf(iconBuf,256,e.id); }
					else { t.statusId=e.id; owner.view(t.id).state.reset(); ByteUtil.fillBuf(statusBuf,256,e.id); }
					changed();
				}
			});
		});
		ImGui.popID();
	}
}
