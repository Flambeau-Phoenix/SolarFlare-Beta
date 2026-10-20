package solarflare;

/** Immutable, primitive capability publication. Amounts and tracker visibility never decide eligibility. */
class ResourceCapabilities {
 public static var current(default,null)=new ResourceCapabilities("","",false);
 public var heroId(default,null):String;
 public var kind(default,null):String;
 public var known(default,null):Bool;
 public var rage(default,null):Bool;
 public var mana(default,null):Bool;
 public var spark(default,null):Bool;
 public var prayers(default,null):Bool;
 public var combo(default,null):Bool;
 public var chaincast(default,null):Bool;
 public var conduits(default,null):Bool;
 public function new(heroId:String,kind:String,chaincast:Bool) {
  this.heroId=heroId; this.kind=kind;
  known=heroId!="" && ["Warrior","Mage","Priest","Rogue"].indexOf(kind)>=0;
  rage=known && kind=="Warrior"; spark=known && kind=="Mage";
  // Mana is the legacy name of the Mage's generic specialEnergy resource.
  mana=spark; prayers=known && kind=="Priest"; combo=known && kind=="Rogue";
  conduits=spark; this.chaincast=spark && chaincast;
 }
 public static function publish(heroId:String,kind:String,chaincast:Bool):Void {
  var old=current;
  if(old.heroId!=heroId || old.kind!=kind || old.chaincast!=chaincast) { current=new ResourceCapabilities(heroId,kind,chaincast); solarflare.ui.ProfileTrace.note("capability","hero="+heroId+" kind="+kind+" known="+current.known+" rage="+current.rage+" spark="+current.spark+" prayers="+current.prayers+" combo="+current.combo+" chaincast="+current.chaincast); }
 }
 public static function reset():Void current=new ResourceCapabilities("","",false);
}
