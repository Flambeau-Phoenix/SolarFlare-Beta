package solarflare.ui;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;

/** Decoded 32-bit BGRA pixels. */
typedef BgraImage = {w:Int, h:Int, bgra:Bytes};

/**
 * Turns user image files into PNG bytes so the rest of the pipeline (scan, textures, share archives) stays
 * PNG-only. Native-free: pure `format` library decoding, safe to unit test. Oversized images are
 * box-filter downscaled instead of rejected.
 */
class ImageConvert {
	/** Extensions the importer accepts, lower-case without the dot. */
	public static var EXTENSIONS:Array<String> = ["png", "jpg", "gif", "bmp", "tga"];
	/** Hard ceiling on decoded pixels, checked before any scaling buffer is allocated. */
	public static inline var MAX_PIXELS:Int = 64 * 1024 * 1024 >> 2;

	/** JPEG decoder installed at runtime by JpegBridge (the game's own decoder); unset in tests and headless builds. */
	public static var jpegDecoder:Bytes->BgraImage = null;

	/** libpng decoder installed at runtime by PngBridge (the game's own); handles interlaced, 16-bit and odd greyscale PNGs. */
	public static var pngDecoder:Bytes->BgraImage = null;

	/** Formats the pure-Haxe reader gets wrong: interlaced, or anything but 8-bit outside palette images. */
	static function pngNeedsNative(b:Bytes):Bool {
		if (b.length < 29) return false;
		return b.get(28) == 1 || (b.get(25) != 3 && b.get(24) != 8);
	}

	/** Width/height from the first start-of-frame marker, or null when the file is not a readable JPEG. */
	public static function jpegSize(b:Bytes):{w:Int, h:Int} {
		var i = 2;
		while (i + 8 < b.length) {
			if (b.get(i) != 0xFF) { i++; continue; }
			var m = b.get(i + 1);
			if (m == 0xFF) { i++; continue; }
			if (m == 0xD8 || m == 0x01 || (m >= 0xD0 && m <= 0xD7)) { i += 2; continue; }
			var len = (b.get(i + 2) << 8) | b.get(i + 3);
			var sof = m >= 0xC0 && m <= 0xCF && m != 0xC4 && m != 0xC8 && m != 0xCC;
			if (sof) return {w: (b.get(i + 7) << 8) | b.get(i + 8), h: (b.get(i + 5) << 8) | b.get(i + 6)};
			if (m == 0xDA || len < 2) return null;
			i += 2 + len;
		}
		return null;
	}

	public static function isSupportedExtension(ext:String):Bool {
		ext = ext == null ? "" : ext.toLowerCase();
		return EXTENSIONS.indexOf(ext) >= 0 || ext == "jpeg";
	}

	/** Content-based type, falling back to the extension for formats without a magic number (TGA). */
	public static function sniff(b:Bytes, ext:String):String {
		ext = ext == null ? "" : ext.toLowerCase();
		if (b.length >= 8 && b.get(0) == 0x89 && b.get(1) == 0x50 && b.get(2) == 0x4E && b.get(3) == 0x47) return "png";
		if (b.length >= 6 && b.get(0) == 0x47 && b.get(1) == 0x49 && b.get(2) == 0x46 && b.get(3) == 0x38) return "gif";
		if (b.length >= 2 && b.get(0) == 0x42 && b.get(1) == 0x4D) return "bmp";
		if (b.length >= 3 && b.get(0) == 0xFF && b.get(1) == 0xD8 && b.get(2) == 0xFF) return "jpg";
		if (b.length >= 4 && b.get(0) == 0 && b.get(1) == 0 && b.get(2) == 1 && b.get(3) == 0) return "ico";
		if (ext == "tga") return "tga";
		return "unknown";
	}

	public static function decode(b:Bytes, ext:String):BgraImage {
		switch (sniff(b, ext)) {
			case "png":
				if (pngDecoder != null && pngNeedsNative(b)) {
					var img = pngDecoder(b);
					guard(img.w, img.h);
					return img;
				}
				try {
					var data = new format.png.Reader(new BytesInput(b)).read();
					var h = format.png.Tools.getHeader(data);
					guard(h.width, h.height);
					return {w: h.width, h: h.height, bgra: format.png.Tools.extract32(data)};
				} catch (e:Dynamic) {
					// The pure reader rejects some valid PNGs; the game's decoder gets a second try.
					if (pngDecoder == null) throw e;
					var img = pngDecoder(b);
					guard(img.w, img.h);
					return img;
				}
			case "gif":
				var data = new format.gif.Reader(new BytesInput(b)).read();
				var w = data.logicalScreenDescriptor.width, h = data.logicalScreenDescriptor.height;
				guard(w, h);
				return {w: w, h: h, bgra: format.gif.Tools.extractFullBGRA(data, 0)};
			case "bmp":
				var data = new format.bmp.Reader(new BytesInput(b)).read();
				guard(data.header.width, data.header.height);
				return {w: data.header.width, h: data.header.height, bgra: format.bmp.Tools.extractBGRA(data)};
			case "tga":
				var data = new format.tga.Reader(new BytesInput(b)).read();
				guard(data.header.width, data.header.height);
				return {w: data.header.width, h: data.header.height, bgra: format.tga.Tools.extract32(data, true)};
			case "jpg":
				if (jpegDecoder == null) throw "JPEG images are not supported yet. Save the image as PNG, GIF or BMP first.";
				var img = jpegDecoder(b);
				guard(img.w, img.h);
				return img;
			case "ico":
				throw "ICO files are not supported. Export the icon as PNG first.";
			default:
				throw "Unsupported image type. Use PNG, JPG, GIF, BMP or TGA.";
		}
	}

	static function guard(w:Int, h:Int):Void {
		if (w <= 0 || h <= 0 || w > 16384 || h > 16384 || w * h > MAX_PIXELS) throw "Image dimensions are out of range (" + w + "x" + h + ").";
	}

	/** Box-filter downscale so the longest side is at most `maxDim`; returns the input when it already fits. */
	public static function fit(img:BgraImage, maxDim:Int):BgraImage {
		if (img.w <= maxDim && img.h <= maxDim) return img;
		var s = maxDim / Math.max(img.w, img.h);
		var nw = Std.int(Math.max(1, Math.round(img.w * s))), nh = Std.int(Math.max(1, Math.round(img.h * s)));
		var out = Bytes.alloc(nw * nh * 4);
		for (y in 0...nh) {
			var y0 = Std.int(y * img.h / nh), y1 = Std.int(Math.max(y0 + 1, Math.min(img.h, Math.ceil((y + 1) * img.h / nh))));
			for (x in 0...nw) {
				var x0 = Std.int(x * img.w / nw), x1 = Std.int(Math.max(x0 + 1, Math.min(img.w, Math.ceil((x + 1) * img.w / nw))));
				// Alpha-weighted so transparent texels do not bleed dark fringes into edges.
				var sb = 0.0, sg = 0.0, sr = 0.0, sa = 0.0, n = 0;
				for (yy in y0...y1) for (xx in x0...x1) {
					var i = (yy * img.w + xx) * 4;
					var a = img.bgra.get(i + 3);
					sb += img.bgra.get(i) * a; sg += img.bgra.get(i + 1) * a; sr += img.bgra.get(i + 2) * a; sa += a; n++;
				}
				var o = (y * nw + x) * 4;
				if (sa > 0) {
					out.set(o, Std.int(sb / sa)); out.set(o + 1, Std.int(sg / sa)); out.set(o + 2, Std.int(sr / sa));
				}
				out.set(o + 3, Std.int(sa / n));
			}
		}
		return {w: nw, h: nh, bgra: out};
	}

	public static function encodePng(img:BgraImage):Bytes {
		var out = new BytesOutput();
		new format.png.Writer(out).write(format.png.Tools.build32BGRA(img.w, img.h, img.bgra));
		return out.getBytes();
	}

	/**
	 * Any supported file -> PNG bytes no larger than `maxDim` on a side. A PNG that already fits is returned
	 * untouched so its bytes (and any share hash) are preserved.
	 */
	public static function toPng(b:Bytes, ext:String, maxDim:Int):Bytes {
		var kind = sniff(b, ext);
		var img = decode(b, ext);
		if (kind == "png" && img.w <= maxDim && img.h <= maxDim) return b;
		return encodePng(fit(img, maxDim));
	}
}
