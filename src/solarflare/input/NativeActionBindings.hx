package solarflare.input;

typedef NativeBindingSnap = {
 var actionId:String;
 var state:String;
 var text:String;
 var known:Bool;
}

/** Shared observe-only action labels. Never registers input or retains native binding arrays. */
class NativeActionBindings {
 public static inline var INTERVAL_S:Float = 0.5;
 static var owner:Dynamic;
 static var rows:Map<String,NativeBindingSnap> = new Map();
 static var readAt:Map<String,Float> = new Map();
 static var names:Map<Int,String> = new Map();
 static var namesReady:Bool = false;
 public static function reset():Void { owner=null; rows.clear(); readAt.clear(); }
 public static function read(action:String, hero:Dynamic, now:Float, force:Bool=false):NativeBindingSnap {
  if (hero != owner) { reset(); owner=hero; }
  if (hero == null || action == null || action.length == 0) return unknown(action);
  var at=readAt.get(action);
  if (!force && at != null && now-at < INTERVAL_S) return rows.get(action);
  initializeNames();
  var row=sample(action); rows.set(action,row); readAt.set(action,now); return row;
 }
 static function unknown(action:String):NativeBindingSnap return {actionId:action == null ? "" : action,state:"unreadable",text:"Unknown",known:false};
 static function initializeNames():Void {
  if (namesReady) return;
  try {
   var type=HlxRuntime.resolveType("hxd.Key");
   if (type == null) return;
   function add(name:String,label:String):Void {
    var code:Null<Int>=HlxRuntime.resolveStaticField(type,name);
    if (code != null) names.set(code,label);
   }
   for (i in 0...26) { var letter=String.fromCharCode(65+i); add(letter,letter); }
   for (i in 0...10) { add("NUMBER_"+i,Std.string(i)); add("NUMPAD_"+i,"Num"+i); }
   for (i in 1...25) add("F"+i,"F"+i);
   for (e in [{name:"MOUSE_LEFT",label:"LMB"},{name:"MOUSE_RIGHT",label:"RMB"},
    {name:"MOUSE_MIDDLE",label:"MMB"},{name:"MOUSE_BACK",label:"Mouse4"},{name:"MOUSE_FORWARD",label:"Mouse5"},
    {name:"SPACE",label:"Space"},{name:"TAB",label:"Tab"},{name:"ENTER",label:"Enter"},{name:"ESCAPE",label:"Esc"},
    {name:"CTRL",label:"Ctrl"},{name:"SHIFT",label:"Shift"},{name:"ALT",label:"Alt"},
    {name:"LEFT",label:"Left"},{name:"RIGHT",label:"Right"},{name:"UP",label:"Up"},{name:"DOWN",label:"Down"},
    {name:"DELETE",label:"Del"},{name:"INSERT",label:"Ins"},{name:"HOME",label:"Home"},{name:"END",label:"End"},
    {name:"PGUP",label:"PgUp"},{name:"PGDOWN",label:"PgDn"},{name:"BACKSPACE",label:"Bksp"},
    {name:"QWERTY_QUOTE",label:"'"},{name:"QWERTY_COMMA",label:","},{name:"QWERTY_MINUS",label:"-"},
    {name:"QWERTY_PERIOD",label:"."},{name:"QWERTY_SLASH",label:"/"},{name:"QWERTY_SEMICOLON",label:";"},
    {name:"QWERTY_EQUALS",label:"="},{name:"QWERTY_BRACKET_LEFT",label:"["},{name:"QWERTY_BRACKET_RIGHT",label:"]"},
    {name:"QWERTY_BACKSLASH",label:"\\"},{name:"QWERTY_TILDE",label:"`"}]) add(e.name,e.label);
   namesReady=true;
  } catch (_:Dynamic) {}
 }
 static function sample(action:String):NativeBindingSnap {
  try {
   var bindings=lib.Input.getBindings(action);
   if (bindings == null || bindings.length < 0 || bindings.length > 32) return unknown(action);
   var unreadable=false;
   // getBindings returns shared scratch storage; fully consume it before any next action read.
   for (i in 0...bindings.length) {
    var raw=bindings.getDyn(i);
    if (raw == null) { unreadable=true; continue; }
    var code:Null<Int>=HlxRuntime.resolveField(raw,"code");
    if (code == null) continue; // controller-only or explicitly cleared
    var label="";
    try label=solarflare.EngineText.cleanId(lib.Input.getKeyName(code)) catch (_:Dynamic) {}
    if (label.length == 0 || label == "?") label=names.exists(code) ? names.get(code) : "";
    if (label.length == 0 || label == "?") { unreadable=true; continue; }
    return {actionId:action,state:"bound",text:compact(label),known:true};
   }
   return unreadable ? unknown(action) : {actionId:action,state:"unbound",text:"Unbound",known:true};
  } catch (_:Dynamic) { return unknown(action); }
 }
 public static function compact(label:String):String {
  for (pair in [{long:"Mouse Left",short:"LMB"},{long:"Mouse Right",short:"RMB"},
   {long:"Mouse Middle",short:"MMB"},{long:"Mouse Back",short:"Mouse4"},{long:"Mouse Forward",short:"Mouse5"}])
   label=StringTools.replace(label,pair.long,pair.short);
  return label;
 }
}
