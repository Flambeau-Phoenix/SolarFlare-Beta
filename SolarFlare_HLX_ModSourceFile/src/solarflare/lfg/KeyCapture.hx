package solarflare.lfg;

import imgui.ImGui;
import imgui.Enums.ImGuiKey;

/** Renderer-side half of the panel key: polling the bound chord and capturing a new one. */
class KeyCapture {
    /** While true the panel toggle is suspended, so the key being chosen cannot also close the window. */
    public static var listening(default,null):Bool=false;
    public static var resultName(default,null):String="";
    public static var resultMods(default,null):Int=0;
    /** Set for the frame in which a chord was captured, so that same key press cannot also toggle the panel. */
    public static var finished:Bool=false;
    public static function mods():Int {
        return (ImGui.isKeyDown(ImGuiKey.LeftCtrl)||ImGui.isKeyDown(ImGuiKey.RightCtrl)?KeyBinding.CTRL:0)
            |(ImGui.isKeyDown(ImGuiKey.LeftShift)||ImGui.isKeyDown(ImGuiKey.RightShift)?KeyBinding.SHIFT:0)
            |(ImGui.isKeyDown(ImGuiKey.LeftAlt)||ImGui.isKeyDown(ImGuiKey.RightAlt)?KeyBinding.ALT:0);
    }
    /** Exact chord match; keys that double as typing need a modifier and are ignored while a field is active. */
    public static function pressed(name:String,modifiers:Int):Bool {
        var code=KeyBinding.code(name);if(code==0||!ImGui.isKeyPressed(code,false))return false;
        if((KeyBinding.needsModifier(name)||StringTools.startsWith(name,"Keypad"))&&ImGui.isAnyItemActive())return false;
        return mods()==modifiers;
    }
    public static function begin():Void {listening=true;resultName="";resultMods=0;}
    public static function cancel():Void listening=false;
    /** Call every frame while listening. True once a valid chord was pressed (read resultName / resultMods). */
    public static function poll():Bool {
        if(!listening)return false;
        if(ImGui.isKeyPressed(ImGuiKey.Escape,false)){listening=false;return false;}
        var m=mods();var names=KeyBinding.all();
        for(i in 0...names.length)if(ImGui.isKeyPressed(KeyBinding.codes[i],false)&&KeyBinding.valid(names[i],m)){
            resultName=names[i];resultMods=m;listening=false;finished=true;return true;
        }
        return false;
    }
    /** The id table is Dear ImGui's named-key order; verify it against the binding once before trusting it. */
    public static function tableMatchesBinding():Bool {
        return KeyBinding.code("F1")==ImGuiKey.F1&&KeyBinding.code("F12")==ImGuiKey.F12&&KeyBinding.code("Insert")==ImGuiKey.Insert
            &&KeyBinding.code("PageDown")==ImGuiKey.PageDown&&KeyBinding.code("Pause")==ImGuiKey.Pause&&KeyBinding.code("Keypad0")==ImGuiKey.Keypad0
            &&KeyBinding.code("KeypadAdd")==ImGuiKey.KeypadAdd&&KeyBinding.code("GraveAccent")==ImGuiKey.GraveAccent&&KeyBinding.code("A")==ImGuiKey.A
            &&KeyBinding.code("Z")==ImGuiKey.Z&&KeyBinding.code("0")==ImGuiKey._0&&KeyBinding.code("9")==ImGuiKey._9&&KeyBinding.code("ScrollLock")==ImGuiKey.ScrollLock;
    }
}
