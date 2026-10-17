package solarflare.ui;

private class VisibilityLease {
 public var node:Dynamic;
 public var root:Dynamic;
 public var owned=false;
 public var original=true;
 public var target:VisibilityTarget;
 public function new(node:Dynamic,root:Dynamic,target:VisibilityTarget) { this.node=node; this.root=root; this.target=target; }
}
private class VisibilityTarget {
 public var id:String;
 public var fieldName:String;
 public var types:Array<String>;
 public var leases:Array<VisibilityLease>=[];
 public var failed=false;
 public var found=false;
 public var lateFailed=false;
 public var row:NativeHideElement;
 /** Also searched for under the HUD itself (shallow), for widgets that do not live in the hero bars. */
 public var hudScan:Bool;
 public function new(id:String,fieldName:String,types:Array<String>,hudScan:Bool=false) {
  this.id=id; this.fieldName=fieldName; this.types=types; this.hudScan=hudScan;
 }
}

/** Observation-owned target discovery/ownership. Independent failures cannot disable other rows. */
class NativeElementController {
 static inline var SCAN_S:Float=0.5;
 static inline var MAX_NODES:Int=192;
 static inline var MAX_DEPTH:Int=4;
 static inline var HUD_DEPTH:Int=3;
 /** Safety net only: a hidden/probed HUD-scan row with nothing found is searched again this often. */
 static inline var HUD_RETRY_S:Float=3.0;
 /** HUD children that hold windows, unit widgets or overlays: huge, and never home to the cast bar. */
 static var HUD_SKIP:Array<String>=["widgets","windows","overlays","modals","popups","dragContainer","chat","deathCard","spectator"];
 var hudRetry:Float=-1e9;
 var source:NativeVisibilitySource;
 var hud:Dynamic;
 var keyboard:Dynamic;
 var pad:Dynamic;
 var config:NativeHideConfig;
 var nextScan:Float=-1e9;
 var previousTime:Float=-1e9;
 var visited:Int=0;
 var chatLease:VisibilityLease;
 var chatTarget:VisibilityTarget;
 var discoveryDirty=true;
 var treeDemand:Int=-1;
 var keyboardCount:Int=-1;
 var padCount:Int=-1;
 var lateLeases=false;
 /** Owned, attached leases of hidden rows, rebuilt by apply so the per-frame late pass walks no tree. */
 var late:Array<VisibilityLease>=[];
 public var scannedNodes(default,null):Int=0;
 var targets:Array<VisibilityTarget>=[
  new VisibilityTarget("skills",null,["ui.hud.SkillBar","ui.hud.SkillBarPad","ui.hud.VehicleSkillBar","ui.hud.PassiveBar"]),
  new VisibilityTarget("baseActions",null,["ui.hud.BaseSkillsBar"]),
  new VisibilityTarget("statuses",null,["ui.hud.StatusBar"]),
  new VisibilityTarget("resources",null,["ui.comp.HealthBar","ui.comp.RessourceHeroBar","ui.hud.SparkSurgeGauge"]),
  new VisibilityTarget("consumables",null,["ui.hud.ConsumableWheel","ui.hud.ConsumableWheelPad"]),
  new VisibilityTarget("menuBar","menuBar",[]),new VisibilityTarget("chat","chat",[]),
  new VisibilityTarget("compass","compass",[]),new VisibilityTarget("groupBar","groupBar",[]),
  new VisibilityTarget("bossesInfo","bossesInfo",[]),new VisibilityTarget("oxygen","oxygen",[]),
  new VisibilityTarget("combatMeter","combatMeter",[]),new VisibilityTarget("feed","feed",[]),
  new VisibilityTarget("castBar",null,["ui.hud.CastingInfo"],true)
 ];
 public function new(source:NativeVisibilitySource) { this.source=source; }
 function attached(lease:VisibilityLease):Bool {
  if(lease.root==null || (lease.root!=hud && lease.root!=keyboard && lease.root!=pad)) return false;
  if(lease.root!=hud) {
   var ancestor=lease.root;
   var inHud=false;
   for(i in 0...MAX_DEPTH+2) {
    ancestor=source.field(ancestor,"parent");
    if(ancestor==hud) { inHud=true; break; }
    if(ancestor==null) break;
   }
   if(!inHud) return false;
  }
  var node=lease.node;
  for(i in 0...MAX_DEPTH+2) {
   if(node==lease.root) return true;
   node=source.field(node,"parent"); if(node==null) return false;
  }
  return false;
 }
 function release(lease:VisibilityLease):Void {
  if(lease.owned && attached(lease)) {
   source.setVisible(lease.node,lease.original);
   lease.owned=false;
  }
 }
 function shownInHud(lease:VisibilityLease):Bool {
  var node=lease.node;
  for(i in 0...MAX_DEPTH+3) {
   if(!source.visible(node) || source.field(node,"alpha")==0.0) return false;
   if(node==hud) return true;
   node=source.field(node,"parent"); if(node==null) return false;
  }
  return false;
 }
 public function clear(attachedHud:Bool):Void {
  discoveryDirty=true; treeDemand=keyboardCount=padCount=-1; lateLeases=false; late.resize(0);
  chatLease=null; chatTarget=null;
  for(target in targets) {
   for(lease in target.leases) if(attachedHud) try { release(lease); } catch(_:Dynamic) {}
   target.leases.resize(0); target.row=null; target.failed=false;
  }
  hud=null; keyboard=null; pad=null; config=null; nextScan=-1e9; hudRetry=-1e9; previousTime=-1e9; source.reset();
 }
 function add(target:VisibilityTarget,node:Dynamic,root:Dynamic):Void {
  if(node==null) return;
  // One lease per live node, even when the bar scan and the HUD scan both reach it.
  for(lease in target.leases) if(lease.node==node) return;
  if(!source.canHide(node)) return;
  target.found=true;
  target.leases.push(new VisibilityLease(node,root,target));
 }
 /** Shallow HUD walk for hudScan targets only; skips the heavy containers and spends its own node budget. */
 function scanHud(node:Dynamic,depth:Int,skip:Array<Dynamic>):Void {
  if(node==null || depth>HUD_DEPTH || visited>=MAX_NODES) return;
  visited++;
  if(depth>0) for(target in targets) if(target.hudScan) {
   try {
    for(name in target.types) if(source.matches(node,name)) { add(target,node,hud); return; }
   } catch(_:Dynamic) { target.failed=true; }
  }
  var count=source.childCount(node);
  if(count<0) return;
  if(count>MAX_NODES) count=MAX_NODES;
  for(i in 0...count) {
   if(visited>=MAX_NODES) break;
   var child=source.childAt(node,i);
   if(skip.indexOf(child)>=0) continue;
   scanHud(child,depth+1,skip);
  }
 }
 function scanBar(node:Dynamic,root:Dynamic,depth:Int):Void {
  if(node==null || depth>MAX_DEPTH || visited>=MAX_NODES) return;
  visited++;
  var matched=false;
  for(target in targets) if(target.fieldName==null) {
   try {
    for(name in target.types) if(source.matches(node,name)) {
     add(target,node,root); matched=true; break;
    }
   } catch(_:Dynamic) { target.failed=true; }
  }
  // A matched section owns its children; never walk hundreds of skill/status icon descendants.
  if(matched) return;
  var count=source.childCount(node);
  if(count<0) return;
  if(count>MAX_NODES) count=MAX_NODES;
  for(i in 0...count) {
   if(visited>=MAX_NODES) break;
   scanBar(source.childAt(node,i),root,depth+1);
  }
 }
 public function apply(nextHud:Dynamic,heroBar:Dynamic,heroBarPad:Dynamic,cfg:NativeHideConfig,now:Float):Void {
  scannedNodes=0; chatLease=null; chatTarget=null; lateLeases=false; late.resize(0);
  if(cfg==null) return;
  if(nextHud!=hud || cfg!=config) {
   clear(nextHud==hud && hud!=null); hud=nextHud; config=cfg;
   for(target in targets) for(row in cfg.elements) if(row.id==target.id) { target.row=row; break; }
  }
  if(keyboard!=heroBar || pad!=heroBarPad || now<previousTime) { nextScan=-1e9; discoveryDirty=true; }
  keyboard=heroBar; pad=heroBarPad; previousTime=now;
  var probe=cfg.probe; var active=probe; var needBars=probe; cfg.probe=false;
  for(target in targets) {
   target.lateFailed=false;
   if(target.row!=null && target.row.hidden.get()) active=true;
   if(target.fieldName==null && target.row!=null && target.row.hidden.get()) needBars=true;
   for(lease in target.leases) if(lease.owned) active=true;
  }
  var demand=0; var demandBit=1;
  for(target in targets) if(target.fieldName==null) {
   if(probe || (target.row!=null && target.row.hidden.get())) demand|=demandBit;
   demandBit<<=1;
   // A detached/rebuilt section invalidates discovery without a periodic tree scan.
   for(lease in target.leases) if(!attached(lease)) discoveryDirty=true;
  }
  if(demand!=treeDemand) { discoveryDirty=true; nextScan=-1e9; treeDemand=demand; }
  if(needBars) {
   var kc=keyboard==null ? 0 : source.childCount(keyboard);
   var pc=pad==null ? 0 : source.childCount(pad);
   if(kc!=keyboardCount || pc!=padCount) { keyboardCount=kc; padCount=pc; discoveryDirty=true; }
  }
  if(!active) {
   // No ownership remains: discard live children rather than retaining an idle HUD tree.
   for(target in targets) target.leases.resize(0);
   nextScan=-1e9;
   return;
  }
  cfg.elementsStatus="";
  var chatExternal=false;
  try { chatExternal=source.externalChat(); } catch(_:Dynamic) {}
  // Named trigger for the HUD walk: a wanted HUD-scan row that found nothing retries on a slow safety-net interval.
  if(now>=hudRetry) for(target in targets) if(target.hudScan && target.row!=null && target.leases.length==0
   && (probe || target.row.hidden.get())) { discoveryDirty=true; hudRetry=now+HUD_RETRY_S; break; }
  var scan=needBars && discoveryDirty && now>=nextScan;
  if(scan) {
   discoveryDirty=false;
   nextScan=now+SCAN_S; visited=0;
   for(target in targets) { target.found=false; target.failed=false; }
   try {
    scanBar(keyboard,keyboard,0); scanBar(pad,pad,0);
    scannedNodes=visited;
    if(visited>=MAX_NODES) cfg.elementsStatus="Native bottom-bar discovery reached its scan limit.";
   } catch(_:Dynamic) { cfg.elementsStatus="Some native bottom-bar elements could not be observed."; }
   try {
    var skip:Array<Dynamic>=[];
    for(name in HUD_SKIP) skip.push(source.field(hud,name));
    visited=0; scanHud(hud,0,skip);
    scannedNodes+=visited;
   } catch(_:Dynamic) { cfg.elementsStatus="Some native HUD elements could not be observed."; }
  }
  for(target in targets) {
   var row=target.row; if(row==null) continue;
   var owned=false; for(lease in target.leases) if(lease.owned) { owned=true; break; }
   if(!probe && !scan && !row.hidden.get() && !owned) continue;
   if(target.id=="chat" && chatExternal) {
    // The other mod now owns chat. Do not overwrite its visibility, even to restore a capture.
    target.leases.resize(0); row.state=NativeHideElement.STATE_EXTERNAL; continue;
   }
   try {
    if(target.fieldName!=null) {
     var currentNode=source.field(hud,target.fieldName);
     var index=target.leases.length;
     while(index>0) {
      var old=target.leases[--index];
      if(old.node!=currentNode) { release(old); target.leases.splice(index,1); }
     }
     add(target,currentNode,hud);
    }
    var found=false;
    var shown=false;
    var i=target.leases.length;
    while(i>0) {
     var lease=target.leases[--i];
     if(!attached(lease)) { target.leases.splice(i,1); continue; }
     found=true;
     if(row.hidden.get()) {
      var current=source.visible(lease.node);
      var first=!lease.owned;
      if(!lease.owned) lease.original=current;
      else if(current) lease.original=true; // Native policy explicitly re-showed it since our last pass.
      lease.owned=true; // Keep restoration responsibility even if the setter fails after applying a write.
      lateLeases=true;
      if(current || (first && target.id=="chat")) source.setVisible(lease.node,false);
      if(target.id=="chat") { chatLease=lease; chatTarget=target; }
     } else release(lease);
     if(!row.hidden.get() && shownInHud(lease)) shown=true;
    }
    row.state=hud==null ? NativeHideElement.STATE_WAITING : target.failed ? NativeHideElement.STATE_ERROR
     : !found ? NativeHideElement.STATE_ABSENT
     : target.fieldName==null && !target.hudScan && cfg.hideBottomBar.get() ? NativeHideElement.STATE_COVERED
     : row.hidden.get() ? NativeHideElement.STATE_HIDDEN : shown ? NativeHideElement.STATE_FOUND : NativeHideElement.STATE_NATIVE_HIDDEN;
   } catch(_:Dynamic) {
    row.state=NativeHideElement.STATE_ERROR;
    cfg.elementsStatus="A native visibility operation failed; affected rows show an error.";
   }
  }
  // Attachment, ownership and the external-chat decision were settled above. The late pass only needs this flat list.
  for(target in targets) {
   var row=target.row;
   if(row==null || !row.hidden.get() || (target.id=="chat" && chatExternal)) continue;
   for(lease in target.leases) if(lease.owned) late.push(lease);
  }
  lateLeases=late.length>0;
 }
 /** Existing GameApp.update postfix: enforce cached leases, with no discovery or type matching. */
 public function hasLeases():Bool return lateLeases;
 /** One visibility read per owned lease; no ancestry walks, registry lookups or field-name reads. */
 public function reassert(currentHud:Dynamic):Void {
  if(!lateLeases || currentHud!=hud) return;
  for(lease in late) {
   var target=lease.target;
   if(target.lateFailed || !target.row.hidden.get()) continue;
   try {
    if(source.visible(lease.node)) { lease.original=true; source.setVisible(lease.node,false); }
   } catch(_:Dynamic) { target.lateFailed=true; target.row.state=NativeHideElement.STATE_ERROR; }
  }
 }
 /** Presentation-only late pass. Discovery and setter resolution were completed by apply. */
 public function hasChatLease():Bool return chatLease!=null && chatTarget!=null && chatTarget.row.hidden.get();
 public function reassertChat(currentHud:Dynamic):Void {
  var lease=chatLease; var target=chatTarget;
  if(lease==null || target==null || currentHud!=hud || !lease.owned || !target.row.hidden.get()) return;
  try {
   if(source.field(hud,"chat")!=lease.node || !attached(lease)) { chatLease=null; return; }
   if(source.visible(lease.node)) { lease.original=true; source.setVisible(lease.node,false); }
  } catch(_:Dynamic) {
   chatLease=null; target.row.state=NativeHideElement.STATE_ERROR;
   config.elementsStatus="Native chat hiding failed during the late visibility pass.";
  }
 }
}
