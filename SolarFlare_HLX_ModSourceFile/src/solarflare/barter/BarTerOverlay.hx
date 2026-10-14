package solarflare.barter;

import imgui.ImGui;
import solarflare.ui.GameIcons;
import solarflare.ui.HudChrome;
import solarflare.ui.HUDWidgetWindow;
import solarflare.ui.SettingsStore;
import solarflare.ui.ThemePalette;
import solarflare.ui.VectorGlow;
import solarflare.statusboard.StatusIcon;
import solarflare.ui.UiCol;
import solarflare.geaux.SkillAttentionPolicy;
import solarflare.geaux.SkillAttentionRenderer;

/** One renderer for the HUD and bounded builder preview. No engine or icon discovery. */
class BarTerOverlay {
	static var defaultGlow=new solarflare.geaux.SkillAttentionStyle();
	var visualBounds=new solarflare.ui.HUDVisualBounds();
	/** Cached callbacks; current UI configuration and frozen snaps are refreshed per draw. */
	var hudBar:BarTerBarConfig;
	var hudSnaps:Array<BarTerSnap>;
	var hudClick:Int->Void;
	var hudContext:Int->Void;
	var hudShowHotkeys:Bool;
	var hudBodyFn:imgui.Structs.ImVec2->Void;
	var hudResizeFn:Single->Single->Void;

 public function new() {
		hudBodyFn = hudBody;
		hudResizeFn = hudResize;
	}
 public function draw(bar:BarTerBarConfig,snaps:Array<BarTerSnap>,chrome:HudChrome,
  edit:Void->Void,hide:Void->Void,click:Int->Void,showHotkeys:Bool=true,context:Int->Void=null,barMenu:Void->Void=null):Void {
  var w:Single=BarTerLayout.width(bar.columns,bar.slotSize);
  var h:Single=BarTerLayout.height(bar.slotCount,bar.columns,bar.slotSize);
  var hasContent=false;
  for (i in 0...bar.slotCount) if (i < snaps.length && !BarTerCellState.empty(snaps[i])) { hasContent=true; break; }
  if (!hasContent && !bar.showEmptyCells) return;
  hudBar = bar;
  hudSnaps = snaps;
  hudClick = click;
  hudContext = context;
  hudShowHotkeys = showHotkeys;
  var reach=bar.glow.reach(bar.slotSize);
  visualBounds.reset(w,h); visualBounds.include(-reach,-reach,w+reach*2,h+reach*2);
  HUDWidgetWindow.draw("SolarFlare.BarTer."+bar.id,bar.name,chrome,w,h,hudBodyFn,edit,hide,false,barMenu,hudResizeFn,visualBounds);
  hudBar = null; hudSnaps = null; hudClick = null; hudContext = null;
 }
 public static function tooltip(s:BarTerSnap):String {
  if (s.kind == "status") {
   if (!s.status.known) return s.label+"\n"+s.statusId+"\nPresence unavailable · display only";
   if (!s.available) return s.label+"\n"+s.statusId+"\nInactive · display only";
   return StatusIcon.tooltip(s.status)+"\nDisplay only";
  }
  var tip=s.label.length > 0 ? s.label : s.isItem ? s.itemKind : s.skillId;
  if (s.isItem) return tip+"\nStack "+s.count+(s.usable ? "\nClick / key to use." : "\nNot currently usable.");
  tip+="\nBinding: "+s.keyLabel+(s.nativeActionId.length > 0 ? " ("+s.nativeActionId+")" : " (no native action matched)");
  if (!s.available) tip+="\nUnavailable in the current native actions.";
  else tip+="\nActivate with the native keyboard binding.";
  if (s.chargesMax > 1) tip+="\nCharges "+s.charges+"/"+s.chargesMax;
  if (s.cdLeft > 0.05) tip+="\nCooldown "+Math.ceil(s.cdLeft)+"s";
  return tip;
 }
 public static function drawTooltip(s:BarTerSnap):Void {
  if (s.kind=="status" && s.available && s.status.instanceId.length>0)
   solarflare.statusboard.StatusBoardTooltipRenderer.draw(s.status.instanceId,s.label);
  else ImGui.setTooltip(tooltip(s));
 }
 public static function drawCell(dl:Dynamic,s:BarTerSnap,x:Single,y:Single,size:Single,
  now:Float,time:Float,hovered:Bool,showHotkeys:Bool,bar:BarTerBarConfig=null):Void {
  var theme=ThemePalette.current();
  var useTheme=bar != null && bar.colorMode == "theme";
  var custom=bar != null && bar.colorMode == "custom";
  var fill=useTheme ? ImGui.colorConvertFloat4ToU32(theme.cellBg) : UiCol.rgb(custom ? bar.fillColor : 0x181B20,225);
  var border=useTheme ? ImGui.colorConvertFloat4ToU32(theme.border) : UiCol.rgb(custom ? bar.borderColor : 0x626970,210);
  var accent=useTheme ? ImGui.colorConvertFloat4ToU32(theme.accent) : UiCol.rgb(custom ? bar.readyColor : 0xB7C3CE);
  if (s != null && s.kind == "status") {
   StatusIcon.draw(dl,s.status,x,y,size,true,true,s.available,fill,s.available ? accent : border); return;
  }
  var active=BarTerCellState.active(s);
  var lit=BarTerCellState.lit(s);
  var glow=bar!=null ? bar.glow : defaultGlow;
  var skill=active && s.kind=="skill";
  var ammo=skill && SkillAttentionPolicy.hasCharges(s.chargesMax,s.charges);
  if (skill && SkillAttentionPolicy.nearReady(true,s.onCd,ammo,s.cdLeft)) SkillAttentionRenderer.nearReady(dl,x,y,size,time);
  ImGui.ImDrawList_AddRectFilled(dl,ImGui.vec2(x,y),ImGui.vec2(x+size,y+size),fill,4);
  ImGui.ImDrawList_AddRect(dl,ImGui.vec2(x,y),ImGui.vec2(x+size,y+size),hovered || lit ? accent : border,4,lit ? 2 : 1);
  if (skill && !lit && s.onCd && glow.cooldownMode==SkillAttentionPolicy.CD_OUTLINE)
   VectorGlow.rect(dl,x-1,y-1,size+2,size+2,0xAA5AA0FF,4,2);
  if (s == null || s.kind == "empty") return;
  var pad:Single=size*0.1;
  if (!GameIcons.drawKey(dl,s.iconKey,x+pad,y+pad,size-pad*2,size-pad*2,active ? 0xFFFFFFFF : 0x66777777)) {
   var label=s.label.length > 0 ? s.label : s.skillId;
   ImGui.ImDrawList_AddText_Vec2(dl,ImGui.vec2(x+3,y+size*0.4),ImGui.colorConvertFloat4ToU32(active ? theme.text : theme.textDisabled),label.substr(0,7));
  }
  // Preserve readable icons; cooldown/resource state is a separate overlay.
  if (active && !lit && (!skill || !s.affordable || glow.cooldownMode==SkillAttentionPolicy.CD_DIM))
   ImGui.ImDrawList_AddRectFilled(dl,ImGui.vec2(x+pad,y+pad),ImGui.vec2(x+size-pad,y+size-pad),0x44000000,2);
  var flash=skill ? SkillAttentionPolicy.readyAlpha(true,lit,s.affordable,s.readyFlashUntil,now) : 0;
  if (flash>0) SkillAttentionRenderer.ready(dl,glow.readyMode,glow.auraStyle,glow.strength,glow.outer,glow.inner,
   glow.color|0xFF000000,x,y,size,4,flash);
  if (skill && s.procReady) SkillAttentionRenderer.proc(dl,x,y,size,s.procStart,now);
  if (active && s.remaining > 0.02) {
   ImGui.ImDrawList_PathClear(dl); ImGui.ImDrawList_PathLineTo(dl,ImGui.vec2(x+size/2,y+size/2));
   ImGui.ImDrawList_PathArcTo(dl,ImGui.vec2(x+size/2,y+size/2),size*0.48,-Math.PI/2,-Math.PI/2+s.remaining*Math.PI*2,28);
   ImGui.ImDrawList_PathFillConvex(dl,0x99000000);
  }
  if (active && s.cdLeft > 0.05) badge(dl,x+size/2,y+size-3,Std.string(Std.int(Math.ceil(s.cdLeft))),true);
  if (s.isItem && s.count > 0) badge(dl,x+size-3,y+size-3,Std.string(s.count),false);
  else if (active && s.chargesMax > 1) badge(dl,x+size-3,y+ImGui.getFontSize()+3,Std.string(s.charges),false);
  else if (active && s.stacks > 1) badge(dl,x+size-3,y+ImGui.getFontSize()+3,Std.string(s.stacks),false);
  if (s.flashUntil > now) ImGui.ImDrawList_AddRect(dl,ImGui.vec2(x+1,y+1),ImGui.vec2(x+size-1,y+size-1),accent,4,2);
  if (showHotkeys && s.keyLabel.length > 0 && s.keyLabel!="Unknown") {
   var key=BarTerBindingResolver.badgeLabel(s.keyLabel);
   if (ImGui.calcTextSize(key).x > size-6) {
    while (key.length > 1 && ImGui.calcTextSize(key+"…").x > size-6) key=key.substr(0,key.length-1);
    key+="…";
   }
   var ts=ImGui.calcTextSize(key);
   ImGui.ImDrawList_AddRectFilled(dl,ImGui.vec2(x+1,y+1),ImGui.vec2(x+ts.x+5,y+ts.y+3),0xDD000000,3);
   ImGui.ImDrawList_AddText_Vec2(dl,ImGui.vec2(x+3,y+2),ImGui.colorConvertFloat4ToU32(theme.text),key);
  }
 }
 static function badge(dl:Dynamic,x:Single,y:Single,value:String,center:Bool):Void {
  var ts=ImGui.calcTextSize(value);
  var tx:Single=center ? x-ts.x/2 : x-ts.x;
  var ty:Single=y-ts.y;
  ImGui.ImDrawList_AddRectFilled(dl,ImGui.vec2(tx-2,ty-1),ImGui.vec2(tx+ts.x+2,ty+ts.y+1),0xDD000000,3);
  ImGui.ImDrawList_AddText_Vec2(dl,ImGui.vec2(tx,ty),ImGui.colorConvertFloat4ToU32(ThemePalette.current().text),value);
 }

	function hudBody(size:imgui.Structs.ImVec2):Void {
		var bar = hudBar; var snaps = hudSnaps; var click = hudClick; var context = hudContext; var showHotkeys = hudShowHotkeys;
		var w:Single = BarTerLayout.width(bar.columns, bar.slotSize);
		var h:Single = BarTerLayout.height(bar.slotCount, bar.columns, bar.slotSize);
		var origin=ImGui.getCursorScreenPos(); var dl=ImGui.getWindowDrawList();
		var now=haxe.Timer.stamp(); var time=ImGui.getTime();
		for (i in 0...bar.slotCount) {
		 var snap=i < snaps.length ? snaps[i] : null;
		 if (BarTerCellState.empty(snap) && !bar.showEmptyCells) continue;
		 var x:Single=origin.x+(i%bar.columns)*(bar.slotSize+BarTerLayout.GAP);
		 var y:Single=origin.y+Std.int(i/bar.columns)*(bar.slotSize+BarTerLayout.GAP);
		 ImGui.setCursorScreenPos(ImGui.vec2(x,y));
		 var pressed=ImGui.invisibleButton("##bt_use_"+bar.id+"_"+i,ImGui.vec2(bar.slotSize,bar.slotSize));
		 var hovered=ImGui.isItemHovered();
		 if (context != null) context(i);
		 drawCell(dl,snap,x,y,bar.slotSize,now,time,hovered,showHotkeys,bar);
		 if (hovered && snap != null && snap.kind != "empty") drawTooltip(snap);
		 if (pressed && snap != null && snap.kind != "empty" && snap.kind != "status" && click != null) click(i);
		}
		ImGui.setCursorScreenPos(origin); ImGui.dummy(ImGui.vec2(w,h));
	}

	function hudResize(nw:Single,nh:Single):Void {
		var bar = hudBar;
		bar.slotSize=BarTerLayout.resized(bar.slotCount,bar.columns,nw,nh); SettingsStore.markDirty();
	}
}
