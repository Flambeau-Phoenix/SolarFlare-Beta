package solarflare.barter;

import solarflare.barter.BarTerWeaponLayouts.BarTerNativeSkill;

/** Copy frozen Geaux telemetry even when input identity or binding reads fail. */
class BarTerSkillState {
 public static function apply(snap:BarTerSnap,observed:Bool,gs:Dynamic,native:BarTerNativeSkill):Void {
  snap.available=observed;
  snap.keyLabel=native == null ? "Unknown" : native.keyText;
  snap.nativeActionId=native == null ? "" : native.action;
  snap.bindingKnown=native != null && native.keyKnown;
  if (!observed || gs == null || !gs.present) return;
  snap.ready=gs.ready;
  snap.affordable=gs.affordable != false;
  var proc=gs.procReady == true;
  if (proc && !snap.procReady) snap.procStart=haxe.Timer.stamp();
  snap.procReady=proc;
  snap.cdLeft=gs.cdLeft; snap.remaining=gs.remaining;
  snap.chargesMax=gs.chargesMax > 1 ? gs.chargesMax : 0;
  snap.charges=snap.chargesMax > 1 ? gs.charges : 0; snap.stacks=gs.stacks;
  snap.readyFlashUntil=gs.readyFlashUntil;
  var ammo=snap.chargesMax > 0 && snap.charges > 0;
  snap.onCd=snap.cdLeft > 0.05 || snap.remaining > 0.02 || (!snap.ready && !ammo);
 }
}
