package solarflare.barter;

/** Selection has no assignment side effects and never auto-advances. */
class BarTerEditingState {
 public var barId:String = "";
 public var cell:Int = 0;
 var selections:Map<String,Int> = new Map();
 public function new() {}
 public function selectBar(id:String,count:Int):Void {
  if (barId.length > 0) selections.set(barId,cell);
  barId=id; var previous=selections.get(id);
  cell=previous == null ? 0 : previous;
  clamp(count);
 }
 public function selectCell(index:Int,count:Int):Void { cell=index; clamp(count); selections.set(barId,cell); }
 public function clamp(count:Int):Void { cell=Std.int(Math.max(0,Math.min(Math.max(0,count-1),cell))); }
}
