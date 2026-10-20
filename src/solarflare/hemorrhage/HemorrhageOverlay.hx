package solarflare.hemorrhage;

import imgui.ImGui;
import imgui.Enums.ImGuiCond;
import imgui.Enums.ImGuiWindowFlags;
import imgui.Structs.ImVec4;
import solarflare.ui.CursorCaptureFix;
import solarflare.ui.HudChrome;
import solarflare.ui.SettingsStore;
import solarflare.ui.ThemePalette;
import solarflare.ui.UiScope;

/** Compact presentation of the current/last test; never owns recording state. */
class HemorrhageOverlay {
 // Layout constants the floor is derived from: ImGui default window padding / item spacing and HudChrome's strip + footer.
 static inline var PAD:Single = 8;
 static inline var GAP:Single = 4;
 static inline var FOOTER:Single = HudChrome.RESIZE_GRIP + 12;
 static inline var TITLE:String = "Hemorrhage";
 // Widest values the rows can show; the floor stays stable instead of tracking live text.
 static inline var SAMPLE_STATUS:String = "Draining (99.9 s left)";
 static inline var SAMPLE_ELAPSED:String = "9999.9 s";
 static inline var SAMPLE_CRIT:String = "Crit 100.0%";
 static inline var SAMPLE_BLEED:String = "Bleed DPS 99999.9";
 static inline var SAMPLE_SHARE:String = "Bleed share 100.0%";
 var floorW:Single = 0;
 var floorH:Single = 0;
 var floorFont:Single = -1;
 var floorText:Single = -1;
 var floorFloating:Bool = false;
 var cfg:HemorrhageConfig;
 var hideAction:Void->Void;
 var menuAction:Void->Void;
 var resizeAction:Single->Single->Void;
 var floatColor:ImVec4;
 public function new() {
  hideAction=function() { cfg.hidden.set(true); SettingsStore.markDirty(); };
  menuAction=function() { if(ImGui.menuItem("Open Hemorrhage Tool##hem_tool")) cfg.tool.open.set(true); };
  resizeAction=function(w:Single,h:Single) { cfg.width.set(w); cfg.height.set(h); SettingsStore.markDirty(); };
  floatColor=ImGui.vec4(0,0,0,0);
 }
 public function draw(config:HemorrhageConfig):Void {
  cfg=config;
  if(cfg==null || cfg.hidden.get() || solarflare.ui.HudSuppress.active()) return;
  var chrome=cfg.chrome;
  refreshFloor();
  if(cfg.sizeDirty) {
   ImGui.setNextWindowSize(ImGui.vec2(Math.max(floorW,cfg.width.get()),Math.max(floorH,cfg.height.get())),ImGuiCond.Always);
   cfg.sizeDirty=false;
  }
  chrome.extraMenu=menuAction;
  chrome.clampToViewport(); chrome.applyPos();
  var flags=ImGuiWindowFlags.NoTitleBar|ImGuiWindowFlags.NoCollapse|ImGuiWindowFlags.NoScrollbar|ImGuiWindowFlags.NoScrollWithMouse;
  var began=ImGui.begin("Hemorrhage###SolarFlare.Hemorrhage",null,chrome.windowFlagsKeepClicks(flags));
  var failure:Dynamic=null;
  try {
   if(began) {
    var size=ImGui.getWindowSize(); var parentPos=ImGui.getWindowPos(); chrome.winW=size.x; chrome.winH=size.y;
    if(!chrome.isLocked()) chrome.capturePos();
    if(chrome.beginBody(hideAction,null,"Hemorrhage",false,ImGuiWindowFlags.NoScrollWithMouse,0,FOOTER)) {
     var start=ImGui.getCursorScreenPos(); var available=ImGui.getContentRegionAvail();
     var art=solarflare.resourcetracker.ResourceArtwork.active;
     var skin=art!=null ? art.get("hemorrhage") : null;
     if(skin!=null) skin.paint(start.x,start.y,available.x,available.y,skin.progress,false);
     ImGui.setCursorScreenPos(start);
     if(skin==null || skin.keepContent.get() || !skin.ready()) {
     ImGui.textUnformatted(HemorrhageService.hudStatus);
     ImGui.sameLine(); ImGui.textDisabled(HemorrhageService.hudElapsed);
     ImGui.textUnformatted(HemorrhageService.hudCrit);
     ImGui.textUnformatted(HemorrhageService.hudBleed);
     ImGui.textUnformatted(HemorrhageService.hudShare);
     if(cfg.floatingText.get()) drawFloating();
     } else ImGui.dummy(available);
     if(skin!=null) { var end=ImGui.getCursorScreenPos(); skin.paint(start.x,start.y,available.x,available.y,skin.progress,true); ImGui.setCursorScreenPos(end); }
     chrome.contentLeadX=start.x-parentPos.x; chrome.contentLeadY=start.y-parentPos.y;
     chrome.contentWidth=available.x; chrome.contentHeight=available.y;
    }
    chrome.closeBodyChild();
    if(!chrome.isCollapsed()) chrome.captureSize(cfg.width,cfg.height);
    chrome.drawResizeCorner("hemorrhage",!chrome.isLocked(),floorW,floorH,1600,1200,resizeAction,8);
    chrome.pollTransparentSurfaceDrag("hemorrhage",!chrome.isLocked());
   }
  } catch(e:Dynamic) failure=e;
  HudChrome.endOverlayWindow(began,chrome); chrome.extraMenu=null;
  if(failure!=null) UiScope.report("window","hemorrhage",failure);
 }
 /** Smallest outer size that still shows the title strip, the four text rows and the grip footer. Rebuilt only when the font or floating-text settings change. */
 function refreshFloor():Void {
  var font=ImGui.getFontSize(); var floating=cfg.floatingText.get(); var text=cfg.textSize.get();
  if(floorW>0 && font==floorFont && floating==floorFloating && (!floating || text==floorText)) return;
  floorFont=font; floorFloating=floating; floorText=text;
  var line=ImGui.getTextLineHeight();
  var row1=ImGui.calcTextSize(SAMPLE_STATUS).x+8+ImGui.calcTextSize(SAMPLE_ELAPSED).x;
  var content=Math.max(Math.max(row1,ImGui.calcTextSize(SAMPLE_CRIT).x),Math.max(ImGui.calcTextSize(SAMPLE_BLEED).x,ImGui.calcTextSize(SAMPLE_SHARE).x));
  // The centered caption must clear the sun on the left and the close glyph on the right.
  content=Math.max(content,ImGui.calcTextSize(TITLE).x+2*(HudChrome.SUN+6)-2*PAD);
  floorW=Math.ceil(content+2*PAD);
  var h=PAD+HudChrome.STRIP+2+4*line+3*GAP+FOOTER+PAD;
  if(floating) h+=GAP+HemorrhageFloatLayout.stageHeight(text);
  floorH=Math.ceil(h);
 }
 function drawFloating():Void {
  var font=ImGui.getFont(); if(font==null) return;
  ImGui.pushFont(font,cfg.textSize.get());
  var pos=ImGui.getCursorScreenPos(); var width=ImGui.getContentRegionAvail().x;
  var textHeight=ImGui.getTextLineHeight(); var height:Single=HemorrhageFloatLayout.stageHeight(textHeight);
  ImGui.dummy(ImGui.vec2(width,height));
  var dl=ImGui.getWindowDrawList();
  ImGui.ImDrawList_PushClipRect(dl,pos,ImGui.vec2(pos.x+width,pos.y+height),true);
  var failure:Dynamic=null;
  try {
   var rows=HemorrhageCache.floating; var palette=ThemePalette.current();
   for(i in 0...rows.length) {
    var row=rows[i]; var age=HemorrhageService.now-row.at;
    var progress=Math.max(0,Math.min(1,age/Math.max(0.5,cfg.textLifetime.get())));
    if(age<0 || progress>=1) continue;
    var size=ImGui.calcTextSize(row.text);
    var x=pos.x+Math.max(0,(width-size.x)*0.5);
    var y=pos.y+height-textHeight-(rows.length-1-i)*(textHeight+6)-32*progress;
    var color=row.bleed ? palette.accent : palette.text;
    floatColor.x=color.x; floatColor.y=color.y; floatColor.z=color.z;
    floatColor.w=color.w*Math.min(1,(1-progress)/0.4);
    ImGui.ImDrawList_AddText_Vec2(dl,ImGui.vec2(x,y),ImGui.colorConvertFloat4ToU32(floatColor),row.text);
   }
  } catch(e:Dynamic) failure=e;
  ImGui.ImDrawList_PopClipRect(dl); ImGui.popFont();
  if(failure!=null) UiScope.report("floating text","hemorrhage",failure);
 }
}
