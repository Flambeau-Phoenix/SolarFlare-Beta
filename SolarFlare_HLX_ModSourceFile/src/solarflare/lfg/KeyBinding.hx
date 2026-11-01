package solarflare.lfg;

/**
 * Panel key vocabulary: names stay stable in saved settings; codes are Dear ImGui's named-key
 * ids. Pure data and validation, so configuration and tests need no renderer.
 * Letters, digits and the grave key would swallow typing, so they require a modifier.
 */
class KeyBinding {
    public static inline var CTRL=1;
    public static inline var SHIFT=2;
    public static inline var ALT=4;
    public static inline var DEFAULT_NAME="F5";
    public static var names(default,null):Array<String>=[];
    public static var codes(default,null):Array<Int>=[];
    /** Names that are only valid together with at least one modifier. */
    static var guarded:Map<String,Bool>=[];
    static var ready=false;
    static function add(name:String,code:Int,needsModifier:Bool=false):Void {names.push(name);codes.push(code);if(needsModifier)guarded.set(name,true);}
    static function init():Void {
        if(ready)return;ready=true;
        for(i in 0...12)add("F"+(i+1),572+i);
        add("Insert",521);add("Home",519);add("End",520);add("PageUp",517);add("PageDown",518);
        add("Pause",611);add("ScrollLock",608);
        for(i in 0...10)add("Keypad"+i,612+i);
        add("KeypadDecimal",622);add("KeypadDivide",623);add("KeypadMultiply",624);add("KeypadSubtract",625);add("KeypadAdd",626);
        add("GraveAccent",606,true);
        for(i in 0...26)add(String.fromCharCode(65+i),546+i,true);
        for(i in 0...10)add(""+i,536+i,true);
    }
    public static function all():Array<String> {init();return names;}
    public static function indexOf(name:String):Int {init();return names.indexOf(name);}
    public static function code(name:String):Int {var i=indexOf(name);return i<0?0:codes[i];}
    public static function needsModifier(name:String):Bool {init();return guarded.exists(name);}
    public static function valid(name:String,mods:Int):Bool {
        if(name==null||mods<0||mods>7||indexOf(name)<0)return false;
        return !needsModifier(name)||mods!=0;
    }
    /** Returns the saved pair when valid, otherwise F5 with no modifiers. */
    public static function clean(name:String,mods:Int):{name:String,mods:Int} return valid(name,mods)?{name:name,mods:mods}:{name:DEFAULT_NAME,mods:0};
    public static function label(name:String,mods:Int):String {
        var text=(mods&CTRL!=0?"Ctrl+":"")+(mods&SHIFT!=0?"Shift+":"")+(mods&ALT!=0?"Alt+":"");
        return text+(StringTools.startsWith(name,"Keypad")?"Numpad "+name.substr(6):name);
    }
    /** Keys owned by other mods we know about; shown as a warning, never a block. */
    public static function knownOwner(name:String,mods:Int):String {
        if(mods!=0)return "";
        return switch(name){
            case "F6":"The companion overlay hub";
            case "F12":"The companion overlay debug panel";
            case "Keypad0":"The companion overlay hide-all key";
            default:"";
        }
    }
}
