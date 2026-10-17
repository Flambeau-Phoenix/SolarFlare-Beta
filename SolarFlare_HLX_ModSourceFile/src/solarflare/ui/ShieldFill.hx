package solarflare.ui;

import imgui.ImGui;
import imgui.Structs.ImVec2;

/** Draw only the white overlay, between the resource fill and its label. */
class ShieldFill {
	public static inline var COLOR:Int = 0x73FFFFFF;
	public static function bar(dl:Dynamic, x:Single, y:Single, w:Single, h:Single, ratio:Float, vertical:Bool):Void {
		if (ratio <= 0) return;
		ImGui.ImDrawList_PushClipRect(dl, ImGui.vec2(x, vertical ? y+h*(1-ratio) : y),
			ImGui.vec2(vertical ? x+w : x+w*ratio, y+h), true);
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x,y), ImGui.vec2(x+w,y+h), COLOR, 4);
		ImGui.ImDrawList_PopClipRect(dl);
	}
	public static function arc(dl:Dynamic, center:ImVec2, radius:Single, start:Single, end:Single, thickness:Single, caps:Bool=false):Void {
		if (end <= start) return;
		ImGui.ImDrawList_PathClear(dl);
		ImGui.ImDrawList_PathArcTo(dl, center, radius, start, end, 56);
		ImGui.ImDrawList_PathStroke(dl, COLOR, thickness, 0);
		if (caps) {
			ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(center.x+Math.cos(start)*radius,center.y+Math.sin(start)*radius), thickness*0.5,COLOR,12);
			ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(center.x+Math.cos(end)*radius,center.y+Math.sin(end)*radius), thickness*0.5,COLOR,12);
		}
	}
	public static function dome(dl:Dynamic, center:ImVec2, radius:Single, ratio:Float, thickness:Single):Void {
		if (ratio <= 0) return;
		var end:Single=-Math.PI+Math.PI*ratio;
		ImGui.ImDrawList_PathClear(dl);
		ImGui.ImDrawList_PathArcTo(dl,center,radius,-Math.PI,end,40);
		ImGui.ImDrawList_PathLineTo(dl,center);
		ImGui.ImDrawList_PathFillConvex(dl,COLOR);
		arc(dl,center,radius,-Math.PI,end,thickness);
	}
	public static function pip(dl:Dynamic,x:Single,y:Single,w:Single,h:Single,shape:Int,amount:Float,vertical:Bool):Void {
		if (amount<=0) return;
		ImGui.ImDrawList_PushClipRect(dl,ImGui.vec2(x,vertical ? y+h*(1-amount) : y),
			ImGui.vec2(vertical ? x+w : x+w*amount,y+h),true);
		var c=ImGui.vec2(x+w*0.5,y+h*0.5);
		var r:Single=Math.max(3,Math.min(w,h)*0.42);
		switch(shape) {
			case PipShapes.CIRCLE: ImGui.ImDrawList_AddCircleFilled(dl,c,r,COLOR,28);
			case PipShapes.RING: ImGui.ImDrawList_AddCircle(dl,c,r,COLOR,28,Math.max(2.8,r*0.34));
			case PipShapes.HEX: ImGui.ImDrawList_AddNgonFilled(dl,c,r,COLOR,6);
			case PipShapes.DIAMOND: ImGui.ImDrawList_AddNgonFilled(dl,c,r,COLOR,4);
			default: ImGui.ImDrawList_AddRectFilled(dl,ImGui.vec2(x,y),ImGui.vec2(x+w,y+h),COLOR,4);
		}
		ImGui.ImDrawList_PopClipRect(dl);
	}
}
