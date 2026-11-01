package solarflare.lfg;
import imgui.ImGui;
import solarflare.ui.ByteUtil;
import solarflare.ui.UiChrome;

class LfgText {
    var bytes:hl.Bytes;var capacity:Int;var id:String;var hint:String;
    public var value(default,null)="";
    public function new(id:String,hint:String,capacity:Int=256){this.id=id;this.hint=hint;this.capacity=capacity;bytes=new hl.Bytes(capacity);ByteUtil.clearBytes(bytes,capacity);}
    public function set(s:String):Void {value=s;ByteUtil.fillBuf(bytes,capacity,s);}
    public function draw(width:Single=250):Bool {ImGui.setNextItemWidth(width);if(!ImGui.inputTextWithHint(id,hint,bytes,capacity))return false;value=ByteUtil.readString(bytes,capacity,true);return true;}
}
class LfgChoice {
    var id:String;var options:Array<{value:String,label:String}>=[];
    public var value:String;
    public function new(id:String,values:Array<String>,value:String=""){this.id=id;set(values,value);}
    public function set(values:Array<String>,preferred:String=""):Void {options=[for(v in values){value:v,label:v+"##"+id+"_"+v}];value=values.indexOf(preferred)>=0?preferred:(values.length>0?values[0]:"");}
    public function draw(width:Single=180):Bool {
        var changed=false;ImGui.setNextItemWidth(width);
        if(ImGui.beginCombo(id,value)){for(o in options)if(ImGui.selectable(o.label,o.value==value)){value=o.value;changed=true;}ImGui.endCombo();}return changed;
    }
}
class LfgUi {
    public static function button(label:String,width:Single=130):Bool return UiChrome.ghostButton(label,ImGui.vec2(width,26));
}
