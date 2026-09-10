package solarflare.debug;

@:keep
class ResolutionNote {
	public var key:String = "";
	public var method:String = "";
	public var src:String = "";
	public var step:String = "";
	public var nameWon:String = "";
	public var namesTried:Array<String> = [];
	public var tried:Array<Dynamic> = [];
	public var hook:String = "";
	public var payloadType:String = "";
	public var payloadRole:String = "";
	public var args:Array<String> = [];
	public var kind:String = "";
	public var preview:String = "";

	public function new() {}

	public function withMethod(m:String):ResolutionNote {
		method = m != null ? m : "";
		return this;
	}

	public function withSrc(s:String):ResolutionNote {
		src = s != null ? s : "";
		return this;
	}

	public function withStep(s:String):ResolutionNote {
		step = s != null ? s : "";
		return this;
	}

	public function withName(n:String):ResolutionNote {
		nameWon = n != null ? n : "";
		return this;
	}

	public function withHook(h:String):ResolutionNote {
		hook = h != null ? h : "";
		return this;
	}

	public function withPayload(typeName:String, role:String):ResolutionNote {
		payloadType = typeName != null ? typeName : "";
		payloadRole = role != null ? role : "";
		return this;
	}

	public function withArgs(slots:Array<String>):ResolutionNote {
		if (slots != null)
			args = slots;
		return this;
	}

	public function tryRoute(methodName:String, name:String):ResolutionNote {
		tried.push({method: methodName, name: name});
		if (name != null && name.length > 0)
			namesTried.push(name);
		return this;
	}

	public function num(v:Float):ResolutionNote {
		kind = "number";
		if (Math.isNaN(v) || !Math.isFinite(v))
			preview = "nan";
		else
			preview = Std.string(Math.round(v * 1000) / 1000);
		return this;
	}

	public function bool(v:Bool):ResolutionNote {
		kind = "bool";
		preview = v ? "true" : "false";
		return this;
	}

	public function str(v:String):ResolutionNote {
		kind = "string";
		preview = ResolutionLedger.clip(v, 48);
		return this;
	}

	public function emit():Void {
		ResolutionLedger.commit(this);
	}
}
