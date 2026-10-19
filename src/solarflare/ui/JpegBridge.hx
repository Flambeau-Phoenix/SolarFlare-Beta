package solarflare.ui;

import haxe.io.Bytes;

/**
 * Decodes JPEG through the game's own native decoder (`hxd.res.Image.decodeJPG`) so the mod ships no JPEG
 * code. Any failure surfaces as a readable message and the import falls back to "save as PNG".
 */
class JpegBridge {
	static var installed = false;

	public static function install():Void {
		if (installed) return;
		installed = true;
		ImageConvert.jpegDecoder = decode;
	}

	static function decode(b:Bytes):ImageConvert.BgraImage {
		var size = ImageConvert.jpegSize(b);
		if (size == null || size.w <= 0 || size.h <= 0) throw "Not a readable JPEG image.";
		var w = size.w, h = size.h;
		try {
			var pixels:hxd.Pixels = hxd.res.Image.decodeJPG(cast b, w, h, hxd.PixelFormat.BGRA);
			if (pixels == null) throw "no pixels returned";
			var src:Bytes = cast pixels.bytes;
			var base = pixels.offset, stride = pixels.stride > 0 ? pixels.stride : w * 4;
			var out = Bytes.alloc(w * h * 4);
			if (src == null || base + stride * (h - 1) + w * 4 > src.length) throw "unexpected pixel buffer";
			for (y in 0...h) out.blit(y * w * 4, src, base + y * stride, w * 4);
			return {w: w, h: h, bgra: out};
		} catch (e:Dynamic) {
			throw "JPEG decoding is unavailable in this game build (" + Std.string(e) + "). Save the image as PNG, GIF or BMP first.";
		}
	}
}
