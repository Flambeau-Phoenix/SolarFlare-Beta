package solarflare.barter;

import imgui.ImGui;
import imgui.Enums.ImGuiHoveredFlags;
import solarflare.ui.CursorCaptureFix;
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
 /** ImGui ids built once per bar, not concatenated for every cell every frame. */
 static var useIds:Map<String,Array<String>> = new Map();
 static var windowIds:Map<String,String> = new Map();
 static var idCacheCount:Int = 0;
 static function retainBarId(barId:String):Void {
  if (windowIds.exists(barId)) return;
  // Deleted bars and old profiles must not retain strings for the whole session.
  if (idCacheCount >= 256) { useIds.clear(); windowIds.clear(); idCacheCount=0; }
  windowIds.set(barId,"SolarFlare.BarTer."+barId); idCacheCount++;
 }
 static function useId(barId:String,i:Int):String {
  retainBarId(barId);
  var ids=useIds.get(barId);
  if (ids == null) { ids=[]; useIds.set(barId,ids); }
  while (ids.length <= i) ids.push("##bt_use_"+barId+"_"+ids.length);
  return ids[i];
 }
 static function windowId(barId:String):String {
  retainBarId(barId);
  return windowIds.get(barId);
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
  for(s in snaps) if(s.glow!=null) reach=Math.max(reach,s.glow.reach(bar.slotSize));
  visualBounds.reset(w,h); visualBounds.include(-reach,-reach,w+reach*2,h+reach*2);
  HUDWidgetWindow.draw(windowId(bar.id),bar.name,chrome,w,h,hudBodyFn,edit,hide,false,barMenu,hudResizeFn,visualBounds);
  hudBar = null; hudSnaps = null; hudClick = null; hudContext = null;
 }
 public static function tooltip(s:BarTerSnap):String {
  if (s.kind == "status") {
   if (!s.status.known) return s.label+"\n"+s.statusId+"\nPresence unavailable · display only";
   if (!s.available) return s.label+"\n"+s.statusId+"\nInactive · display only";
   return StatusIcon.tooltip(s.status)+"\nDisplay only";
  }
  var tip=s.label.length > 0 ? s.label : s.isItem ? s.itemKind : s.skillId;
  if (s.isItem) return tip+"\nStack "+s.count+(s.keyLabel.length>0 ? "\nBinding: "+s.keyLabel : "\nNo equipped native binding")+(s.usable ? "\nClick / key to use." : "\nNot currently usable.");
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
  else if (BarTerTipCache.eligible(s)) {
   // Draw posts a primitive hover key; BarTer.observe resolves the game text (see BarTerTipCache).
   var key=BarTerTipCache.keyOf(s);
   BarTerTipCache.request(key,haxe.Timer.stamp(),s.label,s);
   solarflare.statusboard.StatusBoardTooltipRenderer.drawRow(BarTerTipCache.get(key),s.label);
  }
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
  var glow=s!=null && s.glow!=null ? s.glow : bar!=null ? bar.glow : defaultGlow;
  var skill=active && s.kind=="skill";
  var ammo=skill && SkillAttentionPolicy.hasCharges(s.chargesMax,s.charges);
  if (skill && s.cooldownValid && glow.nearEnabled && !ammo && s.cdLeft>0.05 && s.cdLeft<=glow.nearThreshold) SkillAttentionRenderer.nearReady(dl,x,y,size,time);
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
  var flash=skill ? SkillAttentionPolicy.configuredAlpha(glow,s.cooldownValid,lit,s.readyAt,now) : 0;
  if(flash>0) SkillAttentionRenderer.configuredReady(dl,glow,x,y,size,flash,time);
  if(skill && s.procValid && s.procReady) SkillAttentionRenderer.configuredProc(dl,glow,x,y,size,s.procStart,now);
  if (active && s.remaining > 0.02) {
   ImGui.ImDrawList_PathClear(dl); ImGui.ImDrawList_PathLineTo(dl,ImGui.vec2(x+size/2,y+size/2));
   ImGui.ImDrawList_PathArcTo(dl,ImGui.vec2(x+size/2,y+size/2),size*0.48,-Math.PI/2,-Math.PI/2+s.remaining*Math.PI*2,28);
   ImGui.ImDrawList_PathFillConvex(dl,0x99000000);
  }
  if (active && s.cdLeft > 0.05) badge(dl,x+size/2,y+size-3,solarflare.util.IntText.of(Std.int(Math.ceil(s.cdLeft))),true);
  var counts=bar==null || bar.showCounts;
  var countFont=solarflare.ui.SlotBadgeMetrics.font(ImGui.getFontSize(),bar!=null ? bar.chargeScale : 1,size);
  var count=counts ? (s.isItem && s.count>0 ? solarflare.util.IntText.of(s.count) : active && s.chargesMax>1 ? solarflare.util.IntText.of(s.charges) : active && s.stacks>1 ? solarflare.util.IntText.of(s.stacks) : "") : "";
  if(count.length>0) solarflare.ui.SlotBadgeRenderer.draw(dl,count,x+size*0.58,y+1,size*0.42-2,size*0.45,countFont,ImGui.colorConvertFloat4ToU32(theme.text),true);
  if (s.flashUntil > now) ImGui.ImDrawList_AddRect(dl,ImGui.vec2(x+1,y+1),ImGui.vec2(x+size-1,y+size-1),accent,4,2);
  if (showHotkeys && s.keyLabel.length > 0 && s.keyLabel!="Unknown") {
   var key=BarTerBindingResolver.badgeLabel(s.keyLabel);
   var font=solarflare.ui.SlotBadgeMetrics.font(ImGui.getFontSize(),bar!=null ? bar.bindingScale : 1,size);
   solarflare.ui.SlotBadgeRenderer.draw(dl,key,x+1,y+1,count.length>0 ? size*0.58-2 : size-2,size*0.45,font,ImGui.colorConvertFloat4ToU32(theme.text));
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
		 var pressed=ImGui.invisibleButton(useId(bar.id,i),ImGui.vec2(bar.slotSize,bar.slotSize));
		 // Nearby HUD hosts include invisible glow/padding/footer space. That space must not
		 // shrink a cell's tooltip target. Keep normal window blocking while an editor is open;
		 // popup, active-item and clipping checks still apply in both cases. Clicks stay native.
		 var hoverFlags=ImGuiHoveredFlags.NoNavOverride;
		 if (!CursorCaptureFix.interactiveActive) hoverFlags |= ImGuiHoveredFlags.AllowWhenOverlappedByWindow;
		 var hovered=CursorCaptureFix.cursorFree && ImGui.isItemHovered(hoverFlags);
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
