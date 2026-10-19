package solarflare.aura;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import haxe.crypto.Sha256;
import haxe.crypto.Crc32;
import format.png.Reader;
import format.png.Tools;
import solarflare.ui.CustomImageKey;
import solarflare.aura.signal.AuraSignalCatalog;
import solarflare.aura.signal.AuraConditionValidator;

typedef AuraShareImage = {
 var sha256:String; var entry:String; var bytes:Int; var width:Int; var height:Int; var keys:Array<String>;
}

/** Portable package rules, dependency discovery and validation; no filesystem or live state. */
class AuraSharePackage {
 public static inline var FORMAT:String="solarflare.aura-share";
 public static inline var VERSION:Int=1;
 public static function hash(bytes:Bytes):String return Sha256.make(bytes).toHex();
 public static function clone(value:Dynamic):Dynamic return haxe.Json.parse(haxe.Json.stringify(value));
 public static function json(bytes:Bytes):Dynamic {
  if(bytes.length>AuraShareArchive.MAX_JSON) throw "Share JSON exceeds 4 MiB.";
  var text=bytes.toString(); var quoted=false; var escaped=false; var depth=0;
  for(i in 0...text.length) {
   var c=text.charCodeAt(i);
   if(quoted) { if(escaped) escaped=false; else if(c==92) escaped=true; else if(c==34) quoted=false; }
   else if(c==34) quoted=true;
   else if(c==123 || c==91) { if(++depth>64) throw "Share JSON is nested too deeply."; }
   else if(c==125 || c==93) depth--;
  }
  return haxe.Json.parse(text);
 }
 public static function list(value:Dynamic,label:String,max:Int):Array<Dynamic> {
  if(!Std.isOfType(value,Array)) throw label+" must be an array.";
  var rows:Array<Dynamic>=cast value; if(rows.length>max) throw label+" exceeds the supported limit."; return rows;
 }
 public static function records(value:Dynamic,label:String,max:Int):Array<Dynamic> {
  var rows=list(value,label,max); var ids=new Map<String,Bool>();
  for(row in rows) {
   if(row==null || !Std.isOfType(row.id,String) || StringTools.trim(row.id).length==0 || row.id.length>160 || ids.exists(row.id)) throw "Invalid or duplicate "+label+" ID.";
   ids.set(row.id,true);
  }
  return rows;
 }
 public static function validateRule(rule:Dynamic):Void {
  if(rule==null) return;
  if(rule.version!=1 || (rule.mode!="all" && rule.mode!="any")) throw "Unsupported Aura rule version or mode.";
  var conditions=list(rule.conditions,"Rule conditions",solarflare.aura.signal.AuraRuleDef.MAX_CONDITIONS);
  if(conditions.length>0 && (!Std.isOfType(rule.presentationSource,Int) || rule.presentationSource<0 || rule.presentationSource>=conditions.length)) throw "Invalid rule presentation source.";
  for(c in conditions) {
   if(c==null || !Std.isOfType(c.signal,String)) throw "Invalid Aura condition.";
   var descriptor=AuraSignalCatalog.find(c.signal);
   if(descriptor==null) throw "This mod build does not support signal: "+c.signal;
   if(!AuraConditionValidator.isValidOperator(c.op,descriptor)) throw "Unsupported comparison for "+c.signal;
   if(descriptor.subjectKind.length>0 && (!Std.isOfType(c.subject,String) || StringTools.trim(c.subject).length==0)) throw "Missing subject for "+c.signal;
   if(descriptor.subjectKind=="statusType" && solarflare.cdb.StatusTypeCatalog.index(c.subject)<0) throw "Unsupported status type: "+c.subject;
   if(c.signal=="custom.script" && haxe.io.Bytes.ofString(c.subject).length>4096) throw "Expression exceeds 4,096 UTF-8 bytes; source was not truncated.";
   if(c.numberValue!=null && ((!Std.isOfType(c.numberValue,Float) && !Std.isOfType(c.numberValue,Int)) || !Math.isFinite(c.numberValue))) throw "Invalid condition threshold.";
  }
 }
 public static function validatePack(pack:Dynamic):Void {
  if(pack==null || pack.kind!="solarflare.aura_pack" || pack.v!=1) throw "Unsupported Aura definitions.";
  if(!Std.isOfType(pack.name,String) || pack.name.length>256) throw "Invalid share package name.";
  var auras=records(pack.auras,"Auras",AuraLimits.MAX_AURAS); if(auras.length==0) throw "The package contains no Auras.";
  var groups=records(pack.groups,"Groups",AuraLimits.MAX_GROUPS); var sets=records(pack.sets,"Sets",AuraLimits.MAX_SETS);
  var groupIds=new Map<String,Bool>(); for(g in groups) groupIds.set(g.id,true);
  var setIds=new Map<String,Bool>(); for(s in sets) setIds.set(s.id,true);
  for(g in groups) {
   for(field in ["grow","align","sort"]) {
    var value=Reflect.field(g,field); var supported=field=="grow" ? AuraGroupDef.GROWS : field=="align" ? AuraGroupDef.ALIGNS : AuraGroupDef.SORTS;
    if(value!=null && supported.indexOf(value)<0) throw "Unsupported group "+field+": "+Std.string(value);
   }
  }
  for(s in sets) {
   if(s.mode!=null && (!Std.isOfType(s.mode,Int) || s.mode<0 || s.mode>2)) throw "Unsupported set activation mode.";
   if(s.maps!=null) for(map in list(s.maps,"Set maps",AuraSetDef.MAX_MAPS)) if(!Std.isOfType(map,String) || StringTools.trim(map).length==0) throw "Invalid set map.";
  }
  for(a in auras) {
   if(!Std.isOfType(a.name,String) || a.name.length==0) throw "An Aura has no name.";
   if(a.group!=null && a.group!="" && !groupIds.exists(a.group)) throw "Missing display group for "+a.name;
   if(a.fight!=null && a.fight!="" && !setIds.exists(a.fight)) throw "Missing Aura set for "+a.name;
   if(a.trigger!=null && ["resource","prayer","cooldown","status","combatlog","combo","chaincast","conduit","script","custom"].indexOf(a.trigger)<0) throw "Unsupported Aura trigger: "+a.trigger;
   if(a.region!=null && ["bar","ring","text","icon","canvas"].indexOf(a.region)<0) throw "Unsupported Aura style: "+a.region;
   validateRule(a.rule);
   if(a.effects!=null) for(e in list(a.effects,"Effects",8)) {
    if(e==null || ["window","alert","icon","audio"].indexOf(e.kind)<0 || ["whileTrue","whileFalse","onRise","onFall","onRiseHold","onFallHold","sticky"].indexOf(e.when)<0) throw "Unsupported Aura effect.";
   }
   var stateIds=new Map<String,Bool>();
   if(a.states!=null) for(st in list(a.states,"States",AuraStateDef.MAX_STATES)) {
    if(st==null || !Std.isOfType(st.id,String) || StringTools.trim(st.id).length==0 || stateIds.exists(st.id)) throw "Unsupported Aura state.";
    stateIds.set(st.id,true); validateRule(st.rule);
   }
   if(a.canvasElements!=null) for(el in list(a.canvasElements,"Canvas elements",4096)) {
    if(el==null || ["text","icon","shape","path"].indexOf(el.kind)<0 || !Std.isOfType(el.content,String)) throw "Unsupported canvas element.";
    validateRule(el.visibilityRule);
    if(el.kind=="path" && el.path!=null) { if(!Std.isOfType(el.path.n,Array)) throw "Unsupported vector path."; var rows:Array<Dynamic>=cast el.path.n; if(rows.length>AuraVectorPath.MAX_NODES) throw "Vector path has too many points."; }
    if(el.inStates!=null) { if(!Std.isOfType(el.inStates,Array)) throw "Unsupported canvas element states."; var refs:Array<Dynamic>=cast el.inStates; if(refs.length>AuraCanvasElement.MAX_STATE_REFS) throw "Too many state references."; }
   }
  }
 }
 /** Explicit image fields only. Text and script expressions are never searched or rewritten. */
 public static function visitImages(pack:Dynamic,visit:Dynamic->String->String->Void):Void {
  var auras:Array<Dynamic>=cast pack.auras;
  for(a in auras) {
   for(field in ["iconId","plate"]) { var value=Reflect.field(a,field); if(Std.isOfType(value,String) && StringTools.startsWith(value,CustomImageKey.PREFIX)) visit(a,field,value); }
   if(Std.isOfType(a.canvasElements,Array)) { var elements:Array<Dynamic>=cast a.canvasElements; for(el in elements) if(el!=null && el.kind=="icon" && Std.isOfType(el.content,String) && StringTools.startsWith(el.content,CustomImageKey.PREFIX)) visit(el,"content",el.content); }
  }
 }
 public static function dependencies(pack:Dynamic):Array<String> {
  var keys:Array<String>=[]; var seen=new Map<String,Bool>();
  visitImages(pack,function(_,_,key) {
   var stem=CustomImageKey.stemOf(key);
   if(stem.length==0 || stem.indexOf("/")>=0 || stem.indexOf("\\")>=0 || stem.indexOf("..")>=0 || stem.indexOf("\x00")>=0) throw "Invalid custom image reference: "+key;
   if(!seen.exists(key.toLowerCase())) { seen.set(key.toLowerCase(),true); keys.push(key); }
  });
  return keys;
 }
 public static function rewriteImages(pack:Dynamic,images:Array<AuraShareImage>):Void {
  var mapping=new Map<String,String>(); for(image in images) for(key in image.keys) mapping.set(key.toLowerCase(),CustomImageKey.key(CustomImageKey.managedStem(image.sha256)));
  visitImages(pack,function(object,field,key) { var next=mapping.get(key.toLowerCase()); if(next==null) throw "Missing bundled image: "+key; Reflect.setField(object,field,next); });
 }
 public static function validatePng(bytes:Bytes):{width:Int,height:Int} {
  if(bytes==null || bytes.length<33 || bytes.length>4*1024*1024) throw "PNG must be at most 4 MiB.";
  if(bytes.sub(0,8).toHex()!="89504e470d0a1a0a") throw "Not a PNG image.";
  var input=new BytesInput(bytes); input.bigEndian=true; input.position=8;
  var width=0; var height=0; var ended=false; var idat=new BytesOutput(); var chunks=0;
  while(input.position<bytes.length) {
   if(bytes.length-input.position<12) throw "Truncated PNG.";
   var length=input.readInt32(); var type=input.readString(4); var dataAt=input.position;
   if(length<0 || length>bytes.length-dataAt-4) throw "Invalid PNG chunk size.";
   input.position+=length; var crc=input.readInt32();
   if(Crc32.make(bytes.sub(dataAt-4,length+4))!=crc) throw "PNG checksum mismatch.";
   if(chunks++==0) {
    if(type!="IHDR" || length!=13) throw "Missing PNG header.";
    var head=new BytesInput(bytes.sub(dataAt,13)); head.bigEndian=true; width=head.readInt32(); height=head.readInt32();
    if(width<1 || height<1 || width>1024 || height>1024) throw "PNG dimensions must be 1..1024 pixels.";
   } else if(type=="IHDR") throw "Duplicate PNG header.";
   if(type=="IDAT") idat.write(bytes.sub(dataAt,length));
   if(type=="IEND") { if(length!=0 || input.position!=bytes.length) throw "Invalid PNG end marker."; ended=true; break; }
  }
  if(!ended || idat.length==0) throw "Incomplete PNG image.";
  // Bound inflation before the existing PNG decoder is allowed to process the stream.
  var compressed=idat.getBytes(); var bounded=Bytes.alloc(width*height*8+height*7+1024); var z=new haxe.zip.Uncompress(15);
  try { var result=z.execute(compressed,0,bounded,0); if(!result.done || result.read!=compressed.length) throw "PNG data exceeds its image bounds."; }
  catch(error:Dynamic) { z.close(); throw error; }
  z.close();
  var png=new Reader(new BytesInput(bytes)).read(); var header=Tools.getHeader(png);
  if(header.width!=width || header.height!=height) throw "Inconsistent PNG header.";
  var decoded=Tools.extract32(png);
  if(decoded.length!=width*height*4) throw "Invalid decoded PNG pixels.";
  return {width:width,height:height};
 }
 public static function imageRecords(manifest:Dynamic,pack:Dynamic,archive:AuraShareArchive):Array<AuraShareImage> {
  if(manifest==null || manifest.format!=FORMAT || manifest.version!=VERSION) throw "Unsupported Aura share version.";
  var images:Array<AuraShareImage>=[]; var hashes=new Map<String,Bool>(); var keys=new Map<String,Bool>();
  for(raw in list(manifest.images,"Images",256)) {
   if(raw==null || !Std.isOfType(raw.sha256,String) || !~/^[a-f0-9]{64}$/.match(raw.sha256) || hashes.exists(raw.sha256)
    || raw.entry!="images/"+raw.sha256+".png" || !Std.isOfType(raw.bytes,Int) || raw.bytes<1 || raw.bytes>4*1024*1024
    || !Std.isOfType(raw.width,Int) || !Std.isOfType(raw.height,Int) || raw.width<1 || raw.height<1 || raw.width>1024 || raw.height>1024) throw "Invalid image manifest.";
   var aliases:Array<String>=[];
   for(key in list(raw.keys,"Image aliases",8192)) {
    if(!Std.isOfType(key,String) || !StringTools.startsWith(key,"custom:") || keys.exists(key.toLowerCase())) throw "Invalid or duplicate image alias.";
    keys.set(key.toLowerCase(),true); aliases.push(key);
   }
   if(aliases.length==0) throw "Image has no references.";
   hashes.set(raw.sha256,true); images.push({sha256:raw.sha256,entry:raw.entry,bytes:raw.bytes,width:raw.width,height:raw.height,keys:aliases});
  }
  var dependencies=dependencies(pack);
  for(key in dependencies) if(!keys.exists(key.toLowerCase())) throw "Package is missing image: "+key;
  var used=new Map<String,Bool>(); for(key in dependencies) used.set(key.toLowerCase(),true);
  for(key in keys.keys()) if(!used.exists(key)) throw "Package contains an unreferenced image alias: "+key;
  if(archive.names.length!=images.length+2) throw "Share ZIP contains unlisted files.";
  for(image in images) if(archive.names.indexOf(image.entry)<0) throw "Missing image file: "+image.entry;
  return images;
 }
}
