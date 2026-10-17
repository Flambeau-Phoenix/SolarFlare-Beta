package solarflare.stacks;

/** Serializable settings only; no live game objects or renderer state. */
class StackTrackerConfig {
	public var id:String;
	public var name:String = "Stacks";
	public var statusId:String = "";
	public var enabled:Bool = true;
	public var hidden:Bool = false;
	public var capacity:Int = 6;
	public var layout:String = "horizontal";
	public var wrapBy:String = "columns";
	public var wrap:Int = 3;
	public var reverse:Bool = false;
	public var cellSize:Float = 32;
	public var gap:Float = 4;
	public var shape:String = "cell";
	public var iconId:String = "";
	/** Null follows the active theme; explicit overrides are ImGui ABGR colors. */
	public var activeColor:Null<Int> = null;
	public var emptyColor:Null<Int> = null;
	public var showCount:Bool = true;
	public var hideAtZero:Bool = false;
	public function new(id:String) this.id = id;
	public function dump():Dynamic return {id:id,name:name,statusId:statusId,enabled:enabled,hidden:hidden,capacity:capacity,
		layout:layout,wrapBy:wrapBy,wrap:wrap,reverse:reverse,cellSize:cellSize,gap:gap,shape:shape,iconId:iconId,
		activeColor:activeColor,emptyColor:emptyColor,showCount:showCount,hideAtZero:hideAtZero};
	public function apply(d:Dynamic):Void {
		if (d == null) return;
		name = StackConfig.text(d,"name","Stacks").substr(0,96);
		statusId = StringTools.trim(StackConfig.text(d,"statusId","")).substr(0,256);
		enabled = Reflect.field(d,"enabled") != false; hidden = Reflect.field(d,"hidden") == true;
		capacity = Std.int(StackConfig.number(d,"capacity",6,1,128));
		layout = StackConfig.choice(d,"layout","horizontal",StackConfig.layouts);
		wrapBy = StackConfig.choice(d,"wrapBy","columns",StackConfig.axes);
		wrap = Std.int(StackConfig.number(d,"wrap",3,1,128));
		reverse = Reflect.field(d,"reverse") == true;
		cellSize = StackConfig.number(d,"cellSize",32,8,128); gap = StackConfig.number(d,"gap",4,0,32);
		shape = StackConfig.choice(d,"shape","cell",StackConfig.shapes);
		iconId = StackConfig.text(d,"iconId","").substr(0,256);
		activeColor = color(d,"activeColor"); emptyColor = color(d,"emptyColor");
		showCount = Reflect.field(d,"showCount") != false; hideAtZero = Reflect.field(d,"hideAtZero") == true;
	}
	static function color(d:Dynamic,k:String):Null<Int> {
		var n:Dynamic=Reflect.field(d,k); return Std.isOfType(n,Int) ? cast n : null;
	}
}

class StackConfig {
	public static var layouts(default,null):Array<String> = ["horizontal","vertical","grid"];
	public static var axes(default,null):Array<String> = ["columns","rows"];
	public static var shapes(default,null):Array<String> = ["cell","diamond","circle","ring","hexagon","lightning","icon"];
	public var trackers:Array<StackTrackerConfig> = [];
	var nextId:Int = 1;
	public function new() {}
	public function add():StackTrackerConfig {
		while (find("stack"+nextId) != null) nextId++;
		var t=new StackTrackerConfig("stack"+nextId++); trackers.push(t); return t;
	}
	public function find(id:String):StackTrackerConfig { for(t in trackers) if(t.id==id) return t; return null; }
	public function remove(id:String):Bool { var t=find(id); return t!=null && trackers.remove(t); }
	public function duplicate(id:String):StackTrackerConfig {
		var source=find(id); if(source==null) return null;
		var t=add(); var key=t.id; t.apply(source.dump()); t.id=key; t.name=source.name+" (Copy)"; return t;
	}
	public function demandIds():Array<String> {
		var ids:Array<String>=[]; appendDemand(ids); return ids;
	}
	public function appendDemand(ids:Array<String>):Void {
		for(t in trackers) if(t.enabled && t.statusId.length>0 && ids.indexOf(t.statusId)<0) ids.push(t.statusId);
	}
	public function dump():Dynamic return {version:1,nextId:nextId,trackers:[for(t in trackers) t.dump()]};
	public function apply(d:Dynamic):Void {
		trackers=[]; nextId=1; if(d==null) return;
		nextId=Std.int(number(d,"nextId",1,1,1000000));
		var rows:Dynamic=Reflect.field(d,"trackers");
		if(!Std.isOfType(rows,Array)) return;
		var entries:Array<Dynamic>=cast rows;
		for(row in entries) {
			if(row==null || trackers.length>=64) continue;
			var id=text(row,"id","");
			if(id.length==0 || find(id)!=null) { while(find("stack"+nextId)!=null) nextId++; id="stack"+nextId++; }
			var t=new StackTrackerConfig(id); t.apply(row); trackers.push(t);
		}
	}
	public static function number(d:Dynamic,k:String,fallback:Float,low:Float,high:Float):Float {
		var v:Dynamic=Reflect.field(d,k);
		if(!Std.isOfType(v,Int) && !Std.isOfType(v,Float)) return fallback;
		var n:Float=v; return Math.isFinite(n) ? Math.max(low,Math.min(high,n)) : fallback;
	}
	public static function text(d:Dynamic,k:String,fallback:String):String {
		var v=Reflect.field(d,k); return Std.isOfType(v,String) ? v : fallback;
	}
	public static function choice(d:Dynamic,k:String,fallback:String,options:Array<String>):String {
		var v=text(d,k,fallback); return options.indexOf(v)>=0 ? v : fallback;
	}
}
