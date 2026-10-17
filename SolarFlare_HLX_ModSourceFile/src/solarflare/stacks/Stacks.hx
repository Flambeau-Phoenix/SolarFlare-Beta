package solarflare.stacks;

import imgui.ref.BoolRef;
import imgui.Structs.ImVec2;
import solarflare.aura.AuraStatusCache;
import solarflare.ui.ConfigPanel;
import solarflare.ui.HudChrome;
import solarflare.ui.HUDWidgetWindow;
import solarflare.ui.SettingsStore;
import solarflare.stacks.StackConfig.StackTrackerConfig;

class StackView {
	public var config:StackTrackerConfig;
	public var state=new StackState();
	public var chrome:HudChrome;
	var owner:Stacks;
	var windowId:String;
	var bodyFn:ImVec2->Void;
	var editFn:Void->Void;
	var hideFn:Void->Void;
	var resizeFn:Single->Single->Void;
	public function new(t:StackTrackerConfig,owner:Stacks,index:Int) {
		config=t; this.owner=owner; chrome=new HudChrome(320+(index%4)*80,320+Std.int(index/4)*100);
		chrome.transparent.set(true); windowId="SolarFlare.Stacks."+t.id;
		bodyFn=body; editFn=edit; hideFn=hide; resizeFn=resize;
	}
	public function draw():Void {
		var t=config; if(!state.visible(t.enabled,t.hidden,t.hideAtZero)) return;
		HUDWidgetWindow.draw(windowId,t.name,chrome,StackLayout.width(t),StackLayout.height(t),bodyFn,editFn,hideFn,false,null,resizeFn);
	}
	function body(_:ImVec2):Void StackRenderer.draw(config,state);
	function edit():Void { owner.builder.select(config.id); owner.open.set(true); }
	function hide():Void { config.hidden=true; SettingsStore.markDirty(); }
	function resize(w:Single,h:Single):Void {
		config.cellSize=Math.max(8,Math.min(128,Math.min((w-(StackLayout.columns(config)-1)*config.gap)/StackLayout.columns(config),
			(h-(config.showCount ? 22 : 0)-(StackLayout.rows(config)-1)*config.gap)/StackLayout.rows(config))));
		SettingsStore.markDirty();
	}
	public function dumpChrome():Dynamic return {x:chrome.x.get(),y:chrome.y.get(),lock:chrome.locked.get(),trans:chrome.transparent.get(),
		collapsed:chrome.collapsed.get(),referenceWidth:chrome.referenceWidth,referenceHeight:chrome.referenceHeight,hudLayoutVersion:chrome.hudLayoutVersion};
	public function applyChrome(d:Dynamic):Void {
		if(d==null) return;
		chrome.x.set(StackConfig.number(d,"x",320,-10000,10000)); chrome.y.set(StackConfig.number(d,"y",320,-10000,10000));
		chrome.locked.set(Reflect.field(d,"lock")==true); chrome.transparent.set(Reflect.field(d,"trans")!=false);
		chrome.collapsed.set(Reflect.field(d,"collapsed")==true);
		chrome.restoreReference(d);
		chrome.hudLayoutVersion=Std.int(StackConfig.number(d,"hudLayoutVersion",0,0,100)); chrome.posDirty=true;
	}
}

/** Coordinates the existing shared observer, frozen views, and editor. No new engine polling. */
class Stacks {
	public var config=new StackConfig();
	public var open=new BoolRef(false);
	public var builder:StackBuilder;
	public var views:Array<StackView>=[];
	var host:ConfigPanel;
	var generation:Int=-1;
	var characterId:String="";
	public function new(host:ConfigPanel) { this.host=host; builder=new StackBuilder(this,host); }
	public function rebuild():Void {
		var old=views; views=[];
		for(t in config.trackers) {
			var v:StackView=null; for(previous in old) if(previous.config==t) { v=previous; break; }
			if(v==null) v=new StackView(t,this,views.length); views.push(v);
		}
		solarflare.ObserveDemand.markStatusDemandDirty();
		if(host.uiLayouts!=null) host.uiLayouts.requestReconcile();
	}
	public function view(id:String):StackView { for(v in views) if(v.config.id==id) return v; return null; }
	public function reset():Void { for(v in views) v.state.reset(); generation=-1; characterId=""; }
	public function clearTransientState():Void builder.clearTransientState();
	public function observe():Void {
		var current=solarflare.HealthCache.characterId;
		if(generation!=AuraStatusCache.ownerGeneration || characterId!=current) {
			reset(); builder.clearTransientState(); generation=AuraStatusCache.ownerGeneration; characterId=current;
		}
		for(v in views) {
			var t=v.config;
			if(!t.enabled || t.statusId.length==0 || !AuraStatusCache.isCurrent(solarflare.HealthCache.localHero)) { v.state.reset(); continue; }
			var s=AuraStatusCache.findExact(t.statusId);
			if(s==null) v.state.set(AuraStatusCache.domainKnown,false,false,0);
			else v.state.set(s.known,s.present,s.stacksKnown,s.stacks);
		}
	}
	public function draw():Void { for(v in views) v.draw(); }
	public function dump():Dynamic {
		var data=config.dump(); var placements:Dynamic={};
		for(v in views) Reflect.setField(placements,v.config.id,v.dumpChrome());
		Reflect.setField(data,"placements",placements); return data;
	}
	public function apply(data:Dynamic,keepHistory:Bool=false):Void {
		clearTransientState(); if(!keepHistory) builder.clearHistory(); config.apply(data); views=[]; rebuild(); reset();
		var placements=data!=null ? Reflect.field(data,"placements") : null;
		if(placements!=null) for(v in views) v.applyChrome(Reflect.field(placements,v.config.id));
	}
}
