package solarflare.ui;

import imgui.ImGui;

/** Cache-only presentation. Each font and clip scope unwinds on failure. */
class SlotBadgeRenderer {
	public static function draw(dl:Dynamic,label:String,x:Single,y:Single,w:Single,h:Single,fontSize:Single,color:Int,
			right:Bool=false,bottom:Bool=false,plate:Bool=true):Void {
		if(label==null || label.length==0 || w<=1 || h<=1) return;
		var font=ImGui.getFont(); if(font==null) return;
		var natural=ImGui.calcTextSize(label).x;
		ImGui.pushFont(font,SlotBadgeMetrics.fit(fontSize,ImGui.getFontSize(),natural,w,h));
		var failure:Dynamic=null;
		var clipped=false;
		try {
			ImGui.pushClipRect(ImGui.vec2(x,y),ImGui.vec2(x+w,y+h),true); clipped=true;
			var ts=ImGui.calcTextSize(label);
			var tx:Single=right ? x+w-ts.x-2 : x+2;
			var ty:Single=bottom ? y+h-ts.y-1 : y+1;
			if(plate) ImGui.ImDrawList_AddRectFilled(dl,ImGui.vec2(Math.max(x,tx-2),Math.max(y,ty-1)),ImGui.vec2(Math.min(x+w,tx+ts.x+2),Math.min(y+h,ty+ts.y+1)),0xDD000000,3);
			ImGui.ImDrawList_AddText_Vec2(dl,ImGui.vec2(tx,ty),color,label);
		} catch(e:Dynamic) failure=e;
		if(clipped) ImGui.popClipRect(); ImGui.popFont();
		if(failure!=null) throw failure;
	}
}
