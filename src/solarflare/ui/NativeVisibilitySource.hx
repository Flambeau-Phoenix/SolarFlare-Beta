package solarflare.ui;

/** Presentation setters only, invoked during observation. */
interface NativeVisibilitySource {
 function field(node:Dynamic,name:String):Dynamic;
 function childCount(node:Dynamic):Int;
 function childAt(node:Dynamic,index:Int):Dynamic;
 function matches(node:Dynamic,typeName:String):Bool;
 function canHide(node:Dynamic):Bool;
 function visible(node:Dynamic):Bool;
 function setVisible(node:Dynamic,value:Bool):Void;
 function externalChat():Bool;
 function reset():Void;
}
