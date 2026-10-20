package solarflare.resourcetracker;

import imgui.ImGui;
import imgui.ref.BoolRef;
import imgui.ref.FloatRef;
import imgui.ref.IntRef;
import solarflare.ui.HudChrome;
import solarflare.ui.SettingsStore;
import solarflare.ui.ThemePalette;
import solarflare.ui.UiLayout;

/** Resource-owned presentation settings; observation lives in AuraMovementObserver. */
class DashTracker {
	public var hidden=new BoolRef(true);
	public var width=new FloatRef(180);
	public var height=new FloatRef(64);
	public var style=new IntRef(0);
	public var showCount=new BoolRef(true);
	public var showTime=new BoolRef(true);
	public var onlyRecharging=new BoolRef(false);
	public var chrome=new HudChrome(420,850);
	public var openBuilder:Void->Void;
	var defaultChrome:Dynamic;
	var bodyFn:imgui.Structs.ImVec2->Void;
	var hideFn:Void->Void;
	var resizeFn:Single->Single->Void;
	public static final STYLES=["Fuse", "Recharge ring", "Charge pips"];
	public function new() { bodyFn=body; hideFn=hide; resizeFn=resize; defaultChrome=SettingsStore.chromeDump(chrome); }
	public function minWidth():Single return showCount.get() && showTime.get() ? 112 : 48;
	public function minHeight():Single return showCount.get() || showTime.get() ? 40 : 24;
	public function draw():Void {
		if(hidden.get()) return;
		var s=solarflare.aura.AuraMovementObserver.state;
		if(chrome.locked.get() && (!s.known || onlyRecharging.get() && s.left<=0)) return;
		solarflare.ui.HUDWidgetWindow.draw("SolarFlare Dash","Dash",chrome,Math.max(minWidth(),width.get()),Math.max(minHeight(),height.get()),bodyFn,openBuilder,hideFn,false,null,resizeFn);
	}
	function body(size:imgui.Structs.ImVec2):Void render(this,solarflare.aura.AuraMovementObserver.state,size.x,size.y);
	function hide():Void { hidden.set(true); SettingsStore.markDirty(); }
	function resize(w:Single,h:Single):Void { width.set(Math.max(minWidth(),Math.min(1200,w))); height.set(Math.max(minHeight(),Math.min(400,h))); SettingsStore.markDirty(); }
	public function drawSettings():Void {
		UiLayout.propertyGrid("##rt_dash_options",function() {
			UiLayout.propertyRow("Display",function() {
				if(ImGui.beginCombo("##rt_dash_style",STYLES[style.get()])) {
					for(i in 0...STYLES.length) if(ImGui.selectable(STYLES[i],style.get()==i)) { style.set(i); SettingsStore.markDirty(); }
					ImGui.endCombo();
				}
			});
			UiLayout.propertyRow("Charges",function() { if(ImGui.checkbox("Show count##rt_dash_count",showCount)) SettingsStore.markDirty(); });
			UiLayout.propertyRow("Timer",function() { if(ImGui.checkbox("Show seconds##rt_dash_time",showTime)) SettingsStore.markDirty(); });
			UiLayout.propertyRow("Visibility",function() { if(ImGui.checkbox("Only while recharging##rt_dash_active",onlyRecharging)) SettingsStore.markDirty(); });
		});
		ImGui.textWrapped("Tracks the equipped dash. The fuse burns down to the next charge, including while another charge is available. Unlock to position it; missing data displays a placeholder.");
	}
	public function dump():Dynamic return {hidden:hidden.get(),w:width.get(),h:height.get(),style:style.get(),count:showCount.get(),time:showTime.get(),only:onlyRecharging.get(),chrome:SettingsStore.chromeDump(chrome)};
	public function apply(d:Dynamic):Void {
		hidden.set(d==null || d.hidden!=false); width.set(180); height.set(64); style.set(0);
		showCount.set(d==null || d.count!=false); showTime.set(d==null || d.time!=false); onlyRecharging.set(d!=null && d.only==true);
		SettingsStore.applyChrome(chrome,d==null || d.chrome==null ? defaultChrome : d.chrome);
		if(d==null) return;
		if(solarflare.ui.HudLayoutModel.finite(d.w)) width.set(Math.max(48,Math.min(1200,d.w)));
		if(solarflare.ui.HudLayoutModel.finite(d.h)) height.set(Math.max(24,Math.min(400,d.h)));
		if(solarflare.ui.HudLayoutModel.finite(d.style)) style.set(Std.int(Math.max(0,Math.min(2,d.style))));
	}
	public static function render(cfg:DashTracker,s:DashState,w:Single,h:Single):Void {
		var p=ImGui.getCursorScreenPos(); ImGui.dummy(ImGui.vec2(w,h));
		var dl=ImGui.getWindowDrawList(); var t=ThemePalette.current();
		var accent=ImGui.colorConvertFloat4ToU32(s.known && s.charges>0 ? t.accent : t.textDisabled);
		var dim=ImGui.colorConvertFloat4ToU32(t.border);
		var text=ImGui.colorConvertFloat4ToU32(t.text);
		var barH:Single=cfg.showCount.get() || cfg.showTime.get() ? Math.max(6,h-24) : h;
		if(cfg.style.get()==1) {
			var r:Single=Math.max(4,Math.min(w,barH)*0.5-4); var cx:Single=p.x+w*0.5; var cy:Single=p.y+barH*0.5;
			ImGui.ImDrawList_AddCircle(dl,ImGui.vec2(cx,cy),r,dim,48,3);
			arc(dl,cx,cy,r,s.known ? (s.left>0 ? s.remaining : 1) : 0,accent);
		} else if(cfg.style.get()==2) {
			var n=s.known ? Std.int(Math.min(12,s.max)) : 2;
			var cell:Single=w/n;
			for(i in 0...n) {
				var x:Single=p.x+i*cell;
				ImGui.ImDrawList_AddRectFilled(dl,ImGui.vec2(x+2,p.y+2),ImGui.vec2(x+cell-2,p.y+barH-2),dim,3);
				var fill:Float=i<s.charges ? 1 : i==s.charges && s.left>0 ? 1-s.remaining : 0;
				if(s.known && fill>0) ImGui.ImDrawList_AddRectFilled(dl,ImGui.vec2(x+2,p.y+2),ImGui.vec2(x+2+(cell-4)*fill,p.y+barH-2),accent,3);
			}
		} else {
			var y:Single=p.y+barH*0.5; var remain=s.known ? (s.left>0 ? s.remaining : 1) : 0;
			ImGui.ImDrawList_AddLine(dl,ImGui.vec2(p.x+4,y),ImGui.vec2(p.x+w-4,y),dim,4);
			var tip:Single=p.x+4+(w-8)*remain;
			if(remain>0) ImGui.ImDrawList_AddLine(dl,ImGui.vec2(p.x+4,y),ImGui.vec2(tip,y),accent,4);
			if(s.known && s.left>0) { ImGui.ImDrawList_AddCircleFilled(dl,ImGui.vec2(tip,y),5,accent,16); ImGui.ImDrawList_AddCircleFilled(dl,ImGui.vec2(tip,y),2,text,12); }
		}
		if(cfg.showCount.get()) ImGui.ImDrawList_AddText_Vec2(dl,ImGui.vec2(p.x+2,p.y+h-20),text,s.countLabel);
		if(cfg.showTime.get()) { var ts=ImGui.calcTextSize(s.timeLabel); ImGui.ImDrawList_AddText_Vec2(dl,ImGui.vec2(p.x+w-ts.x-2,p.y+h-20),text,s.timeLabel); }
	}
	static function arc(dl:Dynamic,cx:Single,cy:Single,r:Single,f:Float,col:Int):Void {
		var n=Std.int(Math.ceil(48*Math.max(0,Math.min(1,f))));
		for(i in 0...n) {
			var a=-Math.PI*0.5+i*Math.PI*2/48; var b=-Math.PI*0.5+Math.min((i+1)/48,f)*Math.PI*2;
			ImGui.ImDrawList_AddLine(dl,ImGui.vec2(cx+Math.cos(a)*r,cy+Math.sin(a)*r),ImGui.vec2(cx+Math.cos(b)*r,cy+Math.sin(b)*r),col,3);
		}
	}
}
