package solarflare.aura;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.crypto.Crc32;
import haxe.zip.Uncompress;

typedef AuraShareEntry = {
 var name:String; var offset:Int; var dataOffset:Int;
 var compressedSize:Int; var size:Int; var crc:Int; var method:Int; var flags:Int;
}

/** Bounded ZIP index. No extraction and no decompression before validating all headers. */
class AuraShareArchive {
 public static inline var MAX_BYTES:Int=64*1024*1024;
 public static inline var MAX_IMAGES:Int=256;
 public static inline var MAX_JSON:Int=4*1024*1024;
 public var names(default,null):Array<String>=[];
 var bytes:Bytes;
 var entries=new Map<String,AuraShareEntry>();
 public function new(bytes:Bytes) {
  if(bytes==null || bytes.length>MAX_BYTES) throw "Share archive exceeds 64 MiB.";
  this.bytes=bytes;
  var input=new BytesInput(bytes); input.bigEndian=false;
  var total=0;
  function room(n:Int):Void { if(n<0 || input.position>bytes.length-n) throw "Truncated share archive."; }
  while(true) {
   room(4); var offset=input.position; var signature=input.readInt32();
   if(signature==0x02014B50) { input.position=offset; break; }
   if(signature!=0x04034B50) throw "Invalid ZIP local header.";
   room(26); var version=input.readUInt16(); var flags=input.readUInt16(); var method=input.readUInt16();
   input.position+=4;
   var crc=input.readInt32(); var compressed=input.readInt32(); var size=input.readInt32();
   var nameLength=input.readUInt16(); var extra=input.readUInt16(); room(nameLength+extra);
   var name=input.readString(nameLength); input.position+=extra;
   if(version>20 || (flags & ~0x800)!=0 || (method!=0 && method!=8)) throw "Unsupported ZIP feature (encryption, streaming or ZIP64).";
   if(!safeName(name) || entries.exists(name)) throw "Unexpected, unsafe or duplicate ZIP entry: "+name;
   var limit=name=="manifest.json" || name=="auras.json" ? MAX_JSON : 4*1024*1024;
   if(size<0 || size>limit || compressed<0 || compressed>MAX_BYTES || (method==0 && compressed!=size)) throw "Invalid entry size: "+name;
   room(compressed); total+=size;
   if(total>MAX_BYTES || names.length>=MAX_IMAGES+2) throw "Share package exceeds its size or image limit.";
   var entry:AuraShareEntry={name:name,offset:offset,dataOffset:input.position,compressedSize:compressed,size:size,crc:crc,method:method,flags:flags};
   entries.set(name,entry); names.push(name); input.position+=compressed;
  }
  var centralStart=input.position; var seen=new Map<String,Bool>(); var count=0;
  while(true) {
   room(4); var signature=input.readInt32();
   if(signature==0x06054B50) break;
   if(signature!=0x02014B50) throw "Invalid ZIP central directory.";
   room(42); input.position+=2; var version=input.readUInt16(); var flags=input.readUInt16(); var method=input.readUInt16(); input.position+=4;
   var crc=input.readInt32(); var compressed=input.readInt32(); var size=input.readInt32();
   var nameLength=input.readUInt16(); var extra=input.readUInt16(); var comment=input.readUInt16(); var disk=input.readUInt16();
   input.position+=2; var attributes=input.readInt32(); var offset=input.readInt32(); room(nameLength+extra+comment);
   var name=input.readString(nameLength); input.position+=extra+comment;
   var entry=entries.get(name);
   if(entry==null || seen.exists(name) || disk!=0 || version>20 || ((attributes>>>16)&0xF000)==0xA000
    || entry.offset!=offset || entry.crc!=crc || entry.method!=method || entry.flags!=flags || entry.size!=size || entry.compressedSize!=compressed)
    throw "ZIP directory does not match its entries.";
   seen.set(name,true); count++;
  }
  var centralSize=input.position-4-centralStart;
  room(18); var disk=input.readUInt16(); var startDisk=input.readUInt16(); var diskCount=input.readUInt16(); var entryCount=input.readUInt16();
  var declaredSize=input.readInt32(); var declaredOffset=input.readInt32(); var comment=input.readUInt16(); room(comment); input.position+=comment;
  if(disk!=0 || startDisk!=0 || diskCount!=count || entryCount!=count || count!=names.length || declaredSize!=centralSize
   || declaredOffset!=centralStart || input.position!=bytes.length || !entries.exists("manifest.json") || !entries.exists("auras.json")) throw "Invalid or incomplete share ZIP directory.";
 }
 public static function safeName(name:String):Bool {
  return name=="manifest.json" || name=="auras.json" || ~/^images\/[a-f0-9]{64}\.png$/.match(name);
 }
 public function read(name:String):Bytes {
  var e=entries.get(name); if(e==null) throw "Missing package file: "+name;
  var data=bytes.sub(e.dataOffset,e.compressedSize);
  if(e.method==8) {
   var out=Bytes.alloc(e.size); var z=new Uncompress(-15);
   try {
    var result=z.execute(data,0,out,0);
    if(!result.done || result.read!=data.length || result.write!=e.size) throw "Invalid compressed share entry.";
   } catch(error:Dynamic) { z.close(); throw error; }
   z.close(); data=out;
  }
  if(Crc32.make(data)!=e.crc) throw "ZIP checksum mismatch: "+name;
  return data;
 }
}
