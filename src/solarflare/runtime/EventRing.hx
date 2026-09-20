package solarflare.runtime;

/** Fixed-capacity ordered mailbox for non-coalescible primitive events. */
class EventRing {
	public static inline var CAPACITY:Int = 512;
	static var rows:Array<HookEvent> = [];
	static var readAt:Int = 0;
	static var writeAt:Int = 0;
	static var used:Int = 0;

	public static function init():Void {
		if (rows.length == CAPACITY)
			return;
		rows = [];
		for (_ in 0...CAPACITY)
			rows.push(new HookEvent());
		readAt = writeAt = used = 0;
	}

	public static inline function depth():Int return used;

	public static function reset():Void {
		init();
		readAt = writeAt = used = 0;
		for (row in rows)
			row.set(0, "", 0, 0, 0);
	}

	public static function push(kind:Int, id:String, value:Float, count:Int, at:Float):Bool {
		init();
		if (used >= CAPACITY) {
			RuntimeMetrics.eventDropped++;
			return false;
		}
		rows[writeAt].set(kind, id, value, count, at);
		writeAt = (writeAt + 1) % CAPACITY;
		used++;
		RuntimeMetrics.eventQueued++;
		if (used > RuntimeMetrics.maxQueueDepth)
			RuntimeMetrics.maxQueueDepth = used;
		return true;
	}

	public static function pushPayload(kind:Int, payload:Dynamic, at:Float):Bool {
		init();
		if (used >= CAPACITY) {
			RuntimeMetrics.eventDropped++;
			return false;
		}
		rows[writeAt].setPayload(kind, payload, at);
		writeAt = (writeAt + 1) % CAPACITY;
		used++;
		RuntimeMetrics.eventQueued++;
		if (used > RuntimeMetrics.maxQueueDepth)
			RuntimeMetrics.maxQueueDepth = used;
		return true;
	}

	/** Callback must consume synchronously; the row is reused after return. */
	public static function drain(consume:HookEvent->Void, budget:Int = CAPACITY):Int {
		if (consume == null || used <= 0 || budget <= 0)
			return 0;
		var n = 0;
		while (used > 0 && n < budget) {
			var row = rows[readAt];
			try consume(row) catch (_:Dynamic) {}
			row.set(0, "", 0, 0, 0);
			readAt = (readAt + 1) % CAPACITY;
			used--;
			n++;
		}
		RuntimeMetrics.eventDrained += n;
		return n;
	}
}
