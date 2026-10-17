package solarflare.stacks;

/** Frozen presentation values. Unknown is never converted into absence. */
class StackState {
	public var known:Bool=false;
	public var present:Bool=false;
	public var count:Int=0;
	public var label:String="--";
	public function new() {}
	public function set(domainKnown:Bool,present:Bool,stacksKnown:Bool,count:Int):Void {
		var k=domainKnown && (!present || stacksKnown);
		var n=k && present ? Std.int(Math.max(0,count)) : 0;
		if(k!=known || n!=this.count) label=k ? Std.string(n) : "--";
		known=k; this.present=domainKnown && present; this.count=n;
	}
	public function reset():Void set(false,false,false,0);
	public function visible(enabled:Bool,hidden:Bool,hideAtZero:Bool):Bool return enabled && !hidden && !(hideAtZero && known && count==0);
}
