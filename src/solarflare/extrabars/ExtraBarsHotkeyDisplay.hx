package solarflare.extrabars;

/** Display preference only. Never changes activation routes or captured bindings. */
class ExtraBarsHotkeyDisplay {
 public static var options(default,null):Array<String> = ["auto","native","extrabars","both"];
 public static function clean(value:String):String return options.indexOf(value) >= 0 ? value : "auto";
 public static function label(value:String):String return switch(value) {
  case "auto": "Automatic"; case "extrabars": "ExtraBars"; case "both": "Both"; default: "Native";
 };
 public static function apply(slot:ExtraBarsPrototypeSlot, mode:String, nativeText:String, nativeState:String, action:String, extra:String):Void {
  mode=clean(mode);
  if (slot.displayMode == mode && slot.displayNativeText == nativeText && slot.displayNativeState == nativeState
   && slot.displayNativeAction == action && slot.displayExtraHint == extra && slot.displayExtraBinding == slot.binding) {
   slot.keyHint=slot.displayPrimary; slot.secondaryKeyHint=slot.displaySecondary; slot.binding=slot.displayTooltip; return;
  }
  slot.displayMode=mode; slot.displayNativeText=nativeText; slot.displayNativeState=nativeState;
  slot.displayNativeAction=action; slot.displayExtraHint=extra; slot.displayExtraBinding=slot.binding;
  var nativeHint=nativeState == "bound" ? nativeText : nativeState == "unreadable" ? "Unknown" : "";
  slot.nativeKeyHint=nativeHint;
  slot.extraKeyHint=extra;
  slot.secondaryKeyHint="";
  switch(clean(mode)) {
   case "auto": slot.keyHint=nativeState=="bound" ? nativeHint : extra;
   case "extrabars": slot.keyHint=extra;
   case "both":
    slot.keyHint=nativeHint.length > 0 ? "N:"+nativeHint : "";
    slot.secondaryKeyHint=extra.length > 0 ? "E:"+extra : "";
   default: slot.keyHint=nativeHint;
  }
  slot.displayPrimary=slot.keyHint; slot.displaySecondary=slot.secondaryKeyHint;
  slot.binding="Native: "+nativeText+(action.length > 0 ? " ("+action+")" : "")+"\nExtraBars: "+slot.binding;
  slot.displayTooltip=slot.binding;
 }
}
