package solarflare.ui;

import solarflare.util.ShareCodec;

typedef HudLayoutRow = {
 var id:String;
 /** Normalized content anchor; dimensions stay in logical pixels. */
 var x:Float; var y:Float;
 var referenceWidth:Float; var referenceHeight:Float;
 @:optional var w:Float; @:optional var h:Float;
 @:optional var growthDirection:String;
 @:optional var scale:Float; @:optional var cellSize:Float;
}

/** Pure, profile-owned layout bank. No game/UI objects or non-geometry fields. */
class HudLayoutModel {
 public static inline var FORMAT:String="solarflare.ui-layout";
 public var active:String="Default";
 public var order:Array<String>=[];
 public var layouts:Map<String,Array<HudLayoutRow>>=new Map();
 /** Recover readable rows for display, but never replace damaged/newer saved data. */
 public var saveSafe(default,null):Bool=true;
 public var loadWarning(default,null):String="";
 public function new() {}
 public static function clone(rows:Array<HudLayoutRow>):Array<HudLayoutRow> return validate(rows);
 public static function finite(v:Dynamic):Bool return (Std.isOfType(v,Float) || Std.isOfType(v,Int)) && Math.isFinite(v);
 public static function validate(data:Dynamic):Array<HudLayoutRow> {
  if(!Std.isOfType(data,Array)) throw "Layout widgets must be an array.";
  var input:Array<Dynamic>=cast data;
  if(input.length>2048) throw "Too many layout widgets.";
  var rows:Array<HudLayoutRow>=[]; var seen=new Map<String,Bool>();
  for(r in input) {
   if(r==null || !Std.isOfType(r.id,String) || r.id.length==0 || r.id.length>256 || seen.exists(r.id)) throw "Invalid or duplicate widget ID.";
   if(!finite(r.x) || !finite(r.y) || Math.abs(r.x)>100 || Math.abs(r.y)>100
    || !finite(r.referenceWidth) || !finite(r.referenceHeight) || r.referenceWidth<320 || r.referenceWidth>32768 || r.referenceHeight<240 || r.referenceHeight>32768) throw "Invalid layout coordinates.";
   var row:HudLayoutRow={id:r.id,x:r.x,y:r.y,referenceWidth:r.referenceWidth,referenceHeight:r.referenceHeight};
   for(key in ["w","h","scale","cellSize"]) {
    var v=Reflect.field(r,key);
    if(v!=null) { if(!finite(v) || v<0 || v>10000 || key=="scale" && (v<0.1 || v>8)) throw "Invalid widget size."; Reflect.setField(row,key,v); }
   }
   if(r.id=="statusBoard.chrome" && Reflect.field(r,"growthDirection")!=null) row.growthDirection=Reflect.field(r,"growthDirection")=="up" ? "up" : "down";
   rows.push(row); seen.set(r.id,true);
  }
  return rows;
 }
 public function unique(name:String):String {
  name=StringTools.trim(name==null ? "" : name); if(name.length==0) name="Layout";
  name=name.substr(0,80); var key=name; var n=2;
  while(layouts.exists(key)) key=name+" ("+(n++)+")";
  return key;
 }
 public function add(name:String,rows:Array<HudLayoutRow>):String {
  var key=unique(name); layouts.set(key,clone(rows)); order.push(key); active=key; return key;
 }
 public static function merge(saved:Array<HudLayoutRow>,updates:Array<HudLayoutRow>):Array<HudLayoutRow> {
  var out=clone(saved); var byId=new Map<String,Int>();
  for(i in 0...out.length) byId.set(out[i].id,i);
  for(row in clone(updates)) {
   var index=byId.get(row.id);
   if(index==null) { byId.set(row.id,out.length); out.push(row); }
   else out[index]=row;
  }
  return out;
 }
 public function retain(rows:Array<HudLayoutRow>):Void layouts.set(active,merge(layouts.get(active),rows));
 public function forget(id:String):Void {
  for(name in order) layouts.set(name,[for(row in layouts.get(name)) if(row.id!=id) row]);
 }
 public function dump():Dynamic {
  if(!saveSafe) throw loadWarning;
  return {version:1,active:active,layouts:[for(name in order) {name:name,widgets:clone(layouts.get(name))}]};
 }
 function damaged(message:String):Void { saveSafe=false; if(loadWarning.length==0) loadWarning=message; }
 public static function load(data:Dynamic,fallback:Array<HudLayoutRow>):HudLayoutModel {
  var bank=new HudLayoutModel();
  if(data!=null && (data.version!=1 || !Std.isOfType(data.layouts,Array))) bank.damaged("Unsupported or damaged saved UI layout bank; original settings preserved.");
  if(data!=null && data.version==1 && Std.isOfType(data.layouts,Array)) {
   var list:Array<Dynamic>=data.layouts;
   for(item in list) {
    if(item==null || !Std.isOfType(item.name,String) || item.name.length==0 || !Std.isOfType(item.widgets,Array)) {
     bank.damaged("Damaged saved UI layout; readable widgets restored, original settings preserved."); continue;
    }
    var rows:Array<HudLayoutRow>=[]; var seen=new Map<String,Bool>(); var widgets:Array<Dynamic>=item.widgets;
    for(widget in widgets) try {
     var row=validate([widget])[0]; if(seen.exists(row.id)) throw "Duplicate saved widget.";
     rows.push(row); seen.set(row.id,true);
    } catch(_:Dynamic) bank.damaged("Damaged saved UI layout; readable widgets restored, original settings preserved.");
    if(bank.layouts.exists(item.name)) bank.damaged("Duplicate saved layout name; original settings preserved.");
    // Saved rows always win over legacy/default geometry, including inactive layouts.
    var recovered=merge(fallback,rows);
    bank.add(item.name,recovered);
   }
   if(Std.isOfType(data.active,String) && bank.layouts.exists(data.active)) bank.active=data.active;
   else if(bank.order.length>0) bank.active=bank.order[0];
  }
  if(bank.order.length==0) bank.add("Default",fallback);
  return bank;
 }
 public function exportSelected():String return ShareCodec.encodeObj({format:FORMAT,version:1,name:active,widgets:clone(layouts.get(active))});
 public function importText(text:String):String {
  if(text==null || text.length>1048576) throw "Layout share key is too large.";
  var data:Dynamic=ShareCodec.parseDyn(text);
  if(data==null || data.format!=FORMAT || data.version!=1) throw "Unsupported UI layout format/version.";
  var rows=validate(data.widgets); // Validate completely before mutating the bank.
  return add(Std.isOfType(data.name,String) ? data.name : "Imported",rows);
 }
 /** Known legacy geometry only. IDs match the live binding registry. */
 public static function legacy(snapshot:Dynamic,defaultWidth:Float=1920,defaultHeight:Float=1080,root:Dynamic=null):Array<HudLayoutRow> {
  var out:Array<HudLayoutRow>=[];
  if(snapshot==null) return out;
  function node(path:String):Dynamic {
   var d=snapshot; for(part in path.split(".")) { if(d==null) return null; d=Reflect.field(d,part); } return d;
  }
  function global(path:String):Dynamic {
   var d=root!=null ? root : snapshot;
   if(root==null && snapshot.auxiliary!=null && Reflect.hasField(snapshot.auxiliary,path.split(".")[0])) d=snapshot.auxiliary;
   for(part in path.split(".")) { if(d==null) return null; d=Reflect.field(d,part); } return d;
  }
  function add(id:String,c:Dynamic,d:Dynamic,w:String="w",h:String="h"):Void {
   if(c==null || !finite(c.x) || !finite(c.y)) return;
   var rw=finite(c.referenceWidth) && c.referenceWidth>=320 ? c.referenceWidth : defaultWidth;
   var rh=finite(c.referenceHeight) && c.referenceHeight>=240 ? c.referenceHeight : defaultHeight;
   var r:HudLayoutRow={id:id,x:c.x/rw,y:c.y/rh,referenceWidth:rw,referenceHeight:rh};
   if(d!=null) for(pair in [{from:w,to:"w"},{from:h,to:"h"},{from:"scale",to:"scale"}]) {
    var v=Reflect.field(d,pair.from); if(finite(v)) Reflect.setField(r,pair.to,v);
   }
   out.push(r);
  }
  for(path in ["geaux.layout","resources.combo","resources.attackCombo","resources.target","resources.castBar","resources.chaincast","resources.conduit","resources.hemorrhage","resources.resourceTracker.dash","statusBoard"]) {
   var d=node(path); if(d!=null) add(path+".chrome",d.chrome,d);
  }
  if(node("resources.resourceTracker.dash")==null) { var tracker=global("resourceTracker"); if(tracker!=null && tracker.dash!=null) add("resources.resourceTracker.dash.chrome",tracker.dash.chrome,tracker.dash); }
  var v=node("resources.vitals");
  if(v==null && root!=null) v=global("vitals");
  if(v!=null) for(p in [{c:"chrome",w:"hpW",h:"hpH"},{c:"rageChrome",w:"rageW",h:"rageH"},{c:"manaChrome",w:"manaW",h:"manaH"},{c:"prayersChrome",w:"prayersW",h:"prayersH"}])
   add("resources.vitals."+p.c,Reflect.field(v,p.c),v,p.w,p.h);
  var b=node("barter");
  if(b!=null && b.chromes!=null) for(id in Reflect.fields(b.chromes)) {
   var before=out.length; add("barter.chromes."+id,Reflect.field(b.chromes,id),null);
   if(out.length>before && Std.isOfType(b.bars,Array)) { var bars:Array<Dynamic>=b.bars; for(bar in bars) if(bar.id==id && finite(bar.slotSize)) out[out.length-1].cellSize=bar.slotSize; }
  }
  var a=node("auras.config");
  if(a==null && root!=null) a=global("auras");
  if(a!=null && Std.isOfType(a.list,Array)) { var list:Array<Dynamic>=a.list; for(item in list) if(Std.isOfType(item.id,String)) add("aura:"+item.id,item.chrome!=null ? item.chrome : item,item); }
  var status=node("statusBoard");
  if(status!=null && status.chrome==null) {
   var n=out.length; add("statusBoard.chrome",status,null);
   if(out.length>n) { var row=out[out.length-1]; if(finite(status.contentWidth)) row.w=status.contentWidth; if(finite(status.contentHeight)) row.h=status.contentHeight; if(finite(status.slotSize)) row.cellSize=status.slotSize; row.growthDirection=status.growthDirection=="up" ? "up" : "down"; }
  }
  if(a!=null) add("global.auraTimers",a.timerBoardChrome,a,"timerBoardW","timerBoardRowH");
  if(a!=null && Std.isOfType(a.groups,Array)) { var gl:Array<Dynamic>=a.groups; for(g in gl) if(Std.isOfType(g.id,String)) add("auraGroup:"+g.id,g,null,"__none","__none"); }
  var chain=node("resources.chaincast");
  if(chain!=null && chain.modules!=null) for(key in Reflect.fields(chain.modules)) {
   var m=Reflect.field(chain.modules,key); if(m!=null) add("resources.chaincast.modules."+key,m.chrome,m);
  }
  for(p in [{path:"rifty",id:"global.rifty",w:"size",h:"__none"},{path:"clog",id:"global.combatLog",w:"w",h:"h"},
   {path:"saber",id:"global.lightsaber",w:"w",h:"h"}]) {
   var d=global(p.path); if(d!=null) add(p.id,d.chrome,d,p.w,p.h);
  }
  var saber=global("saber"); if(saber!=null) add("global.riftMeter",saber.riftChrome,saber,"riftW","riftH");
  var launchers=global("launchers");
  if(launchers!=null) for(key in ["f6","f7"]) { var d=Reflect.field(launchers,key); if(d!=null) add(key=="f6" ? "global.launcherF6" : "global.launcherF7",d.chrome,d,"size","__none"); }
  var stacks=node("stacks");
  if(stacks!=null && Std.isOfType(stacks.trackers,Array)) {
   var list:Array<Dynamic>=stacks.trackers;
   for(t in list) if(t!=null && Std.isOfType(t.id,String)) {
    var n=out.length; add("stacks:"+t.id,stacks.placements!=null ? Reflect.field(stacks.placements,t.id) : null,null);
    if(out.length>n && finite(t.cellSize)) out[out.length-1].cellSize=t.cellSize;
   }
  }
  var extra=global("extraBars"); var positions=global("extraBarsPlacement");
  if(Std.isOfType(positions,Array)) {
   var list:Array<Dynamic>=positions;
   for(p in list) if(p!=null && Std.isOfType(p.id,String)) {
    var n=out.length; add(p.id=="spark" ? "global.spark" : "global.extraBar:"+p.id,p,null);
    if(out.length>n && extra!=null) {
     if(p.id=="spark" && finite(extra.sparkSize)) out[out.length-1].cellSize=extra.sparkSize;
     else if(Std.isOfType(extra.bars,Array)) { var bars:Array<Dynamic>=extra.bars; for(b in bars) if(b.id==p.id && finite(b.slotSize)) out[out.length-1].cellSize=b.slotSize; }
    }
   }
  }
  return validate(out);
 }
}
