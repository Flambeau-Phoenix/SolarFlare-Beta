package solarflare.barter;

/** Primitive snapshots only. Drawing captures a snapshot only when an edit occurs. */
class BarTerHistory<T> {
 public var past:Array<T> = [];
 public var future:Array<T> = [];
 public function new() {}
 public function clear():Void { past.resize(0); future.resize(0); }
 public function push(state:T):Void { past.push(state); if (past.length > 40) past.shift(); future.resize(0); }
 public function undo(current:T):Null<T> { if (past.length == 0) return null; future.push(current); return past.pop(); }
 public function redo(current:T):Null<T> { if (future.length == 0) return null; past.push(current); return future.pop(); }
}
