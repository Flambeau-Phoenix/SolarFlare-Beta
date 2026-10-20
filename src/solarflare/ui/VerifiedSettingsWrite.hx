package solarflare.ui;

/** Windows rename transaction: preserve the original and roll it back on any failed replacement. */
class VerifiedSettingsWrite {
 static inline var RECOVERY_S:Float=300;
 static var lastRecoveryAt:Float=-1e9;
 /** `verified` is the parse of the bytes just read back from `tmp` by the caller; passing it skips re-reading and re-parsing megabytes. */
 public static function replace(tmp:String,path:String,rename:String->String->Void=null,verified:Dynamic=null):Void {
  if(verified==null) { var staged=sys.io.File.getContent(tmp); haxe.Json.parse(staged); }
  var original=sys.FileSystem.exists(path) ? sys.io.File.getBytes(path) : null;
  var recovery=original==null ? "" : path+".write-v35.prev";
  // The in-memory original already rolls back a failed rename and the verified .tmp survives a crash, so the
  // on-disk recovery copy is refreshed on a long interval instead of with every save (rung 4 safety net).
  if(original!=null && (!sys.FileSystem.exists(recovery) || haxe.Timer.stamp()-lastRecoveryAt>=RECOVERY_S)) {
   sys.io.File.saveBytes(recovery,original);
   if(sys.io.File.getBytes(recovery).compare(original)!=0) throw "Settings recovery verification failed";
   lastRecoveryAt=haxe.Timer.stamp();
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
