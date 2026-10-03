package solarflare.extrabars;

import imgui.ImGui;
import solarflare.ui.HudChrome;
import solarflare.ui.HUDWidgetWindow;
import solarflare.ui.GameIcons;
import solarflare.cdb.ConsumableCatalog;
import solarflare.aura.ConsumableCache;
import solarflare.aura.AuraStatusCache;
import solarflare.combatlog.CombatLogCache;

/** Optional separate presentation, sharing inventory/status/combat observations with SolarFlare. */
class SparkCubeTracker {
 public static inline var ITEM_ID:String = "SparkCube";
 static inline var CONTENT_W:Single = 104;
 static inline var CONTENT_H:Single = 112;
 public var flash:Float = 0;
 public var state = new SparkCubeState();
 public var label(default,null):String = "—";
 var enabled = false;
 var owner:Dynamic;
 var sequence:Float = 0;
 var charged = false;
 var known = false;
 var owned = false;
 var flashUntil:Float = 0;
 var nativeSeen = false;
 var nativeEnded = false;
 var castStarted:Float = -1;
 var seconds:Float = 0;
 var progress:Float = 0;
 var source = "";
 var icon:String;
 var damageText = "Observed damage: —";
 var burstText = "Last burst: —";
 var damageReadout = "";
 var readoutBurst = false;
 public function new() { icon = ConsumableCatalog.iconKey(ITEM_ID); }
 public function trigger(now:Float):Void { flashUntil=now+0.30; flash=1; }
 public function reset():Void { state.reset(); enabled = false; owner = null; sequence = 0; known = false; owned = false; charged = false; damageReadout = ""; readoutBurst = false; seconds = 0; progress = 0; flash = 0; label = "—"; flashUntil = 0; nativeSeen = false; nativeEnded = false; castStarted = -1; }
 public function observe(hero:Dynamic, on:Bool, now:Float):Void {
  if (!on) { if (enabled) reset(); return; }
  if (!enabled || owner != hero || CombatLogCache.latestSequence < sequence) {
   reset(); enabled = true; owner = hero; sequence = CombatLogCache.latestSequence; state.lastSequence = sequence;
  }
  if (CombatLogCache.latestSequence != sequence) {
   for (line in CombatLogCache.recentAll()) if (line.sequence > sequence)
    state.accept(line.sequence,line.kind,line.skillId,line.sourceRole == CombatLogCache.ROLE_YOU,line.amount,line.t,line.minionName.length > 0);
   sequence = CombatLogCache.latestSequence;
  }
  var inv = ConsumableCache.find(ITEM_ID); known = inv != null && inv.known;
  owned = known && inv.owned; charged = owned && inv.count > 0;
  seconds = state.remaining(now); source = seconds > 0 ? "Cast timer" : "";
  if (castStarted != state.started) { nativeSeen=false; nativeEnded=false; castStarted=state.started; }
  var effect = AuraStatusCache.isCurrent(hero) ? AuraStatusCache.find("SparkSurge_Status") : null;
  if (!nativeEnded && effect != null && effect.known && effect.present && state.burstAt < 0) { nativeSeen=true; if (effect.durationKnown) { seconds = effect.left; source = "Effect remaining"; } }
  else if (nativeSeen && AuraStatusCache.isCurrent(hero) && AuraStatusCache.domainKnown && effect==null) nativeEnded=true;
  if (nativeEnded) { state.stop(now); seconds=0; source=""; }
  progress = Math.max(0,Math.min(1,seconds / SparkCubeState.DURATION));
  // Item charge is binary; effect activity and native usability are separate.
  label = !known || !owned ? "—" : charged ? "Charged" : "Empty";
  damageText = state.started >= 0 ? (state.partial ? "Partial damage: " : "Observed damage: ")+metric(state.observedDamage) : "Observed damage: —";
  burstText = state.burstAt >= 0 ? "Last burst: "+metric(state.burstDamage) : "Last burst: —";
  readoutBurst = state.burstAt >= 0;
  damageReadout = state.started < 0 ? "" : (readoutBurst ? "Burst " : "Dealt ")+metric(readoutBurst ? state.burstDamage : state.observedDamage)+(state.partial ? "*" : "");
  flash = Math.max(0,Math.min(1,(flashUntil-now)/0.30));
 }
 static function metric(value:Float):String return value >= 1000000 ? Std.string(Math.round(value/10000)/100)+"M" : value >= 10000 ? Std.string(Math.round(value/100)/10)+"K" : Std.string(Math.round(value));
 public function draw(chrome:HudChrome, pixels:Int, edit:Void->Void, click:Void->Void, hide:Void->Void, onResize:Int->Void = null, showHotkey:Bool = false, hotkeyLabel:String = ""):Void {
  var hotkey=showHotkey?ExtraBarsConfig.cleanHotkeyLabel(hotkeyLabel):"";
  var contentH:Single=CONTENT_H+(hotkey.length>0?22:0);
  var scale:Single = pixels/64; var w:Single = CONTENT_W*scale; var h:Single = contentH*scale;
  HUDWidgetWindow.draw("SolarFlare.ExtraBars.SparkCube","Spark Cube",chrome,w,h,function(_) {
   var p = ImGui.getCursorScreenPos(); var dl = ImGui.getWindowDrawList();
   var font=ImGui.getFont(); if (font!=null) ImGui.pushFont(font,Math.min(ImGui.getFontSize(),13*scale));
   try {
   var gold = 0xFF37AFD4; var blue = 0xFFFFBF00;
   // The Cube owns its inner backing; transparent chrome only lightens it.
   ImGui.ImDrawList_AddRectFilled(dl,p,ImGui.vec2(p.x+w,p.y+h),chrome.transparent.get()?0x55191414:0xDC191414,8);
   ImGui.ImDrawList_AddRect(dl,p,ImGui.vec2(p.x+w,p.y+h),gold,8,1.5);
   for (i in 0...4) {
    var x:Single = i%2==0?p.x:p.x+w; var y:Single = i<2?p.y:p.y+h;
    var dx:Single = i%2==0?8*scale:-8*scale; var dy:Single = i<2?12*scale:-12*scale;
    ImGui.ImDrawList_AddLine(dl,ImGui.vec2(x+dx,y),ImGui.vec2(x+dx,y+dy),gold,2);
    ImGui.ImDrawList_AddLine(dl,ImGui.vec2(x,y+dy),ImGui.vec2(x+dx,y+dy),gold,2);
   }
   ExtraBarsPrototypeBar.drawLabel(dl,label,p.x+8*scale,p.y+9*scale,w-16*scale,charged?blue:0xFFEFEFEF);
   var iconSize:Single = 52*scale;
   var iconX:Single = p.x+(w-iconSize)/2; var iconY:Single = p.y+28*scale;
   ImGui.ImDrawList_AddRectFilled(dl,ImGui.vec2(iconX,iconY),ImGui.vec2(iconX+iconSize,iconY+iconSize),0xAA090909,5);
   if (!GameIcons.drawKey(dl,icon,iconX,iconY,iconSize,iconSize,charged?0xFFFFFFFF:0xAAFFFFFF)) ExtraBarsPrototypeBar.drawLabel(dl,"CUBE",iconX,iconY+18*scale,iconSize,0xFFFFFFFF);
   // Only an observed active effect adds a countdown and remaining-time rail.
   if (seconds > 0) {
    ExtraBarsPrototypeBar.drawKeyBadge(dl,Std.string(Math.ceil(seconds*10)/10)+" s",p.x+8*scale,p.y+66*scale,blue,w-16*scale,true);
    var left:Single = p.x+10*scale; var right:Single = p.x+w-10*scale;
    var railTop:Single = p.y+102*scale; var railBottom:Single = railTop+4*scale;
    var edge:Single = left+(right-left)*progress;
    ImGui.ImDrawList_AddRectFilled(dl,ImGui.vec2(left,railTop),ImGui.vec2(right,railBottom),0xAA090909,2);
    ImGui.ImDrawList_AddRectFilled(dl,ImGui.vec2(left,railTop),ImGui.vec2(edge,railBottom),0xBFFF9A00,2);
    ImGui.ImDrawList_AddLine(dl,ImGui.vec2(left,railTop),ImGui.vec2(edge,railTop),0xEFFFFFFF,1);
   }
   // Readout belongs to the widget face, so transparency cannot hide it.
   if (damageReadout.length > 0) {
    ImGui.ImDrawList_AddRectFilled(dl,ImGui.vec2(p.x+6*scale,p.y+84*scale),ImGui.vec2(p.x+w-6*scale,p.y+100*scale),0xA0000000,3);
    ExtraBarsPrototypeBar.drawLabel(dl,damageReadout,p.x+8*scale,p.y+86*scale,w-16*scale,readoutBurst?gold:0xFFEFEFEF);
   }
   // A separate footer keeps the typed hotkey clear of portrait, timer and damage.
   if (hotkey.length>0) {
    ImGui.ImDrawList_AddRectFilled(dl,ImGui.vec2(p.x+6*scale,p.y+112*scale),ImGui.vec2(p.x+w-6*scale,p.y+132*scale),0xA0000000,3);
    ExtraBarsPrototypeBar.drawLabel(dl,hotkey,p.x+8*scale,p.y+116*scale,w-16*scale,0xFFEFEFEF);
   }
   ImGui.setCursorScreenPos(p);
   var pressed = ImGui.invisibleButton("##spark_use",ImGui.vec2(w,h));
   if (ImGui.isItemHovered()) {
    var tip = !known ? "Waiting for inventory data." : !owned ? "Spark Cube is not carried." : charged ? "Charged. Click to use." : "Empty. Refill at the Obelisks' waters.";
    if (seconds > 0) tip += "\nSpark surge: "+Std.string(Math.ceil(seconds*10)/10)+" s ("+source+").";
    if (state.started >= 0) tip += "\n"+damageText+(state.linked?" (includes credited summon hits)":"")+"\nObserved damage is not stored Cube damage.";
    if (state.burstAt >= 0) tip += "\n"+burstText;
    if (state.partial) tip += "\n* Partial observation: some combat events were missed.";
    if (hotkey.length>0) tip += "\nHotkey label: "+hotkey+" (display only).";
    ImGui.setTooltip(tip);
   }
   if (pressed && click != null) click();
   if (flash > 0) ImGui.ImDrawList_AddRect(dl,ImGui.vec2(p.x+3,p.y+3),ImGui.vec2(p.x+w-3,p.y+h-3),(Std.int(flash*255)<<24)|0x00B8FFAA,5,2);
   } catch(e:Dynamic) { if(font!=null) ImGui.popFont(); throw e; }
   if(font!=null) ImGui.popFont();
  },edit,hide,false,null,function(width:Single,height:Single) {
   var size=Std.int(Math.max(40,Math.min(120,Math.min(width/CONTENT_W,height/contentH)*64)));
   if (onResize!=null) onResize(size);
  });
 }
}
