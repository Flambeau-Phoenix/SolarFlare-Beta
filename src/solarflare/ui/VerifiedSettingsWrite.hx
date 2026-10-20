package solarflare.ui;

/** Windows rename transaction: preserve the original and roll it back on any failed replacement. */
class VerifiedSettingsWrite {
 public static function replace(tmp:String,path:String,rename:String->String->Void=null):Void {
  var staged=sys.io.File.getContent(tmp); haxe.Json.parse(staged);
  var original=sys.FileSystem.exists(path) ? sys.io.File.getBytes(path) : null;
  var recovery=original==null ? "" : path+".write-v35.prev";
  if(original!=null) {
   sys.io.File.saveBytes(recovery,original);
   if(sys.io.File.getBytes(recovery).compare(original)!=0) throw "Settings recovery verification failed";
  }
  try {
   if(original!=null) sys.FileSystem.deleteFile(path);
   if(rename==null) sys.FileSystem.rename(tmp,path); else rename(tmp,path);
  } catch(e:Dynamic) {
   if(original!=null) sys.io.File.saveBytes(path,original);
   throw e;
  }
 }
}
