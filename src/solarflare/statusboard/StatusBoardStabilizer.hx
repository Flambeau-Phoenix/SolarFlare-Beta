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
 * Keeps first-seen order and merges only observations of the same primitive application identity.
 * Legacy synthetic rows without an instance id use the timing fallback. Appearance needs two passes;
 * a missing row gets three passes of presentation grace. All retained rows are board-owned copies.
 */
class StatusBoardStabilizer {
 /** Consecutive passes a new status must be seen before it is shown. */
 public static inline var APPEAR_PASSES:Int = 2;
 /** Passes a shown status may be missing before it is dropped (20 Hz passes, about 150 ms). */
 public static inline var GRACE_PASSES:Int = 3;
 public var shown:Array<AuraStatusSnap> = [];
 var entries:Array<StatusBoardEntry> = [];
 /** Entries per `id|sourceItem` key: distinct statuses can share one (generic ids such as `ItemStatus`). */
 var byKey:Map<String,Array<StatusBoardEntry>> = new Map();
 var scratch = new AuraStatusSnap();
 var ownerGeneration:Int = -1;
 public function new() {}
 public function reset():Void { entries.resize(0); byKey.clear(); shown.resize(0); }
 public function syncOwner(generation:Int):Bool {
  if (generation == ownerGeneration) return false;
  reset(); ownerGeneration=generation; return true;
 }

 /** `describe` fills label, icon and source item on a board-owned copy, never on the cache row. */
 public function update(source:Array<AuraStatusSnap>, count:Int, describe:AuraStatusSnap->Void, limit:Int):Void {
  for (e in entries) e.seen = false;
  var now = haxe.Timer.stamp();
  var n = Std.int(Math.min(count, source.length));
  for (i in 0...n) {
   var s = source[i];
   if (s == null || !s.known || !s.present || s.id.length == 0) continue;
   copy(scratch, s);
   describe(scratch);
   var key = scratch.instanceId.length > 0 ? scratch.instanceId : scratch.id.toLowerCase() + "|" + scratch.sourceItemId.toLowerCase();
   var list = byKey.get(key);
   var match:StatusBoardEntry = null;
   var dup:StatusBoardEntry = null;
   if (list != null) for (c in list) {
    if (!sameStatus(c.snap, scratch, now)) continue;
    if (!c.seen) { match = c; break; }
    dup = c;
   }
   if (match == null) {
    if (dup != null) {
     // The same applied status twice in one pass (two cache lanes): keep whichever row carries timing.
     if (scratch.durationKnown && !dup.snap.durationKnown) copy(dup.snap, scratch);
     continue;
    }
    if (entries.length >= limit) continue;
    var e = new StatusBoardEntry(); e.key = key;
    if (list == null) { list = []; byKey.set(key, list); }
    list.push(e); entries.push(e);
    copy(e.snap, scratch);
    e.seen = true; e.streak = 1; e.missed = 0;
    continue;
   }
   copy(match.snap, scratch);
   match.seen = true; match.streak++; match.missed = 0;
  }
  var k = entries.length;
  while (k-- > 0) {
   var e = entries[k];
   if (e.seen) {
    if (e.streak >= APPEAR_PASSES) e.shown = true;
    continue;
   }
   e.streak = 0; e.missed++;
   if (e.missed >= GRACE_PASSES) {
    entries.splice(k, 1);
    var l = byKey.get(e.key);
    if (l != null) { l.remove(e); if (l.length == 0) byKey.remove(e.key); }
   }
  }
  // Entries are appended in first-seen order and removed in place, so the order is already stable.
  shown.resize(0);
  for (e in entries) if (e.shown) shown.push(e.snap);
 }

 /**
  * Two rows with one `id|source` key are the same applied status only if their timing agrees. A generic id such as
  * `ItemStatus` is shared by several equipped-item buffs that differ by remaining time (or by being permanent);
  * rows without timing on either side keep the old behaviour and merge.
  */
 static function sameStatus(a:AuraStatusSnap, b:AuraStatusSnap, now:Float):Bool {
  if (a.instanceId.length > 0 || b.instanceId.length > 0) return a.instanceId.length > 0 && a.instanceId == b.instanceId;
  if (!a.durationKnown || !b.durationKnown) return true;
  if (a.infinite != b.infinite) return false;
  if (a.infinite) return true;
  var la = StatusBoardState.seconds(a, now);
  var lb = StatusBoardState.seconds(b, now);
  if (!Math.isFinite(la) || !Math.isFinite(lb)) return true;
  return Math.abs(la - lb) <= 0.75;
 }

 static function copy(dst:AuraStatusSnap, src:AuraStatusSnap):Void {
  dst.instanceId = src.instanceId;
  dst.id = src.id;
  dst.sourceItemId = src.sourceItemId; dst.sourceItemKnown = src.sourceItemKnown;
  dst.ids.resize(0); dst.idsLower.resize(0);
  for (j in 0...src.ids.length) { dst.ids.push(src.ids[j]); dst.idsLower.push(src.idsLower[j]); }
  dst.nativeTimerEligible=src.nativeTimerEligible; dst.nativeStacksVisible=src.nativeStacksVisible;
  dst.nativeProgressVisible=src.nativeProgressVisible;
  dst.stacks = src.stacks; dst.stacksKnown = src.stacksKnown;
  dst.label = src.label; dst.iconKey = src.iconKey;
  dst.known = src.known; dst.present = src.present;
  dst.durationKnown = src.durationKnown;
  dst.progress = src.progress; dst.left = src.left; dst.infinite = src.infinite;
  dst.endsAt = src.endsAt; dst.totalDur = src.totalDur; dst.stampSource = src.stampSource;
 }
}
