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
}

/** Nested canvas element — mirrors AuraCanvasElement.toObj. */
typedef AuraCanvasImportModel = {
	@:optional var kind:String;
	@:optional var content:String;
	@:optional var x:Float;
	@:optional var y:Float;
	@:optional var w:Float;
	@:optional var h:Float;
	@:optional var fontSize:Float;
	@:optional var color:Int;
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
	@:optional var visual:Bool;
	@:optional var audio:Bool;
	@:optional var cue:String;
	@:optional var plate:String;
	@:optional var announce:String;
	@:optional var fight:String;
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
	@:optional var timerBoard:Bool;
	@:optional var timerKeepExpired:Float;
	@:optional var showFuse:Bool;
	@:optional var fuseBottom:Bool;
	@:optional var followBuffDuration:Bool;
	@:optional var glowColor:Int;
	@:optional var stackCounter:Bool;
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

	/**
	 * Check if a JSON string matches the Aura import schema.
	 */
	public static function isValidAuraImport(jsonString:String):Bool {
		return parseAuraImport(jsonString) != null;
	}
}
