package solarflare.scripting;

import hscript.Expr;
import hscript.Parser;
import solarflare.aura.signal.AuraSignalFrame;
import solarflare.aura.signal.AuraSignalCatalog;
import solarflare.aura.signal.AuraSignalReader;
import solarflare.aura.signal.AuraResolvedValue;
import solarflare.aura.signal.AuraConditionDef;

/** Bounded hscript over frozen signals. Prepare during observation, never drawing. */
class ScriptEngine {
	public static inline var MAX_BYTES=4096;
	public static inline var MAX_NODES=512;
	public static inline var MAX_DEPTH=32;
	public static inline var MAX_STEPS=2048;
	static var programs:Map<String,ScriptProgram>=[];
	static var runtime=new SignalInterp();
	public static function init():Void {}
	public static function clearCache():Void programs.clear();
	public static function retain(codes:Array<String>):Void {
		for(code in programs.keys()) if(codes.indexOf(code)<0) programs.remove(code);
	}
	public static function prepare(code:String):ScriptProgram {
		if(code==null) code="";
		var cached=programs.get(code); if(cached!=null) return cached;
		var p=new ScriptProgram(code);
		programs.set(code,p);
		if(StringTools.trim(code)=="") { p.error="Enter an expression that returns true or false."; return p; }
		if(haxe.io.Bytes.ofString(code).length>MAX_BYTES) { p.error="Expression exceeds 4,096 UTF-8 bytes. Source was preserved."; return p; }
		var parser=new Parser(); parser.allowTypes=true; parser.allowJSON=false; parser.allowMetadata=false;
		var nesting=sourceNesting(code);
		if(nesting>MAX_DEPTH) { p.error="Expression exceeds 32 levels of nesting."; return p; }
		try { p.expr=parser.parseString(code); }
		catch(e:Dynamic) { p.error="Syntax error at line "+parser.line+": "+Std.string(e); return p; }
		try { new ScriptValidator(p).check(p.expr); }
		catch(e:Dynamic) { p.error=Std.string(e); }
		return p;
	}
	/** Bound parser recursion before building an AST, ignoring literals and comments. */
	static function sourceNesting(code:String):Int {
		var depth=0; var maximum=0; var quote=0; var line=false; var block=false; var i=0;
		while(i<code.length) {
			var c=code.charCodeAt(i); var n=i+1<code.length ? code.charCodeAt(i+1) : 0;
			if(line) { if(c==10) line=false; i++; continue; }
			if(block) { if(c==42 && n==47) { block=false; i+=2; } else i++; continue; }
			if(quote!=0) { if(c==92) i+=2; else { if(c==quote) quote=0; i++; } continue; }
			if(c==47 && n==47) { line=true; i+=2; continue; }
			if(c==47 && n==42) { block=true; i+=2; continue; }
			if(c==34 || c==39) quote=c;
			else if(c==40 || c==123 || c==91) { depth++; if(depth>maximum) maximum=depth; }
			else if(c==41 || c==125 || c==93) depth--;
			i++;
		}
		return maximum;
	}
	public static function validate(code:String):Null<String> { var e=prepare(code).error; return e=="" ? null : e; }
	public static function getExpr(code:String):Null<Expr> { var p=prepare(code); return p.error=="" ? p.expr : null; }
	public static function dependencies(code:String):Array<AuraConditionDef> return prepare(code).dependencies;
	public static function evaluate(code:String,frame:AuraSignalFrame):ScriptResult {
		var p=prepare(code); var r=p.result; r.reset();
		if(p.error!="") { r.state="Error"; r.message=p.error; return r; }
		runtime.frame=frame; runtime.steps=0; runtime.eventSerial=0; runtime.clearWaiting();
		try {
			var v:Dynamic=runtime.execute(p.expr);
			// Missing data is recorded, not thrown (HashLink exceptions capture stack traces on a 20 Hz path).
			if(runtime.isWaiting()) { r.state="Waiting for data"; r.message=runtime.waitingMessage(); }
			else {
				if(Std.isOfType(v,Bool)) { r.known=true; r.value=v; }
				else if(Std.isOfType(v,Int) || Std.isOfType(v,Float)) {
					var n:Float=v;
					if(!Math.isFinite(n)) throw "The expression returned a non-finite number.";
					r.known=true; r.value=n>0; r.numeric=true; r.number=n;
				} else throw "Return true or false (or a number for legacy compatibility).";
				r.state=r.value ? "True" : "False";
				if(r.numeric) r.message="Numeric compatibility: values greater than zero are true. Prefer a Boolean result.";
			}
		} catch(e:Dynamic) {
			// A neutral placeholder value may trip a later error; the first missing signal still decides the outcome.
			if(runtime.isWaiting()) { r.known=r.value=r.numeric=false; r.state="Waiting for data"; r.message=runtime.waitingMessage(); }
			else { r.state="Error"; r.message=Std.string(e); }
		}
		r.eventSerial=r.known ? runtime.eventSerial : 0;
		runtime.frame=null; return r;
	}
	public static function evalBool(code:String,frame:AuraSignalFrame=null):Bool { var r=evaluate(code,frame); return r.known && r.value; }
	public static function evalFloat(code:String,frame:AuraSignalFrame=null,def:Float=0):Float {
		var r=evaluate(code,frame); return r.known && r.numeric ? r.number : def;
	}
	public static function variableSignal(name:String):String return switch(name) {
		case "hp","hpRatio": "resource.health.ratio";
		case "hpCur": "resource.health.current";
		case "shield": "resource.shield.ratio";
		case "rage": "resource.rage.ratio";
		case "mana": "resource.mana.ratio";
		case "spark": "resource.spark.ratio";
		case "combo","comboMax": "resource.combo.count";
		case "prayers": "prayer.charged";
		case "prayerLife": "prayer.lifeReady";
		case "prayerShield": "prayer.shieldReady";
		case "prayerSmite": "prayer.smiteReady";
		case "chaincast": "chaincast.stacks";
		case "chaincastReady": "chaincast.ready";
		case "conduit": "conduit.filledCount";
		case "conduitPower": "conduit.powerStacks";
		case "step": "attackCombo.step";
		case "comboWithin": "attackCombo.withinChain";
		case "comboFinal": "attackCombo.finalFlash";
		case "inRift": "encounter.inRift";
		case "damageTaken": "combat.damageTakenRecent";
		default: "";
	}
	public static function helperSignal(name:String):String return switch(name) {
		case "hasSkill","skillReady": "skill.ready";
		case "skillCd": "skill.cooldownLeft";
		case "hasStatus": "status.present";
		case "statusStacks": "status.stacks";
		case "statusDuration": "status.durationLeft";
		default: "";
	}
	public static function mathArity(name:String):Int return switch(name) {
		case "min","max","pow","atan2": 2;
		case "abs","floor","ceil","round","sqrt","sin","cos","tan","asin","acos","atan","exp","log","isFinite","isNaN": 1;
		default: -1;
	}
}

class ScriptProgram {
	public var code:String;
	public var expr:Null<Expr>;
	public var error:String="";
	public var dependencies:Array<AuraConditionDef>=[];
	public var result=new ScriptResult();
	public function new(code:String) this.code=code;
}
class ScriptResult {
	public var eventSerial:Int=0;
	public var known=false;
	public var value=false;
	public var numeric=false;
	public var number:Float=0;
	public var state="Unchecked";
	public var message="";
	public function new() {}
	public function reset():Void { known=value=numeric=false; eventSerial=0; number=0; state="Unchecked"; message=""; }
}
private class ScriptValidator {
	var program:ScriptProgram;
	var nodes=0;
	var locals:Map<String,Bool>=[];
	public function new(p:ScriptProgram) program=p;
	function dependency(signal:String,subject:String=""):Void {
		var d=AuraSignalCatalog.find(signal);
		if(d==null || signal=="custom.script") throw "Unknown or recursive signal: "+signal;
		if(d.subjectKind!="" && subject=="") throw "Signal "+signal+" requires a subject ID.";
		if(d.subjectKind=="" && subject!="") throw "Signal "+signal+" does not take a subject ID.";
		for(c in program.dependencies) if(c.signal==signal && c.subject==subject) return;
		var c=new AuraConditionDef(); c.signal=signal; c.subject=subject; program.dependencies.push(c);
	}
	function literal(e:Expr):String return switch(hscript.Tools.expr(e)) {
		case EConst(CString(s)): s;
		default: throw "Query IDs must be quoted literals. Use Insert signal to choose one.";
	}
	function localTarget(e:Expr):Void switch(hscript.Tools.expr(e)) {
		case EIdent(n): if(!locals.exists(n)) throw "Only local variables may be assigned: "+n;
		default: throw "Only local variables may be assigned.";
	}
	public function check(e:Expr,depth:Int=0):Void {
		if(e==null) return;
		if(++nodes>ScriptEngine.MAX_NODES) throw "Expression exceeds 512 AST nodes.";
		if(depth>ScriptEngine.MAX_DEPTH) throw "Expression exceeds 32 levels of nesting.";
		var next=depth+1;
		switch(hscript.Tools.expr(e)) {
			case EConst(_):
			case EIdent(n):
				if(locals.exists(n) || n=="true" || n=="false" || n=="null") return;
				var signal=ScriptEngine.variableSignal(n);
				if(signal=="") throw "Unknown identifier: "+n;
				dependency(signal);
			case EVar(n,_,v):
				if(ScriptEngine.variableSignal(n)!="" || ScriptEngine.helperSignal(n)!="" || ScriptEngine.mathArity(n)>=0
					|| ["signal","known","Math","true","false","null"].indexOf(n)>=0) throw "Reserved binding: "+n;
				check(v,next); locals.set(n,true);
			case EParent(v),EReturn(v): check(v,next);
			case EBlock(es):
				var before=locals.copy(); for(v in es) check(v,next); locals=before;
			case EBinop(op,a,b):
				if(["=","+=","-=","*=","/=","%="].indexOf(op)>=0) localTarget(a);
				else if(["+","-","*","/","%","==","!=","<",">","<=",">=","&&","||","&","|","^","<<",">>",">>>"].indexOf(op)<0) throw "Unsupported operator: "+op;
				check(a,next); check(b,next);
			case EUnop(op,_,v):
				if(op=="++" || op=="--") localTarget(v);
				else if(["!","-","~"].indexOf(op)<0) throw "Unsupported operator: "+op;
				check(v,next);
			case EIf(c,a,b),ETernary(c,a,b):
				check(c,next); var before=locals.copy(); check(a,next); locals=before.copy(); check(b,next); locals=before;
			case EField(a,name):
				switch(hscript.Tools.expr(a)) { case EIdent("Math") if(["PI"].indexOf(name)>=0): default: throw "Only documented Math members are available."; }
			case ECall(fn,args):
				var name=switch(hscript.Tools.expr(fn)) {
					case EIdent(n): n;
					case EField(a,n): switch(hscript.Tools.expr(a)) { case EIdent("Math"): n; default: throw "Arbitrary member calls are unavailable."; }
					default: throw "Call a documented helper or Math function.";
				};
				var fieldCall=switch(hscript.Tools.expr(fn)) { case EField(_,_): true; default: false; };
				if(!fieldCall && (name=="signal" || name=="known")) {
					if(args.length<1 || args.length>2) throw name+" expects a signal ID and optional subject ID.";
					dependency(literal(args[0]),args.length==2 ? literal(args[1]) : "");
				} else if(!fieldCall && ScriptEngine.helperSignal(name)!="") {
					if(args.length!=1) throw name+" expects one quoted subject ID.";
					dependency(ScriptEngine.helperSignal(name),literal(args[0]));
				} else {
					var arity=ScriptEngine.mathArity(name);
					if(arity<0) throw "Unknown helper: "+name;
					if(args.length!=arity) throw name+" expects "+arity+" argument(s).";
				}
				for(a in args) check(a,next);
			default: throw "Unsupported construct. Use expressions, local variables, return, and if/else; loops and functions are unavailable.";
		}
	}
}

private class SignalInterp extends hscript.Interp {
	public var frame:AuraSignalFrame;
	public var steps=0;
	public var eventSerial=0;
	var value=new AuraResolvedValue();
	/** First missing signal of this evaluation; message built only if the evaluation ends waiting. */
	var waitKind=0;
	var waitSignal="";
	var waitSubject="";
	static var PERCENT_IDS=["hp","shield","rage","mana","spark"];
	public function clearWaiting():Void waitKind=0;
	public function isWaiting():Bool return waitKind!=0;
	public function waitingMessage():String return waitKind==1 ? "No current player snapshot." : "Unavailable: "+waitSignal+(waitSubject=="" ? "" : " ["+waitSubject+"]");
	function waitNoPlayer():Dynamic { if(waitKind==0) waitKind=1; return 0.0; }
	public function new() {
		super(); variables.set("Math",Math);
		variables.set("min",Math.min); variables.set("max",Math.max); variables.set("abs",Math.abs);
		variables.set("floor",Math.floor); variables.set("ceil",Math.ceil); variables.set("round",Math.round);
		variables.set("sqrt",Math.sqrt); variables.set("sin",Math.sin); variables.set("cos",Math.cos);
		variables.set("pow",Math.pow); variables.set("atan2",Math.atan2); variables.set("tan",Math.tan);
		variables.set("asin",Math.asin); variables.set("acos",Math.acos); variables.set("atan",Math.atan);
		variables.set("exp",Math.exp); variables.set("log",Math.log); variables.set("isFinite",Math.isFinite); variables.set("isNaN",Math.isNaN);
	}
	function query(signal:String,subject:String="",knownOnly:Bool=false):Dynamic {
		if(frame==null || !frame.heroKnown) { if(knownOnly) return false; return waitNoPlayer(); }
		AuraSignalReader.read(frame,signal,subject,value);
		if(knownOnly) return value.known;
		if(!value.known) { if(waitKind==0) { waitKind=2; waitSignal=signal; waitSubject=subject; } return 0.0; }
		if(value.eventSerial>eventSerial) eventSerial=value.eventSerial;
		return switch(value.kind) { case Boolean: value.boolValue; case Identity: value.stringValue; default: value.numberValue; };
	}
	override public function expr(e:Expr):Dynamic {
		if(++steps>ScriptEngine.MAX_STEPS) throw "Execution budget exceeded (2,048 steps).";
		switch(hscript.Tools.expr(e)) {
			case EIdent(n):
				var s=ScriptEngine.variableSignal(n);
				if(s!="") {
					var v=query(s);
					if(n=="comboMax") return frame.comboMax;
					if(PERCENT_IDS.indexOf(n)>=0) return v*100.0;
					return v;
				}
			case ECall(fn,args):
				switch(hscript.Tools.expr(fn)) {
					case EIdent(n) if(n=="signal" || n=="known" || ScriptEngine.helperSignal(n)!=""):
						var id:String=expr(args[0]);
						if(n=="signal" || n=="known") return query(id,args.length==2 ? expr(args[1]) : "",n=="known");
						if(n=="hasSkill") {
							if(frame==null || !frame.heroKnown) { waitNoPlayer(); return false; }
							var sk=frame.findSkill(id); return sk!=null && sk.known;
						}
						return query(ScriptEngine.helperSignal(n),id);
					default:
				}
			default:
		}
		var v=super.expr(e);
		if(Std.isOfType(v,String) && (cast v:String).length>MAX_STRING) throw "String value exceeds 4,096 characters.";
		if((Std.isOfType(v,Float) || Std.isOfType(v,Int)) && !Math.isFinite(v)) throw "Non-finite arithmetic result.";
		return v;
	}
	static inline var MAX_STRING=4096;
}
