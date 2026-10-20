package solarflare.resourcetracker;

import imgui.ImGui;
import imgui.ref.BoolRef;
import imgui.ref.FloatRef;
import imgui.ref.IntRef;
import solarflare.ui.GameIcons;
import solarflare.ui.GameIcons.TextureHandle;

/** Artwork settings plus frozen progress; holds no engine objects. */
class ResourceSkin {
	public var enabled=new BoolRef(false);
	public var keepContent=new BoolRef(true);
	public var opacity=new FloatRef(1);
	public var direction=new IntRef(0);
	public var insetX=new FloatRef(0);
	public var insetY=new FloatRef(0);
	public var background:String="";
	public var fill:String="";
	public var frame:String="";
	public var progress:Float=0;
	/** Element-specific image keys (attack states, combo points, prayers...). "" = built-in drawing. */
	public var slots:Array<String>;
	var clipBox={x:0.0,y:0.0,w:0.0,h:0.0};
	public function new(slotCount:Int=0) { slots=[for(_ in 0...slotCount) ""]; }
	public function dump():Dynamic return {enabled:enabled.get(),content:keepContent.get(),opacity:opacity.get(),direction:direction.get(),insetX:insetX.get(),insetY:insetY.get(),background:background,fill:fill,frame:frame,slots:slots.copy()};
	public function apply(d:Dynamic):Void {
		enabled.set(d!=null && d.enabled==true); keepContent.set(d==null || d.content!=false);
		opacity.set(number(d,"opacity",1,0,1)); direction.set(Std.int(number(d,"direction",0,0,3)));
		insetX.set(number(d,"insetX",0,0,200)); insetY.set(number(d,"insetY",0,0,200));
		background=key(d,"background"); fill=key(d,"fill"); frame=key(d,"frame");
		var saved:Array<Dynamic>=d!=null && Std.isOfType(Reflect.field(d,"slots"),Array) ? Reflect.field(d,"slots") : [];
		for(i in 0...slots.length) {
			var k:Dynamic=i<saved.length ? saved[i] : null;
			slots[i]=Std.isOfType(k,String) && solarflare.ui.CustomImages.stemOf(k).length>0 ? k : "";
		}
	}
	static function number(d:Dynamic,k:String,f:Float,lo:Float,hi:Float):Float { var v=d==null ? null : Reflect.field(d,k); return solarflare.ui.HudLayoutModel.finite(v) ? Math.max(lo,Math.min(hi,v)) : f; }
	static function key(d:Dynamic,k:String):String { var v=d==null ? null : Reflect.field(d,k); return Std.isOfType(v,String) && solarflare.ui.CustomImages.stemOf(v).length>0 ? v : ""; }
	public function ready():Bool return enabled.get() && opacity.get()>0 && (background.length>0 || fill.length>0 || frame.length>0)
		&& (background.length==0 || loaded(background)) && (fill.length==0 || loaded(fill)) && (frame.length==0 || loaded(frame));
	static function loaded(k:String):Bool return k.length>0 && GameIcons.get(k)!=(0:TextureHandle);
	/** Key of slot `i` when artwork is on and that image is ready, otherwise "" (use the built-in look). */
	public function slotKey(i:Int):String {
		if(!enabled.get() || i<0 || i>=slots.length) return "";
		var k=slots[i];
		return k.length>0 && loaded(k) ? k : "";
	}
	/** Draws slot `i` aspect-fit and centered in the rect. False (nothing drawn) when the slot is empty or not loaded. */
	public function drawSlot(dl:Dynamic,i:Int,x:Single,y:Single,w:Single,h:Single,alpha:Float=1):Bool {
		var k=slotKey(i); if(k.length==0) return false;
		var tw=GameIcons.texW(k); var th=GameIcons.texH(k);
		var fw:Single=w; var fh:Single=h;
		if(tw>0 && th>0) { var aspect=tw/th; fh=w/aspect; if(fh>h) { fh=h; fw=h*aspect; } }
		var tint=(Std.int(Math.max(0,Math.min(1,alpha*opacity.get()))*255)<<24)|0xFFFFFF;
		return GameIcons.drawKey(dl,k,x+(w-fw)*0.5,y+(h-fh)*0.5,fw,fh,tint);
	}
	public function paint(x:Single,y:Single,w:Single,h:Single,amount:Float,top:Bool):Void {
		if(!enabled.get()) return;
		var dl=ImGui.getWindowDrawList();
		var tint=(Std.int(opacity.get()*255)<<24)|0xFFFFFF;
		if(top) { if(frame.length>0) GameIcons.drawKey(dl,frame,x,y,w,h,tint); return; }
		if(background.length>0) GameIcons.drawKey(dl,background,x,y,w,h,tint);
		if(fill.length==0) return;
		var f=ResourceArtGeometry.fraction(amount);
		var ix:Single=Math.min(insetX.get(),Math.max(0,(w-1)*0.5)); var iy:Single=Math.min(insetY.get(),Math.max(0,(h-1)*0.5));
		var fw:Single=w-ix*2; var fh:Single=h-iy*2; var fx:Single=x+ix; var fy:Single=y+iy;
		if(f<=0 || fw<=0 || fh<=0) return;
		var box=ResourceArtGeometry.clip(fx,fy,fw,fh,f,direction.get(),clipBox);
		ImGui.pushClipRect(ImGui.vec2(box.x,box.y),ImGui.vec2(box.x+box.w,box.y+box.h),true);
		var failure:Dynamic=null;
		try GameIcons.drawKey(dl,fill,fx,fy,fw,fh,tint) catch(e:Dynamic) failure=e;
		ImGui.popClipRect();
		if(failure!=null) throw failure;
	}
}
