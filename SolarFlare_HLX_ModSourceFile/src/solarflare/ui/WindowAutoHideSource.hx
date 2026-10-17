package solarflare.ui;

/** Only the observation boundary and sampler retain engine references. */
interface WindowAutoHideSource {
 function gui(app:Dynamic):Dynamic;
 function windows(gui:Dynamic):Dynamic;
 function count(list:Dynamic):Int;
 function at(list:Dynamic,index:Int):Dynamic;
 function isOpen(window:Dynamic):Bool;
 function classify(window:Dynamic):Int;
 function travelMode(window:Dynamic):Bool;
 /** True when a DialogBar window is showing an obelisk (not any other NPC or object). */
 function obeliskDialog(window:Dynamic):Bool;
 function reset():Void;
}
