package solarflare.aura;

/** Large clipboard shares are separate from the deliberately small editor text buffers. */
class AuraShareText {
 public static inline var MAX_TEXT_BYTES:Int=6*1024*1024;
 public static function encode(data:Dynamic):String {
  var json=haxe.Json.stringify(data);
  if(haxe.io.Bytes.ofString(json).length>AuraShareArchive.MAX_JSON) throw "Aura definitions exceed 4 MiB.";
  return solarflare.util.ShareCodec.wrapJson(json);
 }
 public static function decode(raw:String):String {
  if(raw==null || haxe.io.Bytes.ofString(raw).length>MAX_TEXT_BYTES) throw "Share text exceeds 6 MiB. Use a share file.";
  var json=solarflare.util.ShareCodec.unwrapToJson(raw);
  if(json==null) throw "Invalid Aura share key or JSON.";
  if(haxe.io.Bytes.ofString(json).length>AuraShareArchive.MAX_JSON) throw "Aura definitions exceed 4 MiB.";
  return json;
 }
 #if hl
 public static function readClipboard(bytes:hl.Bytes):String {
  if(bytes==null) return "";
  var length=0;
  while(length<MAX_TEXT_BYTES && bytes.getUI8(length)!=0) length++;
  if(length==MAX_TEXT_BYTES && bytes.getUI8(length)!=0) throw "Clipboard share exceeds 6 MiB. Use a share file.";
  return bytes.toBytes(length).toString();
 }
 #end
}
