package solarflare.statusboard;

/** Same pure text path as TipSkill, using the applied status and its real source context. */
class StatusBoardNativeText {
 #if hl
 static var objectTypes:Map<String,hl.Type>=new Map();
 public static function isObject(source:Dynamic,name:String):Bool {
  if (source == null) return false;
  try {
   var t=hl.Type.getDynamic(source);
   var cached=objectTypes.get(name);
   if (cached != null) return t.safeCast(cached);
   var depth=0;
   while (t.kind == hl.Type.TypeKind.HObj && depth++<16) {
    if (t.getTypeName() == name) { objectTypes.set(name,t); return true; }
    t=t.getSuper();
   }
  } catch (_:Dynamic) {}
  return false;
 }
 #end
 /** Only reject definition-backed missing-key sentinels; bracketed prose is valid. */
 public static function meaningful(text:String,id:String,raw:String=""):Bool {
  if (text == null) return false;
  var plain=StringTools.trim(StatusBoardText.plain(StatusBoardText.parse(text)));
  if (plain.length == 0) return false;
  return !((id.length>0 && plain=="["+id+"]") || (raw != null && raw.length>0 && plain=="["+raw+"]"));
 }
 public static function fallback(label:String,id:String=""):String {
  return meaningful(label,id) && label != id ? label : StatusBoardTooltipLabels.status;
 }
 static function escaped(text:String):String return StringTools.htmlEscape(text);
 public static function read(item:Dynamic,hero:Dynamic,fallbackTitle:String=""):{title:String,description:String,caption:String,statusId:String,sourceItemId:String,resolution:String,failed:Bool,locale:String} {
  try {
   StatusBoardTooltipLabels.refresh();
   #if hl
   if (!isObject(item,"st.skill.Status")) return null;
   #end
   var status:st.skill.Status=item;
   if (status.removed) return null;
   var info=status.getStatusInfo();
   var source:Dynamic=status.getSourceObject();
   #if (hl || status_tooltip_native_test)
   #if hl
   if (!isObject(source,"ent.Unit")) source=hero;
   #else
   if (source == null) source=hero;
   #end
   var inf:Dynamic=solarflare.FieldWalk.extractObject(item,"inf");
   if (inf == null || info == null) return null;
   var definition:Dynamic={inf:inf,rank:info.rank,maxRank:info.maxRank,masteries:info.masteries,heroic:false};
   var base:st.skill.BaseSkill=item;
   var sourceItem:Dynamic=info.sourceItem;
   if (sourceItem == null) try { sourceItem=base.getSourceItem(); } catch (_:Dynamic) {}
   #if hl
   var hasDetails=false;
   var details=new hl.Ref<Bool>(hasDetails);
   #else
   var details:Dynamic=null;
   #end
   var name=""; var failed=false;
   try { name=solarflare.ui.ByteUtil.materialize(HText.skill(cast definition,ETextKind.Name,cast source,details,base,cast sourceItem)); } catch (_:Dynamic) { failed=true; }
   #if hl
   details.set(false);
   #end
   var description="";
   try { description=solarflare.ui.ByteUtil.materialize(HText.skill(cast definition,ETextKind.Desc,cast source,details,base,cast sourceItem)); } catch (_:Dynamic) { failed=true; }
   var caption="";
   if (info.rank>1) try { caption=solarflare.ui.ByteUtil.materialize(Texts.skill_rank({rank:info.rank})); } catch (_:Dynamic) {}
   #else
   if (source == null) source=hero;
   var inf:Dynamic=status.inf;
   var sourceItem:Dynamic=status.sourceItem;
   var failed=false;
   var name=HText.statusName(status,info,source);
   var description=""; try { description=HText.statusDescription(status,info,source); } catch (_:Dynamic) { failed=true; }
   var caption=info.rank>1 ? "Rank "+info.rank : "";
   #end
   var id=solarflare.FieldWalk.extractString(inf,"id");
   var texts=solarflare.FieldWalk.extractObject(inf,"texts");
   var rawName=solarflare.FieldWalk.extractString(texts,"name");
   var rawDesc=solarflare.FieldWalk.extractString(texts,"desc");
   var script=solarflare.FieldWalk.extractString(inf,"script");
   var title=meaningful(name,id,rawName) && meaningful(name,script) ? StatusBoardText.plain(StatusBoardText.parse(name)) : "";
   if (!meaningful(description,id,rawDesc) || !meaningful(description,script)) description="";
   var itemText=StatusBoardItemText.read(sourceItem);
   // A definition association is a fallback only when the catalog proves uniqueness.
   if (sourceItem == null && title.length==0) {
    var entry=solarflare.cdb.ConsumableCatalog.findByStatus(id);
    if (entry != null) title=entry.name;
   }
   if (title.length==0) title=itemText.title.length>0 ? itemText.title : fallback(fallbackTitle,id);
   var resolution=description.length>0 ? "status" : "missing";
   if (itemText.title.length>0 || itemText.description.length>0) {
    var section="<b>"+escaped(StatusBoardTooltipLabels.source);
    if (itemText.title.length>0) section+=": "+escaped(itemText.title);
    section+="</b>";
    if (itemText.description.length>0) section+="\n"+itemText.description;
    if (description.length>0) description="<b>"+escaped(StatusBoardTooltipLabels.active)+"</b>\n"+description+"\n\n"+section;
    else description=section;
    if (itemText.description.length>0) resolution=resolution=="status" ? "status_and_item" : "item";
   }
   if (resolution=="missing") description+=(description.length>0 ? "\n" : "")+escaped(StatusBoardTooltipLabels.unavailable);
   return {title:title,description:description,caption:caption,statusId:id,sourceItemId:itemText.id,resolution:resolution,failed:failed || itemText.failed,locale:StatusBoardTooltipLabels.locale};
  } catch (_:Dynamic) { return null; }
 }
}
