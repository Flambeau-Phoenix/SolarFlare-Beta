package solarflare.extrabars;

typedef ExtraBarsCharacterSettings = { var config:Dynamic; var placement:Dynamic; }

/** Automatic character storage, independent of universal profiles and native objects. */
class ExtraBarsCharacters {
 public var activeId(default,null):String = "";
 var legacyClaimed = false;
 var characters:Map<String,ExtraBarsCharacterSettings> = new Map();
 public function new() {}

 public static function normalizeId(id:String):String {
  if (id == null) return "";
  var value = StringTools.trim(id);
  if (value == "" || value == "0" || value == "null" || value == "undefined" || value.length > 256
      || value.indexOf("\n") >= 0 || value.indexOf("\r") >= 0) return "";
  return value;
 }

 /** Restore only the last active character; the observe step selects the actual hero. */
 public function load(data:Dynamic):ExtraBarsCharacterSettings {
  activeId = ""; legacyClaimed = false; characters.clear();
  if (data == null || Reflect.field(data,"version") != 1) return null;
  legacyClaimed = Reflect.field(data,"legacyClaimed") == true;
  var rows:Dynamic = Reflect.field(data,"characters");
  if (Std.isOfType(rows,Array)) {
   var list:Array<Dynamic> = cast rows;
   for (row in list) {
    if (row == null) continue;
    var raw:Dynamic = Reflect.field(row,"id");
    var id = Std.isOfType(raw,String) ? normalizeId(raw) : "";
    var config = Reflect.field(row,"config");
    if (id.length == 0 || config == null || Std.isOfType(config,Array) || !Reflect.isObject(config)) continue;
    characters.set(id,copy({config:config,placement:Reflect.field(row,"placement")}));
   }
  }
  // Existing rows must never allow the legacy global fallback to leak into a new hero.
  if (characters.iterator().hasNext()) legacyClaimed = true;
  var raw:Dynamic = Reflect.field(data,"activeId");
  var id = Std.isOfType(raw,String) ? normalizeId(raw) : "";
  if (characters.exists(id)) { activeId=id; return copy(characters.get(id)); }
  return null;
 }

 /** Empty identity during loading/logout retains ownership, including pending edits. */
 public function observe(id:String,current:ExtraBarsCharacterSettings):ExtraBarsCharacterSettings {
  id = normalizeId(id);
  if (id.length == 0 || id == activeId) return null;
  if (activeId.length > 0) characters.set(activeId,copy(current));
  var next = characters.get(id);
  if (next == null) next = !legacyClaimed && activeId.length == 0 ? copy(current)
      : {config:new ExtraBarsConfig().dump(),placement:[]};
  activeId=id; legacyClaimed=true; characters.set(id,copy(next));
  return copy(next);
 }

 public function dump(current:ExtraBarsCharacterSettings):Dynamic {
  if (activeId.length > 0) characters.set(activeId,copy(current));
  var ids = [for (id in characters.keys()) id]; ids.sort(Reflect.compare);
  return {version:1,activeId:activeId,legacyClaimed:legacyClaimed,characters:[for (id in ids) {
   var saved=copy(characters.get(id)); {id:id,config:saved.config,placement:saved.placement};
  }]};
 }
 static function copy(value:ExtraBarsCharacterSettings):ExtraBarsCharacterSettings
  return haxe.Json.parse(haxe.Json.stringify(value));
}
