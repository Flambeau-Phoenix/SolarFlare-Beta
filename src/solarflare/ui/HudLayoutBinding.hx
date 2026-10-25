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
 public var captureWarning(default,null):String="";
 public function new(id:String,c:HudChrome,w:FloatRef=null,h:FloatRef=null,scale:FloatRef=null) {
  this.id=id; chrome=c; this.w=w; this.h=h; this.scale=scale;
 }
 /** Repair only invalid live geometry. Saved/imported layout validation remains strict. */
 public function capture(previous:HudLayoutRow=null,defaults:HudLayoutRow=null):HudLayoutRow {
  captureWarning="";
  var repaired=new Map<String,Bool>();
  function valid(key:String,raw:Dynamic):Bool {
   if(!HudLayoutModel.finite(raw)) return false;
   var n:Float=raw;
   return switch(key) {
    case "referenceWidth": n>=320 && n<=32768;
    case "referenceHeight": n>=240 && n<=32768;
    case "x","y": Math.abs(n)<=100;
    case "scale": n>=0.1 && n<=8;
    default: n>=0 && n<=10000;
   }
  }
  function repair(key:String,n:Dynamic,fallback:Float):Float {
   if(valid(key,n)) return n;
   var next:Dynamic=previous==null ? null : Reflect.field(previous,key);
   if(!valid(key,next)) next=defaults==null ? null : Reflect.field(defaults,key);
   if(!valid(key,next)) next=fallback;
   repaired.set(key,true);
   captureWarning+=(captureWarning.length>0 ? "; " : id+": ")+key+"="+Std.string(n)+" -> "+Std.string(next);
   return next;
  }
  // Zero reference extents deliberately mean "use the current viewport" on a new widget.
  var rw=repair("referenceWidth",chrome.referenceWidth==0 ? HudChrome.viewportWidth : chrome.referenceWidth,1920);
  var rh=repair("referenceHeight",chrome.referenceHeight==0 ? HudChrome.viewportHeight : chrome.referenceHeight,1080);
  var row:HudLayoutRow={id:id,x:chrome.x.get()/rw,y:chrome.y.get()/rh,referenceWidth:rw,referenceHeight:rh};
  if(w!=null) row.w=w.get(); if(h!=null) row.h=h.get(); if(scale!=null) row.scale=scale.get();
  if(sizeGet!=null) row.cellSize=sizeGet();
  if(readExtra!=null) readExtra(row);
  row.x=repair("x",row.x,0.5); row.y=repair("y",row.y,0.5);
  for(key in ["w","h","scale","cellSize"]) {
   var n=Reflect.field(row,key);
   if(n!=null) Reflect.setField(row,key,repair(key,n,key=="scale" ? 1 : key=="cellSize" ? 48 : key=="w" ? 240 : 64));
  }
  if(captureWarning.length>0) {
   // Write repairs before feature snapshots are serialized, without converting valid auto-size zeroes to 1.
   chrome.referenceWidth=rw; chrome.referenceHeight=rh;
   chrome.x.set(row.x*rw); chrome.y.set(row.y*rh); chrome.posDirty=true; chrome.expandSizeDirty=true;
   if(w!=null && repaired.exists("w")) w.set(cast row.w); if(h!=null && repaired.exists("h")) h.set(cast row.h);
   if(scale!=null && repaired.exists("scale")) scale.set(cast row.scale);
   if(sizeSet!=null && repaired.exists("cellSize")) sizeSet(cast row.cellSize);
   if(applyExtra!=null && (repaired.exists("w") || repaired.exists("h"))) applyExtra(row);
   if(changed!=null) changed();
  }
  return row;
 }
 public function apply(r:HudLayoutRow):Void {
  chrome.x.set(r.x*r.referenceWidth); chrome.y.set(r.y*r.referenceHeight);
  chrome.referenceWidth=r.referenceWidth; chrome.referenceHeight=r.referenceHeight; chrome.posDirty=true; chrome.expandSizeDirty=true;
  if(w!=null && r.w!=null) w.set(cast r.w); if(h!=null && r.h!=null) h.set(cast r.h);
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
