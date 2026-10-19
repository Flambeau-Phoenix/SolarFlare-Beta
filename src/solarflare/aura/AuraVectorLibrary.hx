package solarflare.aura;

/** Ready-made vector outlines (24 x 24 icon-style SVG path data) offered under Insert > Vector. */
class AuraVectorLibrary {
	public static var ITEMS:Array<{key:String, label:String, d:String}> = [
		{key: "heart", label: "Heart", d: "M12 21 C12 21 3 14.5 3 8.5 C3 5.4 5.4 3 8.5 3 C10 3 11.4 3.7 12 5 C12.6 3.7 14 3 15.5 3 C18.6 3 21 5.4 21 8.5 C21 14.5 12 21 12 21 Z"},
		{key: "bolt", label: "Lightning bolt", d: "M13 2 L4 14 H11 L10 22 L20 9 H13 Z"},
		{key: "drop", label: "Drop", d: "M12 2 C12 2 5 10 5 15 C5 18.9 8.1 22 12 22 C15.9 22 19 18.9 19 15 C19 10 12 2 12 2 Z"},
		{key: "shield", label: "Shield", d: "M12 2 L4 5 V11 C4 16 7.5 20 12 22 C16.5 20 20 16 20 11 V5 Z"},
		{key: "arrow", label: "Arrow", d: "M3 10 H14 V5 L21 12 L14 19 V14 H3 Z"},
		{key: "crescent", label: "Crescent", d: "M20 14 A8 8 0 1 1 10 4 A6.5 6.5 0 0 0 20 14 Z"},
		{key: "cross", label: "Cross", d: "M9 3 H15 V9 H21 V15 H15 V21 H9 V15 H3 V9 H9 Z"},
		{key: "flame", label: "Flame", d: "M12 2 C12 2 6 8 6 13 C6 17.4 8.7 21 12 21 C15.3 21 18 17.4 18 13 C18 10 16 8 15 6 C14 8 13 9 12 9 C12 6 12 2 12 2 Z"},
		{key: "wave", label: "Wave (line)", d: "M2 12 C5 6 8 6 11 12 C14 18 17 18 20 12 L22 12"}
	];

	public static function find(key:String):{key:String, label:String, d:String} {
		for (i in ITEMS) if (i.key == key) return i;
		return null;
	}

	/**
	 * Pulls the `d="..."` values out of pasted SVG markup (several `<path>` elements are joined). Text that
	 * holds no such attribute is returned unchanged, so raw path data works too.
	 */
	public static function extractPathData(text:String):String {
		if (text == null) return "";
		var re = new EReg("\\sd\\s*=\\s*([\"'])([^\"']*)\\1", "g");
		var parts:Array<String> = [];
		var rest = text;
		while (re.match(rest)) {
			parts.push(re.matched(2));
			rest = re.matchedRight();
		}
		return parts.length > 0 ? parts.join(" ") : text;
	}
}
