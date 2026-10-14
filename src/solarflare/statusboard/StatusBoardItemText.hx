package solarflare.statusboard;

/** Read-only native item description composition, without constructing a TipItem UI. */
class StatusBoardItemText {
 public static inline var MAX_EFFECTS:Int=32;
 public static inline var MAX_AFFIXES:Int=128;
 public static function read(source:Dynamic):{id:String,title:String,description:String,failed:Bool} {
  var out={id:"",title:"",description:"",failed:false};
  if (source == null) return out;
  #if (hl || status_tooltip_native_test)
  #if hl
  if (!StatusBoardNativeText.isObject(source,"st.Item")) { out.failed=true; return out; }
  #end
  var item:st.Item=cast source;
  try { out.id=solarflare.EngineText.cleanId(item.kind); } catch (_:Dynamic) { out.failed=true; }
  try { out.title=solarflare.ui.ByteUtil.materialize(item.getName()); } catch (_:Dynamic) { out.failed=true; }
  try {
   var def=item.getDef();
   try { out.description=solarflare.ui.ByteUtil.materialize(HText.item(def,ETextKind.Desc,null)); } catch (_:Dynamic) { out.failed=true; }
   if (!StatusBoardNativeText.meaningful(out.description,out.id,def == null || def.texts == null ? "" : def.texts.desc)) out.description="";
   // TipItem.getDescription uses displayed item affixes for generated effect descriptions.
   if (out.description.length == 0 && def != null && def.props != null && def.props.effects != null) {
    var effects=def.props.effects;
    #if hl
    var displayed=new hl.types.ArrayObj<Dynamic>();
    #else
    var displayed:Array<Dynamic>=[];
    #end
    var affixes=item.getItemAffixes();
    var n=solarflare.FieldWalk.arrayLen(affixes,0);
    if (n>MAX_AFFIXES) { out.failed=true; return out; }
    for (i in 0...n) {
     var a=solarflare.FieldWalk.arrayAt(affixes,i);
     if (solarflare.FieldWalk.extractObject(a,"displayed") == true) {
      #if hl
      displayed.pushDyn(a);
      #else
      displayed.push(a);
      #end
     }
    }
    n=solarflare.FieldWalk.arrayLen(effects,0);
    if (n>MAX_EFFECTS) { out.failed=true; return out; }
    for (i in 0...n) {
     var effect=solarflare.FieldWalk.arrayAt(effects,i);
     if (effect == null) continue;
     var text=solarflare.ui.ByteUtil.materialize(HText.itemEffect(displayed,cast effect));
     if (StatusBoardNativeText.meaningful(text,out.id)) out.description+=(out.description.length>0 ? "\n" : "")+text;
    }
   }
  } catch (_:Dynamic) { out.failed=true; }
  #else
  out.id=solarflare.FieldWalk.extractString(source,"kind",solarflare.FieldWalk.extractString(source,"id"));
  out.title=solarflare.FieldWalk.extractString(source,"name");
  out.description=solarflare.FieldWalk.extractString(source,"description");
  #end
  out.title=StatusBoardText.plain(StatusBoardText.parse(out.title));
  if (!StatusBoardNativeText.meaningful(out.title,out.id)) out.title="";
  return out;
 }
}
