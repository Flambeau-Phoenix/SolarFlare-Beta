package solarflare.geaux;

import solarflare.geaux.GeauxBindingPolicy.GeauxBindingLabel;

/** Native discovery runs only during observation; draw reads retained strings by cell index. */
class GeauxBindingLabels {
	static var labels:Array<GeauxBindingLabel>=[];
	static var empty:GeauxBindingLabel={primary:"",secondary:""};
	public static function at(index:Int):GeauxBindingLabel return index>=0 && index<labels.length ? labels[index] : empty;
	public static function observe(c:solarflare.ui.ConfigPanel,now:Float):Void {
		var cfg=c.geaux;
		if(cfg==null || (!cfg.enabled.get() && !c.geauxBuilder.open.get())) { labels.resize(0); return; }
		// Reuse the action observer when BarTer is disabled, including its identity and freshness gates.
		if(!c.barter.config.enabled.get() && !c.barter.config.open.get()) solarflare.barter.BarTerNativeKeys.sample(now);
		var n=cfg.visibleCount();
		while(labels.length<n) labels.push({primary:"",secondary:""});
		labels.resize(n);
		for(i in 0...n) {
			var id=i<cfg.slotIds.length ? cfg.slotIds[i] : "";
			var native=solarflare.barter.BarTerNativeKeys.find(id);
			var key=native!=null && native.fresh==true && native.availability=="present" ? solarflare.barter.BarTerBindingResolver.badgeLabel(native.keyText) : "";
			var custom=i<cfg.slotHotkeys.length ? cfg.slotHotkeys[i] : "";
			GeauxBindingPolicy.select(cfg.style.bindingMode,key,custom,labels[i]);
		}
	}
}
