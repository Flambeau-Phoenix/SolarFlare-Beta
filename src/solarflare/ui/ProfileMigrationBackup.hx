package solarflare.ui;

/** Never overwrite recovery copies. Verify exact bytes as well as JSON before allowing migration. */
class ProfileMigrationBackup {
 public static function ensure(source:String):String {
  if(source==null || !sys.FileSystem.exists(source)) throw "Missing migration source";
  var bytes=sys.io.File.getBytes(source); haxe.Json.parse(bytes.toString());
  var digest=haxe.crypto.Sha256.make(bytes).toHex();
  var target=source+".profiles-v35-"+digest+".bak";
  if(!sys.FileSystem.exists(target)) sys.io.File.saveBytes(target,bytes);
  var saved=sys.io.File.getBytes(target);
  if(saved.compare(bytes)!=0) throw "Profile migration backup verification failed";
  haxe.Json.parse(saved.toString()); return target;
 }
}
