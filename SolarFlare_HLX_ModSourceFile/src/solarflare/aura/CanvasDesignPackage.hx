package solarflare.aura;

/** One portable canvas, never a profile, library, set or shared display group. Uses the existing share ZIP format. */
class CanvasDesignPackage {
 static var fields:Array<String>=[
  "id","name","enabled","trigger","skillId","resource","op","pct","duration","region","iconId","invert",
  "requireAfford","dormant","alwaysOn","activationGate","visual","audio","cue","plate","announce","volume",
  "opacity","scale","showIcon","progressRing","showCountdown","useGlobalCountdown","countdownScale","countdownPlace",
  "timerMode","timerSource","timerSeconds","timerStartEdge","timerBoard","timerKeepExpired","showFuse","fuseBottom",
  "followBuffDuration","glowColor","glowStyle","glowStrength","glowOuter","glowInner","textSize","stackCounter",
  "stackScale","stackPlace","counterPlace","counterScale","showLabel","isCounter","bannerText","bannerScale",
  "showBanner","keyText","showKey","effects","w","h","canvasElements","states","rule","gaugeFillMode",
  "referenceWidth","referenceHeight","x","y","lock","transparent"
 ];
 public static function capture(aura:Dynamic):Dynamic {
  if(aura==null || aura.region!="canvas") throw "Select a Freeform Canvas to export.";
  var row:Dynamic={};
  for(field in fields) if(Reflect.hasField(aura,field)) Reflect.setField(row,field,Reflect.field(aura,field));
  // Membership is shared-library UI, not part of this item's design or its own window.
  row.group=""; row.fight="";
  var pack:Dynamic={kind:"solarflare.aura_pack",v:1,id:"canvas-design",name:row.name,auras:[row],groups:[],sets:[]};
  validate(pack);
  return AuraSharePackage.clone(pack);
 }
 public static function validate(pack:Dynamic):Void {
  AuraSharePackage.validatePack(pack);
  var auras:Array<Dynamic>=cast pack.auras;
  var groups:Array<Dynamic>=cast pack.groups;
  var sets:Array<Dynamic>=cast pack.sets;
  if(auras.length!=1 || groups.length!=0 || sets.length!=0 || auras[0].region!="canvas"
   || (auras[0].group!=null && auras[0].group!="") || (auras[0].fight!=null && auras[0].fight!=""))
   throw "Choose a single canvas design ZIP without display groups or sets. Use Aura Import / Export for other packages.";
 }
}
