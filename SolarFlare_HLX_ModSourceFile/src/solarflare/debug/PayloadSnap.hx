package solarflare.debug;

@:keep
class PayloadSnap {
	public var src:String = "";
	public var pack:String = "";
	public var label:String = "";
	public var t:Float = 0;
	public var rows:Array<ProbeRow> = [];

	public function new() {}
}
