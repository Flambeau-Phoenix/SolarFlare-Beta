package solarflare.stacks;

import solarflare.stacks.StackConfig.StackTrackerConfig;

/** Pure layout math; partial final rows never create extra stack cells. */
class StackLayout {
	public static function columns(t:StackTrackerConfig):Int {
		if(t.layout=="horizontal") return t.capacity;
		if(t.layout=="vertical") return 1;
		return t.wrapBy=="columns" ? Std.int(Math.min(t.capacity,t.wrap)) : Std.int(Math.ceil(t.capacity/t.wrap));
	}
	public static function rows(t:StackTrackerConfig):Int {
		if(t.layout=="vertical") return t.capacity;
		if(t.layout=="horizontal") return 1;
		return t.wrapBy=="rows" ? Std.int(Math.min(t.capacity,t.wrap)) : Std.int(Math.ceil(t.capacity/t.wrap));
	}
	public static function index(t:StackTrackerConfig,i:Int):Int return t.reverse ? t.capacity-1-i : i;
	public static function column(t:StackTrackerConfig,i:Int):Int {
		var n=index(t,i); return t.layout=="grid" && t.wrapBy=="rows" ? Std.int(n/rows(t)) : n%columns(t);
	}
	public static function row(t:StackTrackerConfig,i:Int):Int {
		var n=index(t,i); return t.layout=="grid" && t.wrapBy=="rows" ? n%rows(t) : Std.int(n/columns(t));
	}
	public static function width(t:StackTrackerConfig):Float return columns(t)*(t.cellSize+t.gap)-t.gap;
	public static function height(t:StackTrackerConfig):Float return rows(t)*(t.cellSize+t.gap)-t.gap+(t.showCount ? 22 : 0);
}
