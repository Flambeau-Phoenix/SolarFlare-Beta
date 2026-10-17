package solarflare.ui;

import imgui.ref.FloatRef;
import solarflare.ui.HudLayoutModel.HudLayoutRow;

/** Local configuration references only; never retains live game/UI engine objects. */
class HudLayoutBindings {
 public static function build(c:ConfigPanel):Array<HudLayoutBinding> {
  var out:Array<HudLayoutBinding>=[];
  function add(id:String,ch:HudChrome,w:FloatRef=null,h:FloatRef=null,scale:FloatRef=null):HudLayoutBinding {
   var b=new HudLayoutBinding(id,ch,w,h,scale); if(ch!=null) out.push(b); return b;
  }
  var v=c.vitals;
  if(v!=null) {
   var hp=add("resources.vitals.chrome",v.chrome,v.hpWidth,v.hpHeight); hp.changed=function() v.hpSizeDirty=true;
   add("resources.vitals.rageChrome",v.rageChrome,v.rageWidth,v.rageHeight).changed=function() v.rageSizeDirty=true;
   add("resources.vitals.manaChrome",v.manaChrome,v.manaWidth,v.manaHeight).changed=function() v.manaSizeDirty=true;
   add("resources.vitals.prayersChrome",v.prayersChrome,v.prayersWidth,v.prayersHeight).changed=function() v.prayersSizeDirty=true;
  }
  if(c.geaux!=null) { var g=c.geaux; var b=add("geaux.layout.chrome",g.chrome,g.width,g.height); b.changed=function() g.sizeDirty=true; }
  if(c.combo!=null) add("resources.combo.chrome",c.combo.chrome,c.combo.width,c.combo.height);
  if(c.attackCombo!=null) add("resources.attackCombo.chrome",c.attackCombo.chrome,c.attackCombo.width,c.attackCombo.height);
  if(c.target!=null) add("resources.target.chrome",c.target.chrome,c.target.width,c.target.height);
  if(c.castBar!=null) add("resources.castBar.chrome",c.castBar.chrome,c.castBar.width,c.castBar.height);
  if(c.chaincast!=null) {
   add("resources.chaincast.chrome",c.chaincast.chrome,c.chaincast.width,c.chaincast.height);
   for(m in c.chaincast.modules.all) add("resources.chaincast.modules."+m.key,m.chrome,m.width,m.height);
  }
  if(c.conduit!=null) add("resources.conduit.chrome",c.conduit.chrome,c.conduit.width,c.conduit.height);
  if(c.hemorrhage!=null) { var h=c.hemorrhage; var b=add("resources.hemorrhage.chrome",h.chrome,h.width,h.height); b.changed=function() h.sizeDirty=true; }
  if(c.barter!=null) for(bar in c.barter.config.bars) {
   var item=bar; var b=add("barter.chromes."+bar.id,c.barter.config.chromeFor(bar.id));
   b.sizeGet=function() return item.slotSize;
   b.sizeSet=function(n) item.slotSize=Std.int(Math.max(32,Math.min(128,n)));
  }
  if(c.auras!=null) {
   for(a in c.auras.auras) { var item=a; var b=add("aura:"+a.id,a.chrome,a.w,a.h,a.scale); b.changed=function() item.sizeDirty=true; }
   add("global.auraTimers",c.auras.timerBoardChrome,c.auras.timerBoardW,c.auras.timerBoardRowH);
   for(g in c.auras.groups) if(g!=null) add("auraGroup:"+g.id,c.auras.groupChrome(g));
  }
  if(c.stacks!=null) for(view in c.stacks.views) {
   var item=view; var b=add("stacks:"+view.config.id,view.chrome);
   b.sizeGet=function() return item.config.cellSize;
   b.sizeSet=function(n) item.config.cellSize=Math.max(8,Math.min(128,n));
  }
  if(c.statusBoard!=null) {
   var s=c.statusBoard.config; var b=add("statusBoard.chrome",s.chrome);
   b.sizeGet=function() return s.slotSize; b.sizeSet=function(n) s.slotSize=Std.int(Math.max(28,Math.min(72,n)));
   // StatusBoard supports independent content width and height.
   b.readExtra=function(row) { row.w=s.contentWidth; row.h=s.contentHeight; };
   b.applyExtra=function(row) { if(row.w!=null) s.contentWidth=cast row.w; if(row.h!=null) s.contentHeight=cast row.h; };
  }
  if(c.getRifty!=null) { var g=c.getRifty; var b=add("global.rifty",g.chrome,g.size); b.changed=function() g.sizeDirty=true; }
  if(c.combatLog!=null) add("global.combatLog",c.combatLog.chrome,c.combatLog.width,c.combatLog.height);
  if(c.lightsaber!=null) { add("global.lightsaber",c.lightsaber.chrome,c.lightsaber.width,c.lightsaber.height); add("global.riftMeter",c.lightsaber.riftChrome,c.lightsaber.riftWidth,c.lightsaber.riftHeight); }
  if(c.launchers!=null) for(s in [c.launchers.f6,c.launchers.f7]) if(s!=null) {
   var item=s; var b=add(s==c.launchers.f6 ? "global.launcherF6" : "global.launcherF7",s.chrome,s.size); b.changed=function() item.sizeDirty=true;
  }
  if(c.extraBarsPrototype!=null) {
   var e=c.extraBarsPrototype;
   for(bar in e.model.bars) {
    var item=bar; var b=add("global.extraBar:"+bar.id,e.chromeFor(bar.id));
    b.sizeGet=function() return item.slotSize; b.sizeSet=function(n) item.slotSize=Std.int(Math.max(24,Math.min(96,n)));
   }
   var b=add("global.spark",e.chromeFor("spark")); b.sizeGet=function() return e.model.sparkSize;
   b.sizeSet=function(n) e.model.sparkSize=Std.int(Math.max(32,Math.min(256,n)));
  }
  return out;
 }
 public static function capture(c:ConfigPanel):Array<HudLayoutRow> return [for(b in build(c)) b.capture()];
 public static function apply(c:ConfigPanel,rows:Array<HudLayoutRow>):Int {
  return HudLayoutBinding.applyRows(build(c),rows);
 }
}
