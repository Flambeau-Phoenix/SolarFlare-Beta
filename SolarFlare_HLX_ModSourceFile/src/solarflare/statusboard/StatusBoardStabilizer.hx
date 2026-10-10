package solarflare.statusboard;

import solarflare.aura.AuraStatusSnap;

/** One presented status: a board-owned copy that keeps its place and appears/lingers deliberately. */
class StatusBoardEntry {
 public var key:String = "";
 public var snap = new AuraStatusSnap();
 public var streak:Int = 0;
 public var missed:Int = 0;
 public var shown:Bool = false;
 public var seen:Bool = false;
 public function new() {}
}

/**
 * Presentation-only stabilizer between AuraStatusCache and the board.
 *
 * The cache rebuilds its rows every pass from lanes (typed lookup, published demand, sliced
 * discovery) that do not agree on order or on how an applied status is deduplicated, so a raw
 * read reorders and can show a second row for a single pass. This keeps first-seen order, merges
 * rows sharing an applied identity within a pass, requires two consecutive passes before a new
 * status appears, and lets a status linger briefly when a pass misses it. It never writes into
 * the cache's rows, so enabling the board cannot change what auras read.
 */
class StatusBoardStabilizer {
 /** Consecutive passes a new status must be seen before it is shown. */
 public static inline var APPEAR_PASSES:Int = 2;
 /** Passes a shown status may be missing before it is dropped (20 Hz passes, about 150 ms). */
 public static inline var GRACE_PASSES:Int = 3;
 public var shown:Array<AuraStatusSnap> = [];
 var entries:Array<StatusBoardEntry> = [];
 var byKey:Map<String,StatusBoardEntry> = new Map();
 var scratch = new AuraStatusSnap();
 public function new() {}
 public function reset():Void { entries.resize(0); byKey.clear(); shown.resize(0); }

 /** `describe` fills label, icon and source item on a board-owned copy, never on the cache row. */
 public function update(source:Array<AuraStatusSnap>, count:Int, describe:AuraStatusSnap->Void, limit:Int):Void {
  for (e in entries) e.seen = false;
  var n = Std.int(Math.min(count, source.length));
  for (i in 0...n) {
   var s = source[i];
   if (s == null || !s.known || !s.present || s.id.length == 0) continue;
   copy(scratch, s);
   describe(scratch);
   var key = scratch.id.toLowerCase() + "|" + scratch.sourceItemId.toLowerCase();
   var e = byKey.get(key);
   if (e == null) {
    if (entries.length >= limit) continue;
    e = new StatusBoardEntry(); e.key = key;
    byKey.set(key, e); entries.push(e);
    copy(e.snap, scratch);
    e.seen = true; e.streak = 1; e.missed = 0;
    continue;
   }
   if (e.seen) {
    // The same applied identity twice in one pass: keep whichever row carries timing.
    if (scratch.durationKnown && !e.snap.durationKnown) copy(e.snap, scratch);
    continue;
   }
   copy(e.snap, scratch);
   e.seen = true; e.streak++; e.missed = 0;
  }
  var k = entries.length;
  while (k-- > 0) {
   var e = entries[k];
   if (e.seen) {
    if (e.streak >= APPEAR_PASSES) e.shown = true;
    continue;
   }
   e.streak = 0; e.missed++;
   if (e.missed >= GRACE_PASSES) { entries.splice(k, 1); byKey.remove(e.key); }
  }
  // Entries are appended in first-seen order and removed in place, so the order is already stable.
  shown.resize(0);
  for (e in entries) if (e.shown) shown.push(e.snap);
 }

 static function copy(dst:AuraStatusSnap, src:AuraStatusSnap):Void {
  dst.id = src.id;
  dst.sourceItemId = src.sourceItemId; dst.sourceItemKnown = src.sourceItemKnown;
  dst.ids.resize(0); dst.idsLower.resize(0);
  for (j in 0...src.ids.length) { dst.ids.push(src.ids[j]); dst.idsLower.push(src.idsLower[j]); }
  dst.stacks = src.stacks; dst.stacksKnown = src.stacksKnown;
  dst.label = src.label; dst.iconKey = src.iconKey;
  dst.known = src.known; dst.present = src.present;
  dst.durationKnown = src.durationKnown;
  dst.progress = src.progress; dst.left = src.left; dst.infinite = src.infinite;
  dst.endsAt = src.endsAt; dst.totalDur = src.totalDur; dst.stampSource = src.stampSource;
 }
}
