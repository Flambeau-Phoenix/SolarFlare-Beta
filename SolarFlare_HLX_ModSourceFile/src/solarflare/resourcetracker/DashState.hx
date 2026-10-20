package solarflare.resourcetracker;

/** Primitive, reusable observation. A ready charge may coexist with an active recharge. */
class DashState {
	public var known:Bool = false;
	public var id:String = "";
	public var charges:Int = 0;
	public var max:Int = 0;
	public var left:Float = Math.NaN;
	public var total:Float = Math.NaN;
	public var remaining:Float = 0;
	public var countLabel:String = "?";
	public var timeLabel:String = "No data";
	public function new() {}
	public function clear():Void {
		known=false; id=""; charges=max=0; left=total=Math.NaN; remaining=0;
		countLabel="?"; timeLabel="No data";
	}
	public function update(id:String, n:Int, capacity:Int, seconds:Float, duration:Float):Void {
		if(capacity<1 || n<0 || !Math.isFinite(seconds)) { clear(); return; }
		this.id=id; known=true; max=capacity; charges=Std.int(Math.min(n,capacity));
		left=charges>=max ? 0 : Math.max(0,seconds);
		total=Math.isFinite(duration) && duration>0 ? duration : Math.NaN;
		remaining=left>0 && Math.isFinite(total) ? Math.max(0,Math.min(1,left/total)) : 0;
		countLabel=charges+" / "+max;
		timeLabel=left>0 ? (left<10 ? Std.string(Math.ceil(left*10)/10) : Std.string(Math.ceil(left)))+"s" : charges>=max ? "Full" : "Recharging";
	}
}
