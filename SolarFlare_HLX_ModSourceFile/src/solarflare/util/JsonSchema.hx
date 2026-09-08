package solarflare.util;

import json2object.JsonParser;

/** Typed model for importable/exportable Aura definitions. */
typedef AuraImportExportModel = {
	var id:String;
	var name:String;
	@:optional var trigger:String;
	@:optional var skillId:String;
	@:optional var resource:String;
	@:optional var op:String;
	@:optional var pct:Float;
	@:optional var duration:Float;
	@:optional var iconId:String;
	@:optional var fight:String;
	@:optional var cue:String;
	@:optional var plate:String;
}

/**
 * Type-safe JSON parser and validator wrapper using json2object macros.
 * Provides schema validation and error reporting for user-imported presets and profile bundles.
 */
class JsonSchema {
	static var auraParser:JsonParser<AuraImportExportModel>;

	/**
	 * Parse an Aura definition JSON string using compile-time generated schema validation.
	 */
	public static function parseAuraImport(jsonString:String):Null<AuraImportExportModel> {
		if (jsonString == null || StringTools.trim(jsonString).length == 0)
			return null;
		if (auraParser == null)
			auraParser = new JsonParser<AuraImportExportModel>();
		try {
			var result = auraParser.fromJson(jsonString, "aura_import.json");
			if (auraParser.errors != null && auraParser.errors.length > 0) {
				#if debug
				for (err in auraParser.errors) {
					trace('JsonSchema Aura import error: ${json2object.ErrorUtils.convertError(err)}');
				}
				#end
				return null;
			}
			return result;
		} catch (e:Dynamic) {
			#if debug
			trace('JsonSchema exception: $e');
			#end
			return null;
		}
	}

	/**
	 * Check if a JSON string matches the Aura import schema.
	 */
	public static function isValidAuraImport(jsonString:String):Bool {
		return parseAuraImport(jsonString) != null;
	}
}
