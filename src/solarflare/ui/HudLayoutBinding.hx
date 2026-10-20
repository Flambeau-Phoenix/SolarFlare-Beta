package solarflare.ui;

import imgui.ref.FloatRef;
import solarflare.ui.HudLayoutModel.HudLayoutRow;

class HudLayoutBinding {
 public var id:String;
 public var chrome:HudChrome;
 public var w:FloatRef; public var h:FloatRef; public var scale:FloatRef;
 public var sizeGet:Void->Float;
 public var sizeSet:Float->Void;
 public var changed:Void->Void;
 public var readExtra:HudLayoutRow->Void;
 public var applyExtra:HudLayoutRow->Void;
 public function new(id:String,c:HudChrome,w:FloatRef=null,h:FloatRef=null,scale:FloatRef=null) {
  this.id=id; chrome=c; this.w=w; this.h=h; this.scale=scale;
 }
 public function capture():HudLayoutRow {
  var rw=chrome.referenceWidth>=320 ? chrome.referenceWidth : HudChrome.viewportWidth;
  var rh=chrome.referenceHeight>=240 ? chrome.referenceHeight : HudChrome.viewportHeight;
  var row:HudLayoutRow={id:id,x:chrome.x.get()/rw,y:chrome.y.get()/rh,referenceWidth:rw,referenceHeight:rh};
  if(w!=null) row.w=w.get(); if(h!=null) row.h=h.get(); if(scale!=null) row.scale=scale.get();
  if(sizeGet!=null) row.cellSize=sizeGet();
  if(readExtra!=null) readExtra(row);
  return row;
 }
 public function apply(r:HudLayoutRow):Void {
  chrome.x.set(r.x*r.referenceWidth); chrome.y.set(r.y*r.referenceHeight);
  chrome.referenceWidth=r.referenceWidth; chrome.referenceHeight=r.referenceHeight; chrome.posDirty=true; chrome.expandSizeDirty=true;
  if(w!=null && r.w!=null) w.set(Math.max(1,r.w)); if(h!=null && r.h!=null) h.set(Math.max(1,r.h));
  if(scale!=null && r.scale!=null) scale.set(cast r.scale);
  if(sizeSet!=null && r.cellSize!=null) sizeSet(r.cellSize*1.);
  if(applyExtra!=null) applyExtra(r);
  if(changed!=null) changed();
 }
 public static function applyRows(bindings:Array<HudLayoutBinding>,rows:Array<HudLayoutRow>):Int {
  var byId=new Map<String,HudLayoutBinding>(); for(b in bindings) byId.set(b.id,b);
  var missing=0;
  for(r in rows) { var b=byId.get(r.id); if(b==null) missing++; else b.apply(r); }
  return missing;
 }
}
