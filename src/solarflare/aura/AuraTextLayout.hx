package solarflare.aura;

/** Wrap preserves authored line breaks and breaks long words to fit the text box. */
class AuraTextLayout {
	public static function fontSize(value:Float):Float return Math.isFinite(value) ? Math.max(6, Math.min(256, value)) : 24;
	public static function wrap(text:String, width:Float, measure:String->Float):String {
		if (text == null || text.length == 0) return "";
		width = Math.max(1, width);
		var output:Array<String> = [];
		for (paragraph in text.split("\n")) {
			var line = "";
			var lastBreak = -1;
			for (i in 0...paragraph.length) {
				var ch = paragraph.charAt(i);
				var candidate = line + ch;
				if (line.length > 0 && measure(candidate) > width) {
					if (lastBreak > 0) {
						output.push(line.substr(0, lastBreak));
						line = StringTools.ltrim(line.substr(lastBreak + 1));
					} else {
						output.push(line);
						line = "";
					}
					lastBreak = line.lastIndexOf(" ");
				}
				line += ch;
				if (ch == " ") lastBreak = line.length - 1;
			}
			output.push(line);
		}
		return output.join("\n");
	}
}
