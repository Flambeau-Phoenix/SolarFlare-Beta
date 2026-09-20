package solarflare.runtime;

/** Sole hook-to-scheduler ingress: coalesced state edges plus primitive events. */
class HookIngress {
	static var dirty:Int = DirtyDomains.ALL;

	public static function mark(domains:Int):Void {
		if (domains == 0)
			return;
		RuntimeMetrics.hookEdges++;
		if ((dirty & domains) != 0)
			RuntimeMetrics.coalescedEdges++;
		dirty |= domains;
	}

	public static inline function peek(domains:Int):Bool return (dirty & domains) != 0;

	public static function consume(domains:Int):Bool {
		var hit = (dirty & domains) != 0;
		if (hit)
			dirty &= ~domains;
		return hit;
	}

	public static function reset():Void dirty = DirtyDomains.ALL;

	public static function event(kind:Int, id:String, value:Float = 0, count:Int = 0):Bool {
		return EventRing.push(kind, id, value, count, stamp());
	}

	public static function frozenEvent(kind:Int, payload:Dynamic):Bool {
		return EventRing.pushPayload(kind, payload, stamp());
	}

	static function stamp():Float {
		try return haxe.Timer.stamp() catch (_:Dynamic) return Date.now().getTime() / 1000.0;
	}
}
