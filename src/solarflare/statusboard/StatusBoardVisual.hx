package solarflare.statusboard;
import solarflare.aura.AuraStatusSnap;

/** Board-owned, prepared primitive text/IDs. snapshot is a mod copy, never a live engine object. */
class StatusBoardVisual {
 public var snapshot:AuraStatusSnap;
 public var hitId:String;
 public var popupId:String;
 public var timer:String="";
 public var stacks:String="";
 public var label:String="";
 public var faceLabel:String="";
 public var seen:Bool=false;
 var timerToken:Int=-1;
 var timerUnit:Int=-1;
 var stackToken:Int=-1;
 public function new(key:String) { hitId="##sb_status_"+key; popupId="##sb_menu_"+key; }
 public function prepare(s:AuraStatusSnap,now:Float,seconds:Bool,showStacks:Bool):Void {
  snapshot=s; var nextLabel=s.label.length>0 ? s.label : s.id;
  if (label != nextLabel) { label=nextLabel; faceLabel=label.substr(0,4); }
  var left=StatusBoardState.seconds(s,now);
  var unit=s.nativeTimerEligible && seconds && s.durationKnown && !s.infinite && Math.isFinite(left) ? (left>=3600 ? 2 : left>=60 ? 1 : 0) : -1;
  var token=unit<0 ? -1 : Std.int(unit==2 ? Math.floor(left/3600) : unit==1 ? Math.floor(left/60) : Math.ceil(left));
  if (token!=timerToken || unit!=timerUnit) {
   timerToken=token; timerUnit=unit; timer=unit<0 ? "" : token+(unit==2 ? "h" : unit==1 ? "m" : "s");
  }
  var stack=s.nativeStacksVisible && s.stacksKnown && showStacks ? s.stacks : -1;
  if (stack != stackToken) { stackToken=stack; stacks=stack<0 ? "" : Std.string(stack); }
 }
}
