package solarflare.util;

import json2object.JsonParser;
import json2object.Error;

/** Nested effect row — mirrors AuraEffect.toObj. */
typedef AuraEffectImportModel = {
	@:optional var id:String;
	@:optional var kind:String;
	@:optional var when:String;
	@:optional var enabled:Bool;
	@:optional var hold:Float;
	@:optional var fadeIn:Float;
	@:optional var fadeOut:Float;
	@:optional var text:String;
	@:optional var cue:String;
	@:optional var glow:Bool;
	@:optional var alpha:Float;
}

/** Nested condition — mirrors AuraRuleCodec.toObj condition rows. */
typedef AuraConditionImportModel = {
	@:optional var signal:String;
	@:optional var subject:String;
	@:optional var subjectLabel:String;
	@:optional var op:String;
	@:optional var numberValue:Float;
	@:optional var boolValue:Bool;
	@:optional var stringValue:String;
	@:optional var negate:Bool;
}

/** Nested rule — mirrors AuraRuleCodec.toObj. */
typedef AuraRuleImportModel = {
	@:optional var version:Int;
	@:optional var mode:String;
	@:optional var presentationSource:Int;
	@:optional var conditions:Array<AuraConditionImportModel>;
	@:optional var negate:Bool;
	@:optional var nodes:Array<AuraRuleNodeImportModel>;
}

typedef AuraRuleNodeImportModel = {
	var kind:String;
	@:optional var conditionIndex:Int;
	@:optional var mode:String;
	@:optional var negate:Bool;
	@:optional var nodes:Array<AuraRuleNodeImportModel>;
}

/** Per-state replacement values for one canvas element. */
typedef AuraElementOverrideImportModel = {
	@:optional var x:Float;
	@:optional var y:Float;
	@:optional var w:Float;
	@:optional var h:Float;
	@:optional var color:Int;
	@:optional var opacity:Float;
	@:optional var rotation:Float;
	@:optional var hidden:Bool;
}

/** Named canvas look and the rule that selects it. */
typedef AuraStateImportModel = {
	@:optional var id:String;
	@:optional var name:String;
	@:optional var group:String;
	@:optional var rule:AuraRuleImportModel;
}

/** Vector path layer: nodes as [x, y] or [x, y, inX, inY, outX, outY]. */
typedef AuraPathImportModel = {
	@:optional var n:Array<Array<Float>>;
	@:optional var c:Bool;
}

/** Layer edge outline: width, colour, side, cooldown wipe mode, direction, drain. */
typedef AuraEdgeImportModel = {
	@:optional var w:Float;
	@:optional var c:Int;
	@:optional var s:Int;
	@:optional var m:Int;
	@:optional var d:Int;
	@:optional var h:Bool;
}

/** Nested canvas element — mirrors AuraCanvasElement.toObj. */
typedef AuraCanvasImportModel = {
	@:optional var visibilityRule:AuraRuleImportModel;
	@:optional var kind:String;
	@:optional var content:String;
	@:optional var x:Float;
	@:optional var y:Float;
	@:optional var w:Float;
	@:optional var h:Float;
	@:optional var fontSize:Float;
	@:optional var color:Int;
	@:optional var hidden:Bool;
	@:optional var locked:Bool;
	@:optional var shadow:Bool;
	@:optional var stroke:Float;
	@:optional var path:AuraPathImportModel;
	@:optional var fill:Bool;
	@:optional var strokeColor:Int;
	@:optional var fadeIn:Float;
	@:optional var fadeOut:Float;
	@:optional var pulseKind:Int;
	@:optional var pulsePeriod:Float;
	@:optional var pulseDepth:Float;
	@:optional var pulseColor:Int;
	@:optional var soundShow:String;
	@:optional var soundHide:String;
	@:optional var soundVolume:Float;
	@:optional var inStates:Array<String>;
	@:optional var sides:Int;
	@:optional var color2:Int;
	@:optional var gradDir:Int;
	@:optional var textAlign:Int;
	@:optional var wholeTime:Bool;
	@:optional var edge:AuraEdgeImportModel;
	@:optional var group:String;
	@:optional var outline:Float;
	@:optional var name:String;
	@:optional var stateOverrides:Map<String, AuraElementOverrideImportModel>;
	@:optional var rotation:Float;
	@:optional var opacity:Float;
}

/**
 * Typed model matching AuraEngine.toObj / AuraConfig.fromDyn.
 * Keep in sync when export shape gains fields.
 */
typedef AuraImportExportModel = {
	var id:String;
	var name:String;
	@:optional var enabled:Bool;
	@:optional var trigger:String;
	@:optional var skillId:String;
	@:optional var resource:String;
	@:optional var op:String;
	@:optional var pct:Float;
	@:optional var duration:Float;
	@:optional var region:String;
	@:optional var iconId:String;
	@:optional var invert:Bool;
	@:optional var requireAfford:Bool;
	@:optional var dormant:Bool;
	@:optional var alwaysOn:Bool;
	@:optional var activationGate:String;
	@:optional var visual:Bool;
	@:optional var audio:Bool;
	@:optional var cue:String;
	@:optional var plate:String;
	@:optional var announce:String;
	@:optional var fight:String;
	@:optional var group:String;
	@:optional var volume:Float;
	@:optional var opacity:Float;
	@:optional var scale:Float;
	@:optional var showIcon:Bool;
	@:optional var progressRing:Bool;
	@:optional var showCountdown:Bool;
	@:optional var countdownScale:Float;
	@:optional var countdownPlace:Int;
	@:optional var timerMode:Int;
	@:optional var timerSource:Int;
	@:optional var timerSeconds:Float;
	/** Legacy import field; timer visibility is now automatic and this value is ignored. */
	@:optional var timerKeepsAura:Bool;
	@:optional var timerStartEdge:Int;
	@:optional var glowStyle:String;
	@:optional var glowStrength:Float;
	@:optional var glowOuter:Float;
	@:optional var glowInner:Float;
	@:optional var textSize:Float;
	@:optional var timerBoard:Bool;
	@:optional var timerKeepExpired:Float;
	@:optional var showFuse:Bool;
	@:optional var fuseBottom:Bool;
	@:optional var followBuffDuration:Bool;
	@:optional var glowColor:Int;
	@:optional var stackCounter:Bool;
	@:optional var stackScale:Float;
	@:optional var stackPlace:Int;
	@:optional var showLabel:Bool;
	@:optional var isCounter:Bool;
	@:optional var bannerText:String;
	@:optional var bannerScale:Float;
	@:optional var showBanner:Bool;
	@:optional var keyText:String;
	@:optional var showKey:Bool;
	@:optional var effects:Array<AuraEffectImportModel>;
	@:optional var w:Float;
	@:optional var h:Float;
	@:optional var x:Float;
	@:optional var y:Float;
	@:optional var lock:Bool;
	@:optional var transparent:Bool;
	@:optional var rule:AuraRuleImportModel;
	@:optional var canvasElements:Array<AuraCanvasImportModel>;
	@:optional var states:Array<AuraStateImportModel>;
	/** Legacy alias some packs still emit. */
	@:optional var key:String;
	@:optional var fxPulse:Bool;
	@:optional var fxExpire:Bool;
	@:optional var fxReady:Bool;
	@:optional var iconGlow:Bool;
	@:optional var counterValue:Int;
}

/**
 * Type-safe JSON parser and validator wrapper using json2object macros.
 * Provides schema validation and error reporting for user-imported presets and profile bundles.
 */
class JsonSchema {
	static var auraParser:JsonParser<AuraImportExportModel>;

	/**
	 * Parse an Aura definition JSON string using compile-time generated schema validation.
	 * UnknownVariable (forward-compat extras) is non-fatal; IncorrectType / missing id|name fail.
	 */
	public static function parseAuraImport(jsonString:String):Null<AuraImportExportModel> {
		if (jsonString == null || StringTools.trim(jsonString).length == 0)
			return null;
		if (auraParser == null)
			auraParser = new JsonParser<AuraImportExportModel>();
		try {
			var result = auraParser.fromJson(jsonString, "aura_import.json");
			if (auraParser.errors != null && auraParser.errors.length > 0) {
				var fatal = false;
				for (err in auraParser.errors) {
					if (isFatalAuraError(err)) {
						fatal = true;
						#if debug
						trace('JsonSchema Aura import error: ${json2object.ErrorUtils.convertError(err)}');
						#end
					}
				}
				if (fatal)
					return null;
			}
			if (result == null || result.id == null || result.id.length == 0)
				return null;
			return result;
		} catch (e:Dynamic) {
			#if debug
			trace('JsonSchema exception: $e');
			#end
			return null;
		}
	}

	static function isFatalAuraError(err:Error):Bool {
		return switch (err) {
			case UnknownVariable(_, _): false;
			default: true;
		};
	}

}
