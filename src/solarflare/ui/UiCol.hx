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
}
