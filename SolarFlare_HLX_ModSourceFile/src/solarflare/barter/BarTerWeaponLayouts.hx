package solarflare.barter;

typedef BarTerNativeSkill = {
 var action:String;
 var id:String;
 var label:String;
 var icon:String;
 var keyText:String;
 var keyKnown:Bool;
}
typedef BarTerPlacement = { var bar:String; var cell:Int; var action:String; var id:String; }

/** Persist primitive action placements; fixed cells remain shared across loadouts. */
class BarTerWeaponLayouts {
 public var layouts:Map<String,Array<BarTerPlacement>> = new Map();
 public function new() {}
 public function capture(key:String,bars:Array<BarTerBarConfig>):Void {
  if (key.length == 0) return;
  var placements:Array<BarTerPlacement>=[];
  for (b in bars) for (i in 0...b.slots.length) if (b.slots[i].hasSkill() && b.slots[i].nativeActionId.length > 0)
   placements.push({bar:b.id,cell:i,action:b.slots[i].nativeActionId,id:b.slots[i].skillId});
  layouts.set(key,placements);
 }
 public function restore(key:String,previous:String,bars:Array<BarTerBarConfig>,source:Array<BarTerNativeSkill>,complete:Bool):Bool {
  if (!complete || key.length == 0 || source.length == 0) return false;
  var template=layouts.get(key); if (template == null) template=layouts.get(previous);
  if (template == null) {
   if (bars.length > 0 && source.length > 0) {
    populate(bars[0],source,bars);
    capture(key,bars);
    return true;
   }
   return false;
  }
  for (b in bars) for (slot in b.slots) if (slot.nativeActionId.length > 0) slot.clearContent();
  for (p in template) {
   var bar:BarTerBarConfig=null; for (b in bars) if (b.id == p.bar) { bar=b; break; }
   if (bar == null || p.cell < 0 || p.cell >= bar.slots.length || bar.slots[p.cell].hasContent()) continue;
   var found=false;
   for (s in source) if (s.action == p.action) { bar.slots[p.cell].assignSkill(s.id); bar.slots[p.cell].nativeActionId=s.action; found=true; break; }
   // Missing actions stay assigned (a partial native read cannot erase placement); BarTerCache hides
   // cells whose action the worn weapon does not have.
   if (!found && p.id.length > 0) { bar.slots[p.cell].assignSkill(p.id); bar.slots[p.cell].nativeActionId=p.action; }
  }
  capture(key,bars); return true;
 }
 public function reserve(bar:String,cell:Int):Void {
  for (key in layouts.keys()) { var rows=layouts.get(key); var i=rows.length-1; while (i >= 0) { if (rows[i].bar == bar && rows[i].cell == cell) rows.splice(i,1); i--; } }
 }
 public static function populate(bar:BarTerBarConfig,source:Array<BarTerNativeSkill>,bars:Array<BarTerBarConfig>):Int {
  if (bar == null) return 0;
  var wrote=0;
  for (s in populationOrder(source)) {
   var exists=false;
   for (b in bars) for (i in 0...b.slotCount) if (b.slots[i].skillId == s.id) exists=true;
   if (exists) continue;
   for (i in 0...bar.slotCount) if (!bar.slots[i].hasContent()) { bar.slots[i].assignSkill(s.id); bar.slots[i].nativeActionId=s.action; wrote++; break; }
  }
  return wrote;
 }
 public static function populationOrder(source:Array<BarTerNativeSkill>):Array<BarTerNativeSkill> {
  var ordered=source.copy();
  function rank(s:BarTerNativeSkill):Int return switch(s.action) {
   case "WeaponSkill1": 0; case "WeaponSkill2": 1; case "WeaponSkill3": 2; case "WeaponSkill4": 3;
   case "Secondary": 5; case "Attack": 6; default: 4;
  };
  ordered.sort(function(a,b) {
   var diff=rank(a)-rank(b); if (diff != 0) return diff;
   var action=Reflect.compare(a.action,b.action); return action != 0 ? action : Reflect.compare(a.id,b.id);
  });
  return ordered;
 }
 /** Explicit replacement preserves consumables, statuses and hidden cells. */
 public static function replaceSkills(bar:BarTerBarConfig,source:Array<BarTerNativeSkill>,bars:Array<BarTerBarConfig>):Int {
  if (bar == null || source.length == 0) return 0;
  for (i in 0...bar.slotCount) if (bar.slots[i].hasSkill()) bar.slots[i].clearContent();
  return populate(bar,source,bars);
 }
 public function dump():Dynamic return [for (key in layouts.keys()) {key:key,placements:[for (p in layouts.get(key)) {bar:p.bar,cell:p.cell,action:p.action,id:p.id}]}];
 public function apply(data:Dynamic):Void {
  layouts.clear();
  if (!Std.isOfType(data,Array)) return;
  var rows:Array<Dynamic>=cast data;
  for (row in rows) {
   if (row == null || !Std.isOfType(row.key,String) || !Std.isOfType(row.placements,Array)) continue;
   var placements:Array<BarTerPlacement>=[]; var saved:Array<Dynamic>=cast row.placements;
   for (p in saved) if (p != null && Std.isOfType(p.bar,String) && Std.isOfType(p.action,String) && Std.isOfType(p.cell,Int) && p.cell >= 0 && p.cell < 64)
    placements.push({bar:p.bar,cell:p.cell,action:p.action,id:Std.isOfType(p.id,String) ? p.id : ""});
   layouts.set(row.key,placements);
  }
 }
}
