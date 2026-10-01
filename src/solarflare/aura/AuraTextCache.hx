package solarflare.aura;

/** Eight layouts cover live drawing and iterative preview fit without rewrapping each frame. */
class AuraTextCache {
	var entries:Array<{text:String, width:Float, size:Float, font:Dynamic, wrapped:String}> = [];
	public function new() {}
	public function resolve(text:String, width:Float, size:Float, font:Dynamic, measure:String->Float):String {
		for (entry in entries)
			if (entry.text == text && entry.width == width && entry.size == size && entry.font == font) return entry.wrapped;
		var wrapped = AuraTextLayout.wrap(text, width, measure);
		if (entries.length >= 8) entries.shift();
		entries.push({text:text, width:width, size:size, font:font, wrapped:wrapped});
		return wrapped;
	}
}
