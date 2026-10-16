package solarflare.geaux;

/** Observe-owned edges, independent of transient slot/list snapshots. */
class SkillAttentionState {
 public var flash = new ReadyFlashState();
 public var procReady(default,null):Bool=false;
 public var procStart(default,null):Float=0;
 public function new() {}
 public function observeProc(valid:Bool,signal:Bool,now:Float):Void {
  if (!valid || !signal) { procReady=false; procStart=0; return; }
  if (!procReady) procStart=now;
  procReady=true;
 }
}
