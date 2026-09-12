package solarflare.util;

import haxe.crypto.Base64;
import haxe.io.Bytes;

/**
 * Hybrid share strings: Base64-wrapped JSON for clipboard / Discord,
 * raw JSON when input already starts with `{` or `[`.
 * Disk / SettingsStore / undo stay plain JSON — do not wrap those paths.
 */
class ShareCodec {
	/** Wrap a JSON string for user-facing clipboard / paste-box share. */
	public static function wrapJson(json:String):String {
		if (json == null)
			return "";
		return Base64.encode(Bytes.ofString(json));
	}

	/**
	 * Normalize user paste to a JSON string.
	 * `{` / `[` → raw JSON (whitespace preserved inside values).
	 * Otherwise treat as Base64 share key: strip whitespace/newlines before decode only.
	 */
	public static function unwrapToJson(s:String):Null<String> {
		if (s == null)
			return null;
		var t = StringTools.trim(s);
		if (t.length < 2)
			return null;
		if (t.charAt(0) == "{" || t.charAt(0) == "[")
			return t;
		// Share-key / Base64 branch only — never strip inside JSON string values.
		t = ~/[\s\r\n]+/g.replace(t, "");
		if (t.length < 2)
			return null;
		try {
			var decoded = Base64.decode(t).toString();
			if (decoded == null || StringTools.trim(decoded).length < 2)
				return null;
			return decoded;
		} catch (_:Dynamic) {
			return null;
		}
	}

	public static function encodeObj(obj:Dynamic):String {
		if (obj == null)
			return "";
		return wrapJson(haxe.Json.stringify(obj));
	}

	public static function parseDyn(s:String):Dynamic {
		var json = unwrapToJson(s);
		if (json == null)
			return null;
		return haxe.Json.parse(json);
	}
}
