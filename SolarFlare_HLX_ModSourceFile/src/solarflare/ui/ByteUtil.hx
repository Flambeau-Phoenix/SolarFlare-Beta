package solarflare.ui;

import haxe.io.Bytes;
import hl.Bytes as HLBytes;

/**
 * Shared byte-buffer utilities for ImGui text fields.
 * Uses HashLink's native byte operations with hl.Bytes required by ImGui.
 * 
 * IMPORTANT: hl.Bytes is a raw unmanaged pointer with no .length property.
 * The buffer capacity MUST always be passed explicitly.
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
		
		// Clear the buffer
		clearBytes(buf, effectiveCap);
		
		// Handle null or empty string
		if (s == null) {
			buf.setUI8(0, 0);
			return 0;
		}
		
		if (s.length == 0) {
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
		
		// Null-terminate
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
	
	/**
	 * Validate that a buffer contains a valid null-terminated string.
	 * 
	 * @param buf The buffer to validate
	 * @param cap The buffer capacity (MUST be > 0)
	 * @return true if valid, false otherwise
	 */
	public static function validateString(buf:HLBytes, cap:Int):Bool {
		if (buf == null || cap <= 0) {
			return false;
		}
		
		final effectiveCap:Int = (cap > MAX_BUFFER_SIZE) ? MAX_BUFFER_SIZE : cap;
		
		// Check for null terminator within bounds
		var idx:Int = 0;
		while (idx < effectiveCap) {
			if (buf.getUI8(idx) == 0) {
				return true;
			}
			idx++;
		}
		
		return false;
	}
	
	/**
	 * Compare two buffers for equality (null-terminated strings).
	 * 
	 * @param buf1 First buffer
	 * @param cap1 Capacity of first buffer (MUST be > 0)
	 * @param buf2 Second buffer
	 * @param cap2 Capacity of second buffer (MUST be > 0)
	 * @return true if the strings are equal, false otherwise
	 */
	public static function equals(buf1:HLBytes, cap1:Int, buf2:HLBytes, cap2:Int):Bool {
		// Early null checks
		if (buf1 == null || buf2 == null) {
			return buf1 == buf2;
		}
		
		// Read both strings
		final str1 = readString(buf1, cap1, true);
		final str2 = readString(buf2, cap2, true);
		
		return str1 == str2;
	}
	
	/**
	 * Get the length of a null-terminated string in a buffer.
	 * 
	 * @param buf The buffer
	 * @param cap The capacity (MUST be > 0)
	 * @return The string length in characters, or -1 on error
	 */
	public static function stringLength(buf:HLBytes, cap:Int):Int {
		if (buf == null || cap <= 0) {
			return -1;
		}
		
		final effectiveCap:Int = (cap > MAX_BUFFER_SIZE) ? MAX_BUFFER_SIZE : cap;
		
		var len:Int = 0;
		while (len < effectiveCap) {
			if (buf.getUI8(len) == 0) break;
			len++;
		}
		
		return (len < effectiveCap) ? len : -1;
	}
}
