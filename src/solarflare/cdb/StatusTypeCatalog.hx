package solarflare.cdb;

/** Separate category identity namespace. Initialized before drawing from the embedded catalog. */
class StatusTypeCatalog {
 public static var entries(default,null):Array<{id:String,name:String}>=[];
 static var indexes=new Map<String,Int>();
 static var ready=false;
 public static function keep():Void {
  if(ready) return;
  AuraCatalog.keep();
  for(e in AuraCatalog.entries) if(e.kind=="statustype") {
   indexes.set(e.id.toLowerCase(),entries.length); entries.push({id:e.id,name:e.name});
  }
  ready=true;
 }
 public static function index(id:String):Int {
  if(id==null) return -1;
  var value=indexes.get(StringTools.trim(id).toLowerCase()); return value==null ? -1 : value;
 }
 public static function canonical(id:String):String { var i=index(id); return i<0 ? "" : entries[i].id; }
 public static function label(id:String):String { var i=index(id); return i<0 ? "" : entries[i].name; }
 public static function bit(id:String):Int { var i=index(id); return i<0 ? 0 : 1<<i; }
 public static function matches(id:String,name:String,query:String):Bool {
  if(AuraCatalog.matchesSearch(id,name,query)) return true;
  var alias=switch(id) { case "Stun": "Stunned"; case "Root": "Rooted"; case "Silence": "Silenced"; case "Slow": "Slowed";
   case "Invisibility": "Invisible"; case "Bleed": "Bleeding"; case "Burn": "Burning"; case "Poison": "Poisoned"; default: ""; };
  return alias.length>0 && AuraCatalog.matchesSearch(id,alias,query);
 }
}
