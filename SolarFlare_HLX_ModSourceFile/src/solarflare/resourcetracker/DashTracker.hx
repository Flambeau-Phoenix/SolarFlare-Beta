package solarflare.resourcetracker;

import imgui.ImGui;
import imgui.ref.BoolRef;
import imgui.ref.FloatRef;
import imgui.ref.IntRef;
import solarflare.ui.HudChrome;
import solarflare.ui.SettingsStore;
import solarflare.ui.ThemePalette;
import solarflare.ui.UiCol;
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
	/** Custom palette: ready charges / the charge that is recharging. Off uses the theme accent. */
	public var useColors=new BoolRef(false);
	public var readyColor:hl.Bytes;
	public var rechargeColor:hl.Bytes;
	public var border=new BoolRef(false);
	public var chrome=new HudChrome(420,850);
	public var openBuilder:Void->Void;
	var defaultChrome:Dynamic;
	var bodyFn:imgui.Structs.ImVec2->Void;
	var hideFn:Void->Void;
	var resizeFn:Single->Single->Void;
	public static final STYLES=["Fuse", "Recharge ring", "Charge pips", "Chevrons", "Orbs", "Comet bar"];
	public static inline var MAX_STYLE:Int=5;
	public function new() { readyColor=ImGui.v4(0.35,0.80,0.95,1); rechargeColor=ImGui.v4(0.95,0.70,0.25,1); bodyFn=body; hideFn=hide; resizeFn=resize; defaultChrome=SettingsStore.chromeDump(chrome); }
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
		solarflare.ui.UiHints.noteWrapped("Tracks the equipped dash. The fuse burns down to the next charge, including while another charge is available. Unlock to position it; missing data displays a placeholder.");
	}
	public function dump():Dynamic return {hidden:hidden.get(),w:width.get(),h:height.get(),style:style.get(),count:showCount.get(),time:showTime.get(),only:onlyRecharging.get(),colors:useColors.get(),ready:v4(readyColor),recharge:v4(rechargeColor),border:border.get(),chrome:SettingsStore.chromeDump(chrome)};
	static function v4(b:hl.Bytes):Array<Float> return [b.getF32(0),b.getF32(4),b.getF32(8),b.getF32(12)];
	static function loadV4(b:hl.Bytes,data:Dynamic):Void {
		if(data==null) return;
		try {
			var arr:Array<Dynamic>=data; if(arr==null || arr.length<4) return;
			for(i in 0...4) if(!solarflare.ui.HudLayoutModel.finite(arr[i])) return;
			for(i in 0...4) b.setF32(i*4,Math.max(0,Math.min(1,arr[i])));
		} catch(_:Dynamic) {}
	}
	public function apply(d:Dynamic):Void {
		hidden.set(d==null || d.hidden!=false); width.set(180); height.set(64); style.set(0);
		showCount.set(d==null || d.count!=false); showTime.set(d==null || d.time!=false); onlyRecharging.set(d!=null && d.only==true);
		SettingsStore.applyChrome(chrome,d==null || d.chrome==null ? defaultChrome : d.chrome);
		useColors.set(false); border.set(false);
		if(d==null) return;
		useColors.set(d.colors==true); border.set(d.border==true);
		loadV4(readyColor,d.ready); loadV4(rechargeColor,d.recharge);
		if(solarflare.ui.HudLayoutModel.finite(d.w)) width.set(Math.max(48,Math.min(1200,d.w)));
		if(solarflare.ui.HudLayoutModel.finite(d.h)) height.set(Math.max(24,Math.min(400,d.h)));
		if(solarflare.ui.HudLayoutModel.finite(d.style)) style.set(Std.int(Math.max(0,Math.min(MAX_STYLE,d.style))));
	}
	public static function render(cfg:DashTracker,s:DashState,w:Single,h:Single):Void {
		var p=ImGui.getCursorScreenPos(); ImGui.dummy(ImGui.vec2(w,h));
		var dl=ImGui.getWindowDrawList(); var t=ThemePalette.current();
		var accent=ImGui.colorConvertFloat4ToU32(s.known && s.charges>0 ? t.accent : t.textDisabled);
		var ready=cfg.useColors.get() ? packed(cfg.readyColor) : accent;
		var recharge=cfg.useColors.get() ? packed(cfg.rechargeColor) : accent;
		var dim=ImGui.colorConvertFloat4ToU32(t.border);
		var text=ImGui.colorConvertFloat4ToU32(t.text);
		var outline=cfg.border.get();
		var art=ResourceArtwork.active!=null ? ResourceArtwork.active.get("dash") : null;
		var barH:Single=cfg.showCount.get() || cfg.showTime.get() ? Math.max(6,h-24) : h;
		var style=cfg.style.get();
		if(style==1) {
			var r:Single=Math.max(4,Math.min(w,barH)*0.5-4); var cx:Single=p.x+w*0.5; var cy:Single=p.y+barH*0.5;
			ImGui.ImDrawList_AddCircle(dl,ImGui.vec2(cx,cy),r,dim,48,3);
			arc(dl,cx,cy,r,s.known ? (s.left>0 ? s.remaining : 1) : 0,s.left>0 ? recharge : ready);
		} else if(style==2) {
			var n=cellCount(s); var cell:Single=w/n;
			for(i in 0...n) {
				var x:Single=p.x+i*cell; var fill=cellFill(s,i);
				if(drawCellArt(dl,art,x+2,p.y+2,cell-4,barH-4,s.known ? fill : 0)) continue;
				ImGui.ImDrawList_AddRectFilled(dl,ImGui.vec2(x+2,p.y+2),ImGui.vec2(x+cell-2,p.y+barH-2),dim,3);
				if(s.known && fill>0) ImGui.ImDrawList_AddRectFilled(dl,ImGui.vec2(x+2,p.y+2),ImGui.vec2(x+2+(cell-4)*fill,p.y+barH-2),fill>=1 ? ready : recharge,3);
				if(outline) ImGui.ImDrawList_AddRect(dl,ImGui.vec2(x+2,p.y+2),ImGui.vec2(x+cell-2,p.y+barH-2),UiCol.withAlpha(ready,0xB0),3,1.2);
			}
		} else if(style==3) {
			var n=cellCount(s); var cell:Single=w/n;
			for(i in 0...n) {
				var x:Single=p.x+i*cell+2; var cw:Single=cell-4; var fill=s.known ? cellFill(s,i) : 0;
				if(drawCellArt(dl,art,x,p.y+2,cw,barH-4,fill)) continue;
				chevron(dl,x,p.y+2,cw,barH-4,dim);
				if(fill>0) {
					ImGui.pushClipRect(ImGui.vec2(x,p.y),ImGui.vec2(x+cw*fill,p.y+barH),true);
					chevron(dl,x,p.y+2,cw,barH-4,fill>=1 ? ready : recharge);
					ImGui.popClipRect();
				}
			}
		} else if(style==4) {
			var n=cellCount(s); var cell:Single=w/n;
			var r:Single=Math.max(3,Math.min(cell,barH)*0.5-3);
			for(i in 0...n) {
				var cx:Single=p.x+(i+0.5)*cell; var cy:Single=p.y+barH*0.5; var fill=s.known ? cellFill(s,i) : 0;
				if(drawCellArt(dl,art,cx-r,cy-r,r*2,r*2,fill)) continue;
				ImGui.ImDrawList_AddCircleFilled(dl,ImGui.vec2(cx,cy),r,dim,28);
				if(fill>=1) ImGui.ImDrawList_AddCircleFilled(dl,ImGui.vec2(cx,cy),r,ready,28);
				else if(fill>0) pie(dl,cx,cy,r,fill,recharge);
				if(outline || fill>=1) ImGui.ImDrawList_AddCircle(dl,ImGui.vec2(cx,cy),r,UiCol.withAlpha(ready,fill>=1 ? 0xFF : 0x80),28,1.6);
			}
		} else if(style==5) {
			var y:Single=p.y+barH*0.5; var remain=s.known ? (s.left>0 ? s.remaining : 1) : 0;
			var x0:Single=p.x+6; var span:Single=Math.max(1,w-12); var tip:Single=x0+span*remain;
			ImGui.ImDrawList_AddLine(dl,ImGui.vec2(x0,y),ImGui.vec2(x0+span,y),dim,6);
			var col=s.left>0 ? recharge : ready;
			if(remain>0) {
				// Trail: eight slices brightening toward the head.
				for(k in 0...8) {
					var a0=x0+(tip-x0)*k/8; var a1=x0+(tip-x0)*(k+1)/8;
					ImGui.ImDrawList_AddLine(dl,ImGui.vec2(a0,y),ImGui.vec2(a1,y),UiCol.withAlpha(col,Std.int(60+195*(k+1)/8)),k==7 ? 6 : 4+k*0.25);
				}
			}
			if(s.known && s.left>0) {
				if(art==null || !art.drawSlot(dl,2,tip-8,y-8,16,16)) {
					ImGui.ImDrawList_AddCircleFilled(dl,ImGui.vec2(tip,y),9,UiCol.withAlpha(col,0x40),20);
					ImGui.ImDrawList_AddCircleFilled(dl,ImGui.vec2(tip,y),5,col,16);
					ImGui.ImDrawList_AddCircleFilled(dl,ImGui.vec2(tip,y),2,text,12);
				}
			}
		} else {
			var y:Single=p.y+barH*0.5; var remain=s.known ? (s.left>0 ? s.remaining : 1) : 0;
			ImGui.ImDrawList_AddLine(dl,ImGui.vec2(p.x+4,y),ImGui.vec2(p.x+w-4,y),dim,4);
			var tip:Single=p.x+4+(w-8)*remain;
			if(remain>0) ImGui.ImDrawList_AddLine(dl,ImGui.vec2(p.x+4,y),ImGui.vec2(tip,y),s.left>0 ? recharge : ready,4);
			if(s.known && s.left>0) {
				if(art==null || !art.drawSlot(dl,2,tip-7,y-7,14,14)) { ImGui.ImDrawList_AddCircleFilled(dl,ImGui.vec2(tip,y),5,recharge,16); ImGui.ImDrawList_AddCircleFilled(dl,ImGui.vec2(tip,y),2,text,12); }
			}
		}
		if(cfg.showCount.get()) ImGui.ImDrawList_AddText_Vec2(dl,ImGui.vec2(p.x+2,p.y+h-20),text,s.countLabel);
		if(cfg.showTime.get()) { var ts=ImGui.calcTextSize(s.timeLabel); ImGui.ImDrawList_AddText_Vec2(dl,ImGui.vec2(p.x+w-ts.x-2,p.y+h-20),text,s.timeLabel); }
	}
	static inline function cellCount(s:DashState):Int return s.known ? Std.int(Math.max(1,Math.min(12,s.max))) : 2;
	/** 1 = ready charge, 0..1 = the charge that is recharging, 0 = empty. */
	static inline function cellFill(s:DashState,i:Int):Float return i<s.charges ? 1 : i==s.charges && s.left>0 ? 1-s.remaining : 0;
	static function packed(b:hl.Bytes):Int return ImGui.colorConvertFloat4ToU32(ImGui.vec4(b.getF32(0),b.getF32(4),b.getF32(8),b.getF32(12)));
	/** User images: "Charge ready" (slot 0) over "Charge empty" (slot 1), the ready one revealed left to right while recharging. */
	static function drawCellArt(dl:Dynamic,art:ResourceSkin,x:Single,y:Single,w:Single,h:Single,fill:Float):Bool {
		if(art==null || (art.slotKey(0).length==0 && art.slotKey(1).length==0)) return false;
		art.drawSlot(dl,1,x,y,w,h);
		if(fill>0) {
			ImGui.pushClipRect(ImGui.vec2(x,y),ImGui.vec2(x+w*Math.min(1,fill),y+h),true);
			art.drawSlot(dl,0,x,y,w,h);
			ImGui.popClipRect();
		}
		return true;
	}
	/** Two convex arms meeting at the right tip. */
	static function chevron(dl:Dynamic,x:Single,y:Single,w:Single,h:Single,col:Int):Void {
		var t:Single=Math.max(3,w*0.34); var ym:Single=y+h*0.5; var xr:Single=x+w;
		ImGui.ImDrawList_AddQuadFilled(dl,ImGui.vec2(x,y),ImGui.vec2(x+t,y),ImGui.vec2(xr,ym),ImGui.vec2(xr-t,ym),col);
		ImGui.ImDrawList_AddQuadFilled(dl,ImGui.vec2(xr-t,ym),ImGui.vec2(xr,ym),ImGui.vec2(x+t,y+h),ImGui.vec2(x,y+h),col);
	}
	/** Clockwise pie from twelve o'clock. */
	static function pie(dl:Dynamic,cx:Single,cy:Single,r:Single,f:Float,col:Int):Void {
		ImGui.ImDrawList_PathClear(dl);
		ImGui.ImDrawList_PathLineTo(dl,ImGui.vec2(cx,cy));
		ImGui.ImDrawList_PathArcTo(dl,ImGui.vec2(cx,cy),r,-Math.PI*0.5,-Math.PI*0.5+Math.PI*2*Math.max(0,Math.min(1,f)),32);
		ImGui.ImDrawList_PathFillConvex(dl,col);
	}
	static function arc(dl:Dynamic,cx:Single,cy:Single,r:Single,f:Float,col:Int):Void {
		var n=Std.int(Math.ceil(48*Math.max(0,Math.min(1,f))));
		for(i in 0...n) {
			var a=-Math.PI*0.5+i*Math.PI*2/48; var b=-Math.PI*0.5+Math.min((i+1)/48,f)*Math.PI*2;
			ImGui.ImDrawList_AddLine(dl,ImGui.vec2(cx+Math.cos(a)*r,cy+Math.sin(a)*r),ImGui.vec2(cx+Math.cos(b)*r,cy+Math.sin(b)*r),col,3);
		}
	}
}
