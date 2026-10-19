package solarflare.aura;

import haxe.io.Bytes;
import haxe.io.Path;
import haxe.zip.Writer;
import haxe.zip.Entry;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileOutput;
import solarflare.ui.CustomImages;
import solarflare.ui.CustomImageKey;
import solarflare.aura.AuraSharePackage.AuraShareImage;

/** Cooperative observation jobs: at most one PNG is validated, written or installed per tick. */
class AuraShareService {
 public var busy(default,null):Bool=false;
 public var error(default,null):Bool=false;
 public var status(default,null):String="Export a creation with its images, or choose a share ZIP to import.";
 public var folder(default,null):String="aura_shares";
 public var files(default,null):Array<String>=[];
 public var summary(default,null):String="";
 public var selectedPath(default,null):String="";
 public var lastExport(default,null):String="";
 public var progress(default,null):Float=0;
 var operation:String="";
 var phase:String="";
 var refreshWanted=false;
 var cancelled=false;
 var lifetime:Void->Bool;
 var preflight:Dynamic->Void;
 var publish:Dynamic->Void;
 var pack:Dynamic;
 var images:Array<AuraShareImage>=[];
 var imageBytes=new Map<String,Bytes>();
 var references:Array<String>=[];
 var cursor=0;
 var totalBytes=0;
 var archive:AuraShareArchive;
 var staging:String;
 var created:Array<String>=[];
 var output:FileOutput;
 var writer:Writer;
 var archivePath:String;
 var managedPath:String;
 static var sequence=0;
 public function new() {}
 function root():String { folder=CustomImages.shareDir(); return folder; }
 static function ensure(path:String):Void {
  if(!FileSystem.exists(path)) FileSystem.createDirectory(path);
  if(!FileSystem.isDirectory(path)) throw "A folder is required: "+path;
 }
 public function requestRefresh():Void refreshWanted=true;
 public function cancel():Void cancelled=true;
 public function choose(path:String):Void { if(busy) throw "A share operation is already running."; selectedPath=cleanPath(path); summary=""; }
 public static function cleanPath(path:String):String {
  var value=path==null ? "" : StringTools.trim(path);
  if(value.length>=2 && value.charAt(0)=='"' && value.charAt(value.length-1)=='"') value=value.substr(1,value.length-2);
  return value;
 }
 function start(kind:String,alive:Void->Bool):Void {
  if(busy) throw "A share operation is already running.";
  operation=kind; phase="start"; busy=true; cancelled=false; error=false; progress=0; status="Preparing "+kind+"...";
  lifetime=alive; images=[]; imageBytes.clear(); references=[]; cursor=0; totalBytes=0; archive=null; created=[];
 }
 public function requestExport(snapshot:Dynamic,alive:Void->Bool=null):Void {
  if(busy) throw "A share operation is already running.";
  var copy=AuraSharePackage.clone(snapshot);
  start("export",alive); pack=copy; summary="";
 }
 public function requestInspect(path:String,check:Dynamic->Void=null,alive:Void->Bool=null):Void {
  if(busy) throw "A share operation is already running.";
  choose(path); start("inspect",alive); preflight=check; publish=null;
 }
 public function requestImport(path:String,check:Dynamic->Void,commit:Dynamic->Void,alive:Void->Bool=null):Void {
  if(busy) throw "A share operation is already running.";
  choose(path); start("import",alive); preflight=check; publish=commit;
 }
 function refreshFiles():Void {
  refreshWanted=false; ensure(root());
  var next:Array<String>=[];
  for(name in FileSystem.readDirectory(folder)) if(Path.extension(name).toLowerCase()=="zip" && !FileSystem.isDirectory(Path.join([folder,name]))) next.push(name);
  next.sort(Reflect.compare); files=next;
 }
 public function observe():Void {
  if(!busy) {
   if(refreshWanted) try refreshFiles() catch(e:Dynamic) { error=true; status=Std.string(e); }
   return;
  }
  try {
   if(cancelled || (lifetime!=null && !lifetime())) { cleanup(); finish("Share operation cancelled.",false); return; }
   if(operation=="export") exportStep(); else importStep();
  } catch(e:Dynamic) {
   var message=Std.string(e);
   try cleanup() catch(cleanupError:Dynamic) message+=" Cleanup could not finish: "+Std.string(cleanupError);
   finish(message,true);
  }
 }
 function beginStaging():Void {
  ensure(root()); var parent=Path.join([folder,"_staging"]); ensure(parent);
  do { staging=Path.join([parent,"share_"+Std.int(Date.now().getTime()/1000)+"_"+(sequence++)]); } while(FileSystem.exists(staging));
  ensure(staging);
 }
 function exportStep():Void {
  switch(phase) {
   case "start":
    AuraSharePackage.validatePack(pack); references=AuraSharePackage.dependencies(pack);
    beginStaging(); phase="collect";
   case "collect":
    if(cursor<references.length) {
     var key=references[cursor++]; var path=CustomImages.pathFor(CustomImageKey.stemOf(key));
     if(path==null) throw "Missing custom image: "+key;
     if(FileSystem.stat(path).size>4*1024*1024) throw "Image exceeds 4 MiB: "+key;
     var bytes=File.getBytes(path); var dimensions;
     try dimensions=AuraSharePackage.validatePng(bytes) catch(e:Dynamic) throw key+": "+Std.string(e);
     var hash=AuraSharePackage.hash(bytes); var existing:AuraShareImage=null;
     for(image in images) if(image.sha256==hash) { existing=image; break; }
     if(existing!=null) existing.keys.push(key);
     else {
      if(images.length>=256) throw "Share packages support at most 256 unique PNGs.";
      totalBytes+=bytes.length; if(totalBytes>AuraShareArchive.MAX_BYTES) throw "Share contents exceed 64 MiB.";
      images.push({sha256:hash,entry:"images/"+hash+".png",bytes:bytes.length,width:dimensions.width,height:dimensions.height,keys:[key]});
      imageBytes.set(hash,bytes);
     }
     status="Collecting image "+cursor+" / "+references.length; progress=references.length==0 ? 0.4 : cursor/references.length*0.45;
    } else phase="write";
   case "write":
    var auraBytes=Bytes.ofString(haxe.Json.stringify(pack));
    var manifest=Bytes.ofString(haxe.Json.stringify({format:AuraSharePackage.FORMAT,version:AuraSharePackage.VERSION,name:pack.name,aurasSha256:AuraSharePackage.hash(auraBytes),images:images}));
    if(auraBytes.length>AuraShareArchive.MAX_JSON || manifest.length>AuraShareArchive.MAX_JSON || totalBytes+auraBytes.length+manifest.length>AuraShareArchive.MAX_BYTES) throw "Share definitions or contents exceed their size limit.";
    archivePath=Path.join([staging,"package.zip"]); output=File.write(archivePath,true); writer=new Writer(output);
    writeEntry("manifest.json",manifest); writeEntry("auras.json",auraBytes); cursor=0; phase="writeImages";
   case "writeImages":
    if(cursor<images.length) {
     var image=images[cursor++]; writeEntry(image.entry,imageBytes.get(image.sha256));
     imageBytes.remove(image.sha256); progress=0.45+0.45*cursor/Math.max(1,images.length);
     status="Writing image "+cursor+" / "+images.length;
    } else {
     writer.writeCDR(); output.close(); output=null; writer=null;
     if(FileSystem.stat(archivePath).size>AuraShareArchive.MAX_BYTES) throw "Share archive exceeds 64 MiB.";
     var base=sanitize(pack.name)+"-"+DateTools.format(Date.now(),"%Y%m%d-%H%M%S"); var name=base+".zip"; var n=2;
     while(FileSystem.exists(Path.join([root(),name]))) name=base+"-"+(n++)+".zip";
     var destination=Path.join([folder,name]); FileSystem.rename(archivePath,destination); lastExport=destination; selectedPath=destination;
     cleanup(); refreshWanted=true; finish("Exported "+pack.auras.length+" Aura(s) and "+images.length+" image(s): "+name,false);
    }
   default: throw "Invalid share export state.";
  }
 }
 function writeEntry(name:String,bytes:Bytes):Void {
  var entry:Entry={fileName:name,fileSize:bytes.length,fileTime:Date.now(),compressed:false,dataSize:bytes.length,data:bytes,crc32:null};
  writer.writeEntryHeader(entry); output.writeFullBytes(bytes,0,bytes.length);
 }
 function importStep():Void {
  switch(phase) {
   case "start":
    if(selectedPath.length==0 || !FileSystem.exists(selectedPath) || FileSystem.isDirectory(selectedPath)) throw "Choose an existing share ZIP file.";
    if(Path.extension(selectedPath).toLowerCase()!="zip" || FileSystem.stat(selectedPath).size>AuraShareArchive.MAX_BYTES) throw "Choose a share ZIP no larger than 64 MiB.";
    archive=new AuraShareArchive(File.getBytes(selectedPath));
    var manifest=AuraSharePackage.json(archive.read("manifest.json")); var auraBytes=archive.read("auras.json");
    if(manifest==null || manifest.aurasSha256!=AuraSharePackage.hash(auraBytes)) throw "Aura definitions checksum mismatch.";
    pack=AuraSharePackage.json(auraBytes); AuraSharePackage.validatePack(pack);
    images=AuraSharePackage.imageRecords(manifest,pack,archive);
    summary=Std.string(pack.name)+": "+images.length+" PNG(s). Requires "+pack.auras.length+" Aura, "+pack.groups.length+" group and "+pack.sets.length+" set slot(s).";
    if(preflight!=null) preflight(pack);
    phase="validate"; status="Validating bundled images...";
   case "validate":
    if(cursor<images.length) {
     var image=images[cursor++]; var bytes=archive.read(image.entry);
     if(bytes.length!=image.bytes || AuraSharePackage.hash(bytes)!=image.sha256) throw "Image checksum mismatch: "+image.entry;
     var dimensions=AuraSharePackage.validatePng(bytes);
     if(dimensions.width!=image.width || dimensions.height!=image.height) throw "Image dimensions do not match the manifest.";
     if(operation=="import") imageBytes.set(image.sha256,bytes);
     progress=0.5*cursor/Math.max(1,images.length); status="Validated image "+cursor+" / "+images.length;
    } else if(operation=="inspect") finish("Package validated. "+summary,false);
    else { AuraSharePackage.rewriteImages(pack,images); beginStaging(); cursor=0; phase="stage"; }
   case "stage":
    if(cursor<images.length) {
     var image=images[cursor++]; File.saveBytes(Path.join([staging,image.sha256+".png"]),imageBytes.get(image.sha256));
     imageBytes.remove(image.sha256); progress=0.5+0.2*cursor/Math.max(1,images.length);
    } else { managedPath=Path.join([folder,"_assets"]); ensure(managedPath); cursor=0; phase="install"; }
   case "install":
    if(cursor<images.length) {
     var image=images[cursor++]; var destination=Path.join([managedPath,CustomImageKey.managedStem(image.sha256)+".png"]);
     if(FileSystem.exists(destination)) {
      if(FileSystem.isDirectory(destination) || FileSystem.stat(destination).size!=image.bytes || AuraSharePackage.hash(File.getBytes(destination))!=image.sha256) throw "A managed image is damaged; no existing file was overwritten.";
     } else {
      FileSystem.rename(Path.join([staging,image.sha256+".png"]),destination); created.push(destination);
     }
     progress=0.7+0.25*cursor/Math.max(1,images.length);
    } else {
     if(preflight!=null) preflight(pack);
     if(publish==null) throw "No import destination is available.";
     // All failures before this boundary roll back new files. The callback publishes a prepared transaction.
     cleanup(false);
     publish(pack); created.resize(0); CustomImages.requestRefresh();
     finish("Imported "+pack.auras.length+" Aura(s) with all bundled images.",false);
    }
   default: throw "Invalid share import state.";
  }
 }
 function finish(message:String,failed:Bool):Void {
  status=message; error=failed; busy=false; progress=failed ? 0 : 1;
  archive=null; pack=null; imageBytes.clear(); references=[]; lifetime=null; preflight=null; publish=null; operation=""; phase="";
 }
 function cleanup(deleteCreated:Bool=true):Void {
  if(output!=null) { output.close(); output=null; writer=null; }
  if(deleteCreated) {
   for(path in created) if(FileSystem.exists(path) && !FileSystem.isDirectory(path)) FileSystem.deleteFile(path);
   created.resize(0);
  }
  if(staging!=null && FileSystem.exists(staging)) {
   // Only flat files generated by this job; never recursively delete caller or archive paths.
   for(name in FileSystem.readDirectory(staging)) {
    var path=Path.join([staging,name]); if(FileSystem.isDirectory(path)) throw "Unexpected directory in share staging.";
    FileSystem.deleteFile(path);
   }
   FileSystem.deleteDirectory(staging);
  }
  staging=null; archivePath=null;
 }
 static function sanitize(value:String):String {
  var text=value==null ? "Aura" : value; var buffer=new StringBuf();
  for(i in 0...text.length) { var c=text.charCodeAt(i); buffer.add((c>=48 && c<=57)||(c>=65 && c<=90)||(c>=97 && c<=122)||c==45||c==95 ? text.charAt(i) : "_"); }
  var name=buffer.toString().substr(0,64); return name.length==0 ? "Aura" : name;
 }
}
