package solarflare.ui;

import haxe.io.Bytes;

/**
 * Decodes PNG through the game's own libpng-backed decoder (`hxd.res.Image.decodePNG`), for the formats the
 * pure-Haxe reader cannot handle (interlaced, 16-bit, low-bit greyscale). Only used while conforming images.
 */
class PngBridge {
	static var installed = false;

	public static function install():Void {
		if (installed) return;
		installed = true;
		ImageConvert.pngDecoder = decode;
	}

	static function decode(b:Bytes):ImageConvert.BgraImage {
		if (b.length < 24) throw "Not a readable PNG image.";
		var w = (b.get(16) << 24) | (b.get(17) << 16) | (b.get(18) << 8) | b.get(19);
		var h = (b.get(20) << 24) | (b.get(21) << 16) | (b.get(22) << 8) | b.get(23);
		if (w <= 0 || h <= 0 || w > 16384 || h > 16384) throw "Image dimensions are out of range (" + w + "x" + h + ").";
		try {
			var pixels:hxd.Pixels = hxd.res.Image.decodePNG(cast b, w, h, hxd.PixelFormat.BGRA);
			if (pixels == null) throw "no pixels returned";
			var src:Bytes = cast pixels.bytes;
			var base = pixels.offset, stride = pixels.stride > 0 ? pixels.stride : w * 4;
			var out = Bytes.alloc(w * h * 4);
			if (src == null || base + stride * (h - 1) + w * 4 > src.length) throw "unexpected pixel buffer";
			for (y in 0...h) out.blit(y * w * 4, src, base + y * stride, w * 4);
			return {w: w, h: h, bgra: out};
		} catch (e:Dynamic) {
			throw "This PNG uses a format the mod cannot read (" + Std.string(e) + "). Re-save it as a standard 8-bit PNG.";
		}
	}
}
