package solarflare.ui;

import imgui.ref.BoolRef;

/** Global options and frozen presentation values; engine references belong to the sampler. */
class WindowAutoHide {
 public static var enabled=new BoolRef(false);
 public static var inventory=new BoolRef(true);
 public static var bankVendor=new BoolRef(true);
 public static var craftUpgrade=new BoolRef(true);
 public static var travel=new BoolRef(true);
 public static var obelisk=new BoolRef(true);
 public static var dialogue=new BoolRef(true);
 public static var map=new BoolRef(true);
 public static var escapeMenu=new BoolRef(true);
 static var sampler=new WindowAutoHideSampler(new WindowAutoHideEngine());
 public static var valid(get,never):Bool;
 static inline function get_valid():Bool return sampler.valid;
 public static var activeCategories(get,never):Int;
 static inline function get_activeCategories():Int return sampler.mask;
 public static var reason(get,never):String;
 static inline function get_reason():String return sampler.reason;
 public static function active():Bool return enabled.get() && sampler.hidden;
 public static function observe(app:Dynamic,now:Float):Void {
  var options=enabled.get() ? (inventory.get()?1:0) | (bankVendor.get()?2:0) | (craftUpgrade.get()?4:0) | (travel.get()?8:0) | (obelisk.get()?16:0)
   | (dialogue.get()?32:0) | (map.get()?64:0) | (escapeMenu.get()?128:0) : -1;
  sampler.observe(app,now,options);
 }
 public static function reset():Void sampler.reset();
 public static function dumpCategories():Dynamic return {
  inventory:inventory.get(),bankVendor:bankVendor.get(),craftUpgrade:craftUpgrade.get(),travel:travel.get(),obelisk:obelisk.get(),
  dialogue:dialogue.get(),map:map.get(),escapeMenu:escapeMenu.get()
 };
 public static function applyCategories(data:Dynamic):Void {
  inventory.set(read(data,"inventory")); bankVendor.set(read(data,"bankVendor"));
  craftUpgrade.set(read(data,"craftUpgrade")); travel.set(read(data,"travel")); obelisk.set(read(data,"obelisk"));
  dialogue.set(read(data,"dialogue")); map.set(read(data,"map")); escapeMenu.set(read(data,"escapeMenu")); reset();
 }
 static function read(data:Dynamic,name:String):Bool {
  var value:Dynamic=data==null ? null : Reflect.field(data,name);
  return Std.isOfType(value,Bool) ? value : true;
 }
}
