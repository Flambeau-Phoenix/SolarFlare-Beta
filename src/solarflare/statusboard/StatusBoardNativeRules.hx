package solarflare.statusboard;

/** Frozen during observation, never queried by a renderer. */
class StatusBoardNativeRules {
 static var debugRead:Bool=false;
 static var debugStacks:Bool=false;
 public static function beginPass():Void { debugRead=false; debugStacks=false; }
 public static function stacks(item:Dynamic,count:Int):Bool {
  if (!debugRead) {
   debugRead=true;
   #if hl
   try { var prefs=Config.prefs; debugStacks=prefs != null && prefs.skillsDebug; } catch (_:Dynamic) {}
   #end
  }
  if (debugStacks) return true;
  if (count<=1) return false;
  try { var status:st.skill.Status=item; return status.get_stackingPolicy()!=1; } catch (_:Dynamic) { return false; }
 }
}
