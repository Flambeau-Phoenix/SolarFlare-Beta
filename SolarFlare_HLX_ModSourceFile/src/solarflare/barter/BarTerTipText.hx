package solarflare.barter;

import solarflare.FieldWalk;
import solarflare.cdb.ConsumableCatalog;
import solarflare.statusboard.StatusBoardNativeText;
import solarflare.statusboard.StatusBoardText;
import solarflare.statusboard.StatusBoardTooltipLabels;
import solarflare.statusboard.StatusBoardItemText;

typedef BarTerTip = {title:String,description:String,caption:String,resolution:String,failed:Bool,locale:String};

/**
 * Observer-side description resolvers for BarTer skill and consumable cells. Same game text path as the
 * status board (HText through StatusBoardNativeText); never called from draw, never stores engine pointers.
 */
class BarTerTipText {
 static function escaped(text:String):String return StringTools.htmlEscape(text);
 static function missing(title:String,failed:Bool):BarTerTip
  return {title:title,description:escaped(StatusBoardTooltipLabels.unavailable),caption:"",resolution:"missing",failed:failed,locale:StatusBoardTooltipLabels.locale};

 /**
  * `native` is the live skill for the cell when one is in hand (rank-aware text); otherwise the skill renders by id from
  * its CDB row, the same call the Dev Log skill-text dump used for every skill. `hero` is the formatter's source unit.
  */
 public static function skill(native:Dynamic,id:String,label:String,hero:Dynamic):BarTerTip {
  StatusBoardTooltipLabels.refresh();
  #if (hl || status_tooltip_native_test)
  if (native == null) return skillById(id,label,hero);
  try {
   #if hl
   if (!StatusBoardNativeText.isObject(native,"st.skill.BaseSkill")) return skillFallback(id,label,hero);
   #end
   var base:st.skill.BaseSkill=native;
   var info:Dynamic=base.getSkillInfo();
   var inf:Dynamic=FieldWalk.extractObject(native,"inf");
   if (inf == null || info == null) return skillFallback(id,label,hero);
   var text=StatusBoardNativeText.skillText(base,inf,info,hero,FieldWalk.extractObject(info,"heroic") == true);
   var id=FieldWalk.extractString(inf,"id");
   var texts=FieldWalk.extractObject(inf,"texts");
   var rawName=FieldWalk.extractString(texts,"name");
   var rawDesc=FieldWalk.extractString(texts,"desc");
   var script=FieldWalk.extractString(inf,"script");
   var title=StatusBoardNativeText.meaningful(text.name,id,rawName) && StatusBoardNativeText.meaningful(text.name,script) ? StatusBoardText.plain(StatusBoardText.parse(text.name)) : "";
   if (title.length == 0) title=label;
   var description=text.description;
   if (!StatusBoardNativeText.meaningful(description,id,rawDesc) || !StatusBoardNativeText.meaningful(description,script)) description="";
   var resolution=description.length>0 ? "skill" : "missing";
   if (description.length == 0) return skillFallback(id,label,hero,text.failed);
   return {title:title,description:description,caption:text.caption,resolution:resolution,failed:text.failed,locale:StatusBoardTooltipLabels.locale};
  } catch (_:Dynamic) { return skillFallback(id,label,hero); }
  #else
  return missing(label,false);
  #end
 }

 static function skillFallback(id:String,label:String,hero:Dynamic,failed:Bool=true):BarTerTip {
  var result=skillById(id,label,hero);
  if (result.resolution == "missing") result.failed=result.failed || failed;
  return result;
 }

 /** Rank 1 text for any CDB skill id, with no skill instance or item (ground truth: SkillTextDump, 1098 skills, 0 errors). */
 static function skillById(id:String,label:String,hero:Dynamic):BarTerTip {
  #if (hl || status_tooltip_native_test)
  try {
   // Retain the generated IndexId/StringMap wrappers: raw Dynamic.get bypasses HLX.
   var row:Dynamic=Data.skill.byId.get(id);
   if (row == null) return missing(label,false);
   // masteries must be an object array at runtime: a bare [] is an ArrayDyn and the engine's cast aborts.
   var masteries:Array<String>=[];
   var definition:Dynamic={inf:row,heroic:false,masteries:masteries,maxRank:1,rank:1};
   var name=solarflare.ui.ByteUtil.materialize(HText.skill(definition,ETextKind.Name,null,null,null,null));
   var description:String=null;
   try { description=solarflare.ui.ByteUtil.materialize(HText.skill(definition,ETextKind.Desc,hero,null,null,null)); }
   catch (_:Dynamic) { description=solarflare.ui.ByteUtil.materialize(HText.skill(definition,ETextKind.Desc,null,null,null,null)); }
   var rowId=FieldWalk.extractString(row,"id");
   var texts=FieldWalk.extractObject(row,"texts");
   var rawName=FieldWalk.extractString(texts,"name");
   var rawDesc=FieldWalk.extractString(texts,"desc");
   var title=StatusBoardNativeText.meaningful(name,rowId,rawName) ? StatusBoardText.plain(StatusBoardText.parse(name)) : "";
   if (title.length == 0) title=label;
   if (!StatusBoardNativeText.meaningful(description,rowId,rawDesc)) description="";
   if (description.length == 0) return {title:title,description:escaped(StatusBoardTooltipLabels.unavailable),caption:"",resolution:"missing",failed:false,locale:StatusBoardTooltipLabels.locale};
   return {title:title,description:description,caption:"",resolution:"cdb",failed:false,locale:StatusBoardTooltipLabels.locale};
  } catch (_:Dynamic) { return missing(label,true); }
  #else
  return missing(label,false);
  #end
 }

 /** Id text first; real carried items also supply descriptions generated from displayed effects. */
 public static function item(kind:String,label:String,native:Dynamic=null):BarTerTip {
  StatusBoardTooltipLabels.refresh();
  var entry=ConsumableCatalog.find(kind);
  var title=entry != null ? entry.name : label.length>0 ? label : kind;
  var description=""; var failed=false;
  #if (hl || status_tooltip_native_test)
  var rawName=""; var rawDesc="";
  try {
   var definition:Dynamic=Data.item.byId.get(kind);
   var texts=FieldWalk.extractObject(definition,"texts");
   rawName=FieldWalk.extractString(texts,"name"); rawDesc=FieldWalk.extractString(texts,"desc");
  } catch (_:Dynamic) { failed=true; }
  try {
   var name=solarflare.ui.ByteUtil.materialize(HText.itemById(kind,ETextKind.Name));
   if (StatusBoardNativeText.meaningful(name,kind,rawName)) title=StatusBoardText.plain(StatusBoardText.parse(name));
  } catch (_:Dynamic) { failed=true; }
  try { description=solarflare.ui.ByteUtil.materialize(HText.itemById(kind,ETextKind.Desc)); } catch (_:Dynamic) { failed=true; }
  if (!StatusBoardNativeText.meaningful(description,kind,rawDesc)) description="";
  if (description.length == 0 && native != null) {
   var source=StatusBoardItemText.read(native);
   if (source.id == kind && source.description.length>0) {
    description=source.description; failed=source.failed;
    if (source.title.length>0) title=source.title;
   }
  }
  #end
  var resolution=description.length>0 ? "item" : "missing";
  // Authored effect durations are static catalog facts; they stay useful when the game text is empty.
  var durations:Array<String>=[];
  if (entry != null) for (effect in entry.statuses) if (effect.duration>0) {
   var shown=StatusBoardText.duration(effect.duration);
   if (durations.indexOf(shown)<0) durations.push(shown);
  }
  if (durations.length>0) {
   description+=(description.length>0 ? "\n\n" : "")+"<b>"+escaped(StatusBoardTooltipLabels.duration)+"</b>: "+escaped(durations.join(" / "));
   if (resolution == "missing") resolution="catalog";
  }
  if (resolution == "missing") description=escaped(StatusBoardTooltipLabels.unavailable);
  return {title:title,description:description,caption:"",resolution:resolution,failed:failed,locale:StatusBoardTooltipLabels.locale};
 }
}
