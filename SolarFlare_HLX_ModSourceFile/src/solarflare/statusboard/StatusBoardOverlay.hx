package solarflare.statusboard;
import imgui.ImGui;
import solarflare.ui.HUDWidgetWindow;

class StatusBoardOverlay {
	/** Cached callbacks; current UI configuration and frozen snaps are refreshed per draw. */
	var hudCfg:StatusBoardConfig;
 var visualBounds=new solarflare.ui.HUDVisualBounds();
	var hudColumns:Int;
	var hudWidth:Single;
	var hudHeight:Single;
	var hudBodyFn:imgui.Structs.ImVec2->Void;
	var hudResizeFn:Single->Single->Void;

 static inline var GAP:Int = 4;
 var windowId:String;
 var windowTitle:String;
 public function new(windowId:String = "SolarFlare.StatusBoard", windowTitle:String = "Statuses") {
		this.windowId = windowId; this.windowTitle = windowTitle;
		hudBodyFn = hudBody;
		hudResizeFn = hudResize;
	}
 public function draw(cfg:StatusBoardConfig, edit:Void->Void, hide:Void->Void, title:String = null):Void {
  if (cfg == null || !cfg.demand()) return;
  var n=cfg.visible.length;
  if (n == 0 && cfg.chrome.locked.get()) return;
  var unlocked=!cfg.chrome.locked.get();
  var size=StatusBoardLayout.size(n,cfg.slotSize,cfg.columns,unlocked,cfg.contentWidth,cfg.contentHeight,cfg.showSeconds,cfg.growthDirection=="up");
  var cols=size.columns; var w=size.width; var h=size.height;
  hudCfg = cfg;
  hudColumns = cols; hudWidth = w; hudHeight = h;
  visualBounds.reset(w,h);
  if (n>0 && cfg.growthDirection=="up") {
   var top=StatusBoardLayout.rowY(n-1,cols,cfg.slotSize,cfg.showSeconds,h,true);
   visualBounds.include(0,top,w,cfg.slotSize+StatusBoardLayout.timerBand(cfg.slotSize,cfg.showSeconds));
  }
  HUDWidgetWindow.draw(windowId,title != null ? title : windowTitle,cfg.chrome,w,h,hudBodyFn,edit,hide,false,null,hudResizeFn,cfg.growthDirection=="up" ? visualBounds : null);
  hudCfg = null;
 }

	function hudBody(size:imgui.Structs.ImVec2):Void {
		var cfg = hudCfg; var n = cfg.visible.length;
		var cols = hudColumns; var w = hudWidth; var h = hudHeight;
		var band:Single=StatusBoardLayout.timerBand(cfg.slotSize,cfg.showSeconds);
		var origin=ImGui.getCursorScreenPos(); var dl=ImGui.getWindowDrawList();
		if (n == 0) ImGui.textDisabled("Status placement preview");
		for (i in 0...n) {
		 var s=cfg.visible[i]; var v=cfg.visuals[i];
		 var x:Single=origin.x+(i%cols)*(cfg.slotSize+GAP);
		 var y:Single=origin.y+StatusBoardLayout.rowY(i,cols,cfg.slotSize,cfg.showSeconds,h,cfg.growthDirection=="up");
		 StatusBoardRenderer.draw(dl,v,x,y,cfg.slotSize,band);
		 ImGui.setCursorScreenPos(ImGui.vec2(x,y));
		 ImGui.invisibleButton(v.hitId,ImGui.vec2(cfg.slotSize,cfg.slotSize+band));
		 if (ImGui.isItemHovered()) StatusBoardTooltipRenderer.draw(s.instanceId,s.label);
		 if (!cfg.chrome.locked.get() && ImGui.beginPopupContextItem(v.popupId)) {
		  try { if (ImGui.menuItem("Hide this status")) cfg.hideStatus(s.id); }
		  catch(e:Dynamic) { ImGui.endPopup(); throw e; }
		  ImGui.endPopup();
		 }
		}
		ImGui.setCursorScreenPos(origin); ImGui.dummy(ImGui.vec2(w,h));
	}

	function hudResize(newW:Single,newH:Single):Void {
		var cfg = hudCfg;
		cfg.resize(newW,newH,GAP);
	}
}
