package solarflare.runtime;

/** Primitive-only ordered hook event. Never retains a live engine object. */
class HookEvent {
	public var kind:Int = 0;
	public var id:String = "";
	public var value:Float = 0;
	public var count:Int = 0;
	public var at:Float = 0;
	/** Frozen SolarFlare DTO only; never assign a live engine object. */
	public var payload:Dynamic = null;

	public function new() {}

	public function set(kind:Int, id:String, value:Float, count:Int, at:Float):Void {
		this.kind = kind;
		this.id = id != null ? id : "";
		this.value = value;
		this.count = count;
		this.at = at;
		this.payload = null;
	}

	public function setPayload(kind:Int, payload:Dynamic, at:Float):Void {
		set(kind, "", 0, 0, at);
		this.payload = payload;
	}
}
