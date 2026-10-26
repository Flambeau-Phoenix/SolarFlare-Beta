package solarflare.ui;

import haxe.io.Bytes;
import hl.Bytes as HLBytes;

/** UTF-8 ImGui buffers and UTF-16 engine buffers. Raw capacities are always bytes. */
class ByteUtil {
 public static inline var MAX_BUFFER_SIZE:Int = 65536;
 public static inline var DEFAULT_CAPACITY:Int = 256;

 public static inline function readBytes(buf:HLBytes, cap:Int):String return readString(buf, cap, true);

 public static function readString(buf:HLBytes, cap:Int, trim:Bool = false):String {
  if (buf == null || cap <= 0) return "";
  var end = cap > MAX_BUFFER_SIZE ? MAX_BUFFER_SIZE : cap;
  var len = 0;
  while (len < end && buf.getUI8(len) != 0) len++;
  if (len == 0) return "";
  try {
   var result = buf.toBytes(len).getString(0, len);
   return trim ? StringTools.trim(result) : result;
  } catch (_:Dynamic) return "";
 }

 /**
  * Copy UTF-16 code units into an owned, terminated String.
  * charCount >= 0 reads exactly that many code units (zero means empty).
  * Scanning (charCount < 0) requires the actual readable byte capacity in cap.
  */
 public static function readUCS2(buf:HLBytes, charCount:Int = -1, cap:Int = 0):String {
  if (buf == null || charCount == 0) return "";
  var count = charCount;
  if (count < 0) {
   if (cap <= 0) return "";
   var limit = (cap > MAX_BUFFER_SIZE ? MAX_BUFFER_SIZE : cap) >> 1;
   count = 0;
   while (count < limit && buf.getUI16(count << 1) != 0) count++;
  } else {
   if (count > MAX_BUFFER_SIZE >> 1 || cap < 0 || (cap > 0 && count > cap >> 1)) return "";
  }
  return count == 0 ? "" : copyUCS2(buf, count);
 }

 static function copyUCS2(buf:HLBytes, count:Int):String {
  var bytes = count << 1;
  var owned = new HLBytes(bytes + 2);
  owned.blit(0, buf, 0, bytes);
  owned.setUI16(bytes, 0);
  return @:privateAccess String.__alloc__(owned, count);
 }

 /** Legacy entry point: default UTF-8, or explicit UTF-16. Encoding cannot be inferred from two bytes. */
 public static function readAuto(buf:HLBytes, cap:Int = DEFAULT_CAPACITY, utf16:Bool = false):String {
  return utf16 ? readUCS2(buf, -1, cap) : readString(buf, cap, true);
 }

 /** Bulk copy preserves surrogate pairs and avoids per-character StringBuf growth. */
 public static function materialize(s:String):String {
  if (s == null || s.length == 0) return "";
  if (s.length > 0x3FFFFFFE) return "";
  return copyUCS2(@:privateAccess s.bytes, s.length);
 }

 /** Only reject the complete textual byte/length dump shape, never a word or an arbitrary brace. */
 public static function isDumpShape(s:String):Bool {
  if (s == null || s.length == 0) return true;
  var text = StringTools.trim(s);
  if (!StringTools.startsWith(text, "{") || !StringTools.endsWith(text, "}")) return false;
  return dumpShape.match(text);
 }
 static var dumpShape = ~/^\{\s*"?bytes"?\s*:\s*.*[,]\s*"?length"?\s*:\s*[0-9]+\s*\}$/i;

 /** Managed strings copy directly. Raw hl.Bytes must have a trusted readable capacity. */
 public static function coerceString(val:Dynamic, cap:Int = DEFAULT_CAPACITY):String {
  if (val == null) return "";
  if (Std.isOfType(val, String)) return materialize(cast val);
  #if hl
  if (cap <= 0) return "";
  // A cast/catch is not a pointer-validity test. Reject non-byte Dynamic values before reading.
  var type = hl.Type.getDynamic(val);
  if (type == null || type.kind != hl.Type.TypeKind.HBytes) return "";
  return readUCS2(cast val, -1, cap);
  #else
  return "";
  #end
 }

 public static function clearBytes(buf:HLBytes, cap:Int):Int {
  if (buf == null || cap <= 0) return 0;
  var size = cap > MAX_BUFFER_SIZE ? MAX_BUFFER_SIZE : cap;
  buf.fill(0, size, 0);
  return size;
 }

 /** Copy complete UTF-8 characters, followed by NUL. Caller supplies the actual allocation capacity. */
 public static function fillBuf(buf:HLBytes, cap:Int, s:String):Int {
  if (buf == null || cap <= 0) return -1;
  var size = cap > MAX_BUFFER_SIZE ? MAX_BUFFER_SIZE : cap;
  if (size == 1 || s == null || s.length == 0) { buf.setUI8(0, 0); return 0; }
  return fillEncoded(buf, size, Bytes.ofString(s));
 }

 static function fillEncoded(buf:HLBytes, cap:Int, source:Bytes):Int {
  var count = source.length < cap - 1 ? source.length : cap - 1;
  if (count < source.length) {
   // If the next excluded byte is a continuation, move back to the incomplete character's lead byte.
   while (count > 0 && source.get(count) & 0xC0 == 0x80) count--;
  }
  if (count > 0) buf.blit(0, source.getData(), 0, count);
  buf.setUI8(count, 0);
  return count;
 }

 /** Allocate at least the UTF-8 payload plus NUL. Explicit cap is a minimum allocation size. */
 public static function fromString(s:String, cap:Int = -1):Null<HLBytes> {
  try {
   var source = s == null ? Bytes.alloc(0) : Bytes.ofString(s);
   if (source.length >= MAX_BUFFER_SIZE || cap > MAX_BUFFER_SIZE) return null;
   var required = source.length + 1;
   var size = cap > required ? cap : required;
   var buf = new HLBytes(size);
   // Reuse the encoding; do not convert the same string to UTF-8 a second time.
   fillEncoded(buf, size, source);
   return buf;
  } catch (_:Dynamic) return null;
 }
}
