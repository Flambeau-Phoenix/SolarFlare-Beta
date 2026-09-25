package solarflare.ui;

import haxe.io.Bytes;
import hl.Bytes as HLBytes;

/**
 * Shared byte-buffer utilities for ImGui text fields and HashLink native strings.
 * Uses HashLink's native byte operations with hl.Bytes required by ImGui.
 *
 * IMPORTANT: hl.Bytes is a raw unmanaged pointer with no .length property.
 * The buffer capacity MUST always be passed explicitly.
 *
 * ImGui buffers = null-terminated UTF-8 (readString/readBytes/fillBuf).
 * Engine String / FieldWalk bytes = UCS-2/UTF-16LE (readUCS2 / materialize / coerceString).
 * Prefer coerceString or readUCS2 at engine sites; readAuto is ImGui/unknown only.
 */
class ByteUtil {
	/** Maximum buffer size to prevent runaway iteration (64 KB) */
	public static inline var MAX_BUFFER_SIZE:Int = 65536;
	
	/** Default buffer capacity for most text fields */
	public static inline var DEFAULT_CAPACITY:Int = 256;

	/** Read a null-terminated UTF-8 byte buffer into a trimmed String. */
	public static inline function readBytes(buf:HLBytes, cap:Int):String {
		return readString(buf, cap, true);
	}

	/**
	 * Read a null-terminated UTF-8 byte buffer, optionally preserving whitespace.
	 *
	 * @param buf The HashLink byte buffer
	 * @param cap The allocated capacity of the buffer
	 * @param trim Whether to trim leading/trailing whitespace
	 * @return Decoded UTF-8 string, or empty string on null/error
	 */
	public static function readString(buf:HLBytes, cap:Int, trim:Bool = false):String {
		// Validate inputs
		if (buf == null || cap <= 0) {
			return "";
		}

		// Guard against excessive capacity
		final effectiveCap:Int = (cap > MAX_BUFFER_SIZE) ? MAX_BUFFER_SIZE : cap;
		
		// Scan for null terminator with bounds checking
		var len:Int = 0;
		while (len < effectiveCap) {
			if (buf.getUI8(len) == 0) break;
			len++;
		}

		// Early return for empty strings
		if (len == 0) {
			return "";
		}

		// Safe extraction with error recovery
		try {
			final raw = buf.toBytes(len);
			final result = raw.getString(0, len);
			return trim ? StringTools.trim(result) : result;
		} catch (e:Dynamic) {
			#if debug
			trace('ByteUtil.readString error: $e');
			#end
			return "";
		}
	}

	/**
	 * Read a HashLink native UCS-2 / UTF-16LE string buffer.
	 * Fixes opaque `???` when UTF-8 scanners stop on the 0x00 high byte of ASCII.
	 *
	 * @param buf Raw character bytes (vbyte* / hl.Bytes)
	 * @param charCount Explicit character count (e.g. String.length). If <= 0, scans for 16-bit NUL.
	 */
	public static function readUCS2(buf:HLBytes, charCount:Int = -1):String {
		if (buf == null)
			return "";
		try {
			if (charCount > 0)
				return @:privateAccess String.__alloc__(buf, charCount);
			return @:privateAccess String.fromUCS2(buf);
		} catch (e:Dynamic) {
			#if debug
			trace('ByteUtil.readUCS2 error: $e');
			#end
			return "";
		}
	}

	/**
	 * Auto-detect UTF-8 (ImGui) vs UCS-2 (engine String bytes).
	 * Prefer readUCS2 / coerceString at engine/FieldWalk sites — do not guess with readAuto.
	 * Heuristic: empty UCS-2 (0x00 0x00); ASCII LE (b0!=0 && b1==0) => UCS-2; else UTF-8.
	 */
	public static function readAuto(buf:HLBytes, cap:Int = DEFAULT_CAPACITY):String {
		if (buf == null || cap <= 0)
			return "";
		try {
			if (cap >= 2) {
				var b0 = buf.getUI8(0);
				var b1 = buf.getUI8(1);
				// Empty UCS-2 / UTF-16LE null string — do not UTF-8-scan.
				if (b0 == 0 && b1 == 0)
					return "";
				if (b0 != 0 && b1 == 0)
					return readUCS2(buf, -1);
			}
		} catch (_:Dynamic) {}
		return readString(buf, cap, true);
	}

	/**
	 * Copy a HashLink String into a fresh UTF-16-backed Haxe String via char codes.
	 * Prevents haxe.Json.stringify from emitting `{bytes:"???",length:N}` for engine strings.
	 */
	public static function materialize(s:String):String {
		if (s == null || s.length == 0)
			return "";
		try {
			var out = new StringBuf();
			var i = 0;
			while (i < s.length) {
				var c = s.charCodeAt(i);
				if (c != null)
					out.addChar(c);
				i++;
			}
			return out.toString();
		} catch (_:Dynamic) {
			return "";
		}
	}

	/** True for Json/Std.string dump shapes like `{bytes : ???, length : N}`. */
	public static function isDumpShape(s:String):Bool {
		if (s == null || s.length == 0)
			return true;
		if (s.indexOf("{") >= 0 || s.indexOf("}") >= 0)
			return true;
		var low = s.toLowerCase();
		return low.indexOf("bytes") >= 0;
	}

	/**
	 * Dynamic → managed Haxe String for hooks / FieldWalk.
	 * String → materialize; raw vbyte* → try readUCS2 (no isBytes); never Std.string.
	 */
	public static function coerceString(val:Dynamic, cap:Int = DEFAULT_CAPACITY):String {
		if (val == null)
			return "";
		// 1. Boxed Haxe String path
		if (Std.isOfType(val, String)) {
			var s = materialize(cast val);
			return isDumpShape(s) ? "" : s;
		}
		#if hl
		// 2. Raw HashLink Bytes pointer (vbyte*) — guarded; no isBytes on this HL.
		try {
			var decoded = readUCS2(cast val, -1);
			if (decoded != null && decoded.length > 0 && !isDumpShape(decoded))
				return decoded;
		} catch (_:Dynamic) {}
		#end
		// 3. Fallback: drop safely without Std.string dumps
		return "";
	}

	/**
	 * Zero-fill a byte buffer with bounds checking.
	 *
	 * @param buf The HashLink buffer to clear
	 * @param cap Number of bytes to zero out (must be > 0 and <= allocated capacity)
	 * @return The actual number of bytes cleared
	 */
	public static function clearBytes(buf:HLBytes, cap:Int):Int {
		if (buf == null || cap <= 0) {
			return 0;
		}
		
		final clearSize:Int = (cap > MAX_BUFFER_SIZE) ? MAX_BUFFER_SIZE : cap;
		
		buf.fill(0, clearSize, 0);
		return clearSize;
	}

	/**
	 * Fill a byte buffer from a String, guaranteeing null-termination.
	 * Writes payload + single NUL only — does not zero the remainder of the buffer.
	 *
	 * @param buf Destination buffer
	 * @param cap Capacity of the buffer (MUST be > 0)
	 * @param s Source string
	 * @return Number of payload bytes written (excluding null terminator), or -1 on error
	 */
	public static function fillBuf(buf:HLBytes, cap:Int, s:String):Int {
		// Validate buffer
		if (buf == null || cap <= 0) {
			#if debug
			trace('ByteUtil.fillBuf: invalid buffer or capacity');
			#end
			return -1;
		}
		
		// Determine effective capacity
		final effectiveCap:Int = (cap > MAX_BUFFER_SIZE) ? MAX_BUFFER_SIZE : cap;
		
		// Need at least 1 byte for null terminator
		if (effectiveCap <= 1) {
			return 0;
		}
		
		// Handle null or empty string
		if (s == null || s.length == 0) {
			buf.setUI8(0, 0);
			return 0;
		}
		
		// Convert to UTF-8 bytes
		final source = Bytes.ofString(s);
		final sourceLen:Int = source.length;
		
		// Calculate copy length (leave room for null terminator)
		final copyLen:Int = (sourceLen < effectiveCap - 1) ? sourceLen : effectiveCap - 1;
		
		// Copy bytes if there's data to copy
		if (copyLen > 0) {
			buf.blit(0, source.getData(), 0, copyLen);
		}
		
		// Null-terminate immediately after payload
		buf.setUI8(copyLen, 0);
		
		// Warn about truncation in debug builds
		#if debug
		if (copyLen < sourceLen) {
			trace('ByteUtil.fillBuf: truncated string from ${sourceLen} to ${copyLen} bytes');
		}
		#end
		
		return copyLen;
	}

	/**
	 * Create a newly allocated buffer from a string with null-termination.
	 *
	 * @param s String to write (null becomes empty string)
	 * @param cap Explicit capacity, or -1 for automatic sizing (string length + 1)
	 * @return New buffer containing the string, or null on error
	 */
	public static function fromString(s:String, cap:Int = -1):Null<HLBytes> {
		try {
			// Handle null string
			final source = (s != null) ? Bytes.ofString(s) : Bytes.alloc(0);
			final requiredSize:Int = source.length + 1; // +1 for null terminator
			
			// Determine final buffer size
			final bufferSize:Int = (cap < requiredSize || cap <= 0) ? requiredSize : cap;
			
			// Guard against excessive allocation
			if (bufferSize > MAX_BUFFER_SIZE) {
				#if debug
				trace('ByteUtil.fromString: requested ${bufferSize} bytes exceeds max (${MAX_BUFFER_SIZE})');
				#end
				return null;
			}
			
			// Allocate and fill
			final buf = new HLBytes(bufferSize);
			final written:Int = fillBuf(buf, bufferSize, s);
			
			// Validate write succeeded (written >= 0 means success, even if 0 bytes written)
			if (written < 0) {
				return null;
			}
			
			return buf;
		} catch (e:Dynamic) {
			#if debug
			trace('ByteUtil.fromString allocation error: $e');
			#end
			return null;
		}
	}
	
}
