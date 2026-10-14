package solarflare.barter;

import solarflare.barter.BarTerWeaponLayouts.BarTerNativeSkill;

/** Frozen current native actions for the horizontal picker; no catalog or engine discovery. */
class BarTerNativePickerState {
 public var rows(default,null):Array<BarTerNativeSkill>=[];
 public var signatureIndex(default,null):Int=-1;
 public var caption(default,null):String="Native skills · waiting for observation";
 public var signatureSummary(default,null):String="Signature observation unavailable";
 public var signatureTooltip(default,null):String="";
 var owner:Int=-1;
 var generation:Int=-1;
 public function new() {}
 public function refresh(records:Array<BarTerNativeSkill>,nextOwner:Int,nextGeneration:Int):Void {
  if (owner==nextOwner && generation==nextGeneration) return;
  owner=nextOwner; generation=nextGeneration; rows.resize(0); signatureIndex=-1;
  signatureSummary="Signature observation unavailable"; signatureTooltip="";
  // The fixed action order includes SignatureSkill ninth, even if records arrive out of order.
  for (action in BarTerWeaponLayouts.ACTIONS) for (row in records) {
   if (row.action!=action || row.ownerGeneration!=owner || row.observationGeneration!=generation) continue;
   if (action=="SignatureSkill" && row.availability=="absent") signatureSummary="Signature slot empty";
   if (row.fresh!=true || row.availability!="present" || row.id.length==0) break;
   if (action=="SignatureSkill") {
    signatureIndex=rows.length;
    signatureSummary="Signature: "+(row.label.length>0 ? row.label : row.id);
    signatureTooltip=signatureSummary+"\nBinding: "+row.keyText+"\nClick or drag its icon into the selected cell.";
   }
   rows.push(row); break;
  }
  caption="Native skills · "+rows.length+" available · drag into any cell";
 }
}
