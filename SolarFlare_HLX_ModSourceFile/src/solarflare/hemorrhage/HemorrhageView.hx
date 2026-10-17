package solarflare.hemorrhage;

/** Formatted only during observation, never by the ImGui renderer. */
class HemorrhageView {
	public var title:String;
	public var quality:String;
	public var rows:Array<{label:String,value:String,raw:Float,ratio:Bool}> = [];
	public var abilities:Array<{id:String,label:String,hits:String,damage:String,bleed:String}> = [];
	public function new(r:HemorrhageRun) {
		title = (r.build == "" ? "Unnamed test" : r.build) + " — " + (r.state:String);
		quality = r.quality();
		var m = r.metrics;
		add("Elapsed (including tail)",r.elapsed,decimal(r.elapsed)+" s");
		add("Attack window",r.attackSeconds,decimal(r.attackSeconds)+" s");
		add("Bleed tail",r.tailSeconds,decimal(r.tailSeconds)+" s");
		add("Character crit at start",r.chanceStart,percent(r.chanceStart),true);
		add("Character crit range",Math.NaN,percent(r.chanceMin)+" – "+percent(r.chanceMax));
		add("Crit rating at start",r.ratingStart,number(r.ratingStart));
		add("Crit rating range",Math.NaN,number(r.ratingMin)+" – "+number(r.ratingMax));
		add("Hero damage (no summons)",m.damage,number(m.damage));
		add("Hero DPS",r.dps(),number(r.dps()));
		add("Physical Hemorrhage",m.physicalBleed,number(m.physicalBleed));
		add("Spark Hemorrhage",m.sparkBleed,number(m.sparkBleed));
		add("Combined bleed damage",m.bleed(),number(m.bleed()));
		add("Combined bleed DPS",r.bleedDps(),number(r.bleedDps()));
		var share = m.damage>0 ? m.bleed()/m.damage : Math.NaN;
		add("Bleed share of hero damage",share,percent(share),true);
		add("Direct physical hits",m.physicalHits,Std.string(m.physicalHits));
		add("Direct physical crits",m.physicalCrits,Std.string(m.physicalCrits));
		var physical = m.physicalHits>0 ? m.physicalCrits/m.physicalHits : Math.NaN;
		add("Observed physical crit frequency",physical,percent(physical),true);
		add("Direct magic hits",m.magicHits,Std.string(m.magicHits));
		add("Direct magic crits",m.magicCrits,Std.string(m.magicCrits));
		var magic = m.magicHits>0 ? m.magicCrits/m.magicHits : Math.NaN;
		add("Observed magic crit frequency",magic,percent(magic),true);
		add("Direct critical-hit damage",m.criticalDamage,number(m.criticalDamage));
		add("Bleed ticks",m.bleedTicks,Std.string(m.bleedTicks));
		add("Critical bleed ticks",m.bleedCrits,Std.string(m.bleedCrits));
		add("Unclassified damage events",m.unknown,Std.string(m.unknown));
		add("Shared events dropped",r.dropped,Std.string(r.dropped));
		for(a in r.abilities) abilities.push({id:a.id,label:a.label,hits:Std.string(a.metrics.events),damage:number(a.metrics.damage),bleed:number(a.metrics.bleed())});
	}
	function add(label:String,raw:Float,value:String,ratio:Bool=false):Void rows.push({label:label,value:value,raw:raw,ratio:ratio});
	public static function number(v:Float):String return HemorrhageCache.number(v);
	public static function decimal(v:Float):String return Math.isFinite(v) ? Std.string(Math.fround(v*10)/10) : "—";
	public static function percent(v:Float):String return Math.isFinite(v) ? decimal(v*100)+"%" : "—";
	public static function delta(a:Float,b:Float,percent:Bool=false):String {
		if(!Math.isFinite(a) || !Math.isFinite(b) || (percent && a==0)) return "—";
		var d = percent ? (b-a)/Math.abs(a)*100 : b-a;
		return (d>0 ? "+" : "") + decimal(d) + (percent ? "%" : "");
	}
}
