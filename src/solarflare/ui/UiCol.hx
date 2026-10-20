package solarflare.ui;

/**
 * Dear ImGui draw-list colors are packed as IM_COL32 / ABGR on little-endian:
 * `(A<<24)|(B<<16)|(G<<8)|R`. Writing AARRGGBB literals swaps red and blue
 * (fiery orange reads as blue). Prefer these helpers or `colorConvertFloat4ToU32`.
 */
class UiCol {
	/** Pack 0–255 RGBA channels into an ImGui draw-list U32. */
	public static inline function rgba(r:Int, g:Int, b:Int, a:Int = 255):Int {
		return (a << 24) | (b << 16) | (g << 8) | r;
	}

	/** Pack `0xRRGGBB` with alpha into an ImGui draw-list U32. */
	public static inline function rgb(rgb24:Int, a:Int = 255):Int {
		return rgba((rgb24 >> 16) & 0xFF, (rgb24 >> 8) & 0xFF, rgb24 & 0xFF, a);
	}

	/**
	 * Reinterpret a mistaken AARRGGBB / `(a<<24)|0x00RRGGBB` literal as the
	 * intended RGBA channels and emit ABGR.
	 */
	public static inline function fromArgb(argb:Int):Int {
		return rgba((argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF, (argb >>> 24) & 0xFF);
	}

	/** Move a packed ABGR color toward white by `amount` (0..1), alpha kept. */
	public static function lighten(color:Int, amount:Float):Int {
		var a = (color >>> 24) & 0xFF;
		var b = (color >>> 16) & 0xFF;
		var g = (color >>> 8) & 0xFF;
		var r = color & 0xFF;
		r = Std.int(Math.min(255, r + (255 - r) * amount));
		g = Std.int(Math.min(255, g + (255 - g) * amount));
		b = Std.int(Math.min(255, b + (255 - b) * amount));
		return rgba(r, g, b, a);
	}

	/** Move a packed ABGR color toward black by `amount` (0..1), alpha kept. */
	public static function darken(color:Int, amount:Float):Int {
		var keep = 1 - amount;
		return rgba(Std.int((color & 0xFF) * keep), Std.int(((color >>> 8) & 0xFF) * keep),
			Std.int(((color >>> 16) & 0xFF) * keep), (color >>> 24) & 0xFF);
	}

	/** Replace the alpha channel of a packed ABGR color (0..255). */
	public static inline function withAlpha(color:Int, a:Int):Int {
		return (color & 0x00FFFFFF) | (a << 24);
	}
}
