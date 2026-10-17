package solarflare.stacks;

import imgui.ImGui;
import solarflare.ui.GameIcons;
import solarflare.ui.ThemePalette;
import solarflare.stacks.StackConfig.StackTrackerConfig;

/** Same content renderer for previews and live HUDs; frozen counts only. */
class StackRenderer {
	public static function draw(t:StackTrackerConfig,s:StackState):Void {
		var p=ImGui.getCursorScreenPos(); var dl=ImGui.getWindowDrawList(); var theme=ThemePalette.current();
		var lit=t.activeColor==null ? ImGui.colorConvertFloat4ToU32(theme.accent) : t.activeColor;
		var dim=t.emptyColor==null ? ImGui.colorConvertFloat4ToU32(theme.cellBg) : t.emptyColor;
		var border=ImGui.colorConvertFloat4ToU32(theme.border);
		var tex:hl.I64=t.shape=="icon" ? GameIcons.get(t.iconId.length>0 ? t.iconId : t.statusId) : 0;
		for(i in 0...t.capacity) {
			var x:Single=p.x+StackLayout.column(t,i)*(t.cellSize+t.gap);
			var y:Single=p.y+StackLayout.row(t,i)*(t.cellSize+t.gap);
			var size:Single=t.cellSize; var active=s.known && i<s.count;
			var color:Int=active ? lit : dim;
			if(t.shape=="icon" && tex!=(0:hl.I64)) {
				GameIcons.draw(dl,tex,x,y,size,active ? (t.activeColor==null ? -1 : lit) :
					(t.emptyColor==null ? 0x55FFFFFF : dim));
			} else {
				shape(dl,t.shape,x,y,size,color);
				if(!active) ImGui.ImDrawList_AddRect(dl,ImGui.vec2(x,y),ImGui.vec2(x+size,y+size),border,3,1);
			}
		}
		if(t.showCount) ImGui.ImDrawList_AddText_Vec2(dl,ImGui.vec2(p.x,p.y+StackLayout.height(t)-20),
			ImGui.colorConvertFloat4ToU32(theme.text),s.label);
		ImGui.dummy(ImGui.vec2(StackLayout.width(t),StackLayout.height(t)));
	}
	static function shape(dl:Dynamic,kind:String,x:Single,y:Single,size:Single,color:Int):Void {
		var c=ImGui.vec2(x+size*0.5,y+size*0.5); var r:Single=size*0.44;
		switch(kind) {
			case "circle": ImGui.ImDrawList_AddCircleFilled(dl,c,r,color,28);
			case "ring": ImGui.ImDrawList_AddCircle(dl,c,r,color,28,Math.max(2,size*0.12));
			case "hexagon": ImGui.ImDrawList_AddNgonFilled(dl,c,r,color,6);
			case "diamond": ImGui.ImDrawList_AddNgonFilled(dl,c,r,color,4);
			case "lightning":
				// Two convex halves avoid the concave-path fill limitation.
				ImGui.ImDrawList_AddQuadFilled(dl,ImGui.vec2(x+size*.58,y),ImGui.vec2(x+size*.12,y+size*.58),
					ImGui.vec2(x+size*.52,y+size*.58),ImGui.vec2(x+size*.72,y+size*.30),color);
				ImGui.ImDrawList_AddTriangleFilled(dl,ImGui.vec2(x+size*.38,y+size*.42),
					ImGui.vec2(x+size*.88,y+size*.42),ImGui.vec2(x+size*.30,y+size),color);
			default: ImGui.ImDrawList_AddRectFilled(dl,ImGui.vec2(x,y),ImGui.vec2(x+size,y+size),color,3);
		}
	}
}
