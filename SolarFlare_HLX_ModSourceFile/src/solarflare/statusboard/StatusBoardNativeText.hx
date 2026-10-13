package solarflare.statusboard;

/** Same pure text path as TipSkill, using the applied status and its real source context. */
class StatusBoardNativeText {
 #if hl
 static var unitType:hl.Type;
 static function isUnit(source:Dynamic):Bool {
  if (source == null) return false;
  try {
   var t=hl.Type.getDynamic(source);
   if (unitType != null) return t.safeCast(unitType);
   var depth=0;
   while (t.kind == hl.Type.TypeKind.HObj && depth++<16) {
    if (t.getTypeName() == "ent.Unit") { unitType=t; return true; }
    t=t.getSuper();
   }
  } catch (_:Dynamic) {}
  return false;
 }
 #end
 public static function read(item:Dynamic,hero:Dynamic):{title:String,description:String,caption:String} {
  try {
   var status:st.skill.Status=item;
   if (status.removed) return null;
   var info=status.getStatusInfo();
   var source:Dynamic=status.getSourceObject();
   #if hl
   if (!isUnit(source)) source=hero;
   var inf:Dynamic=solarflare.FieldWalk.extractObject(item,"inf");
   if (inf == null || info == null) return null;
   var definition:Dynamic={inf:inf,rank:info.rank,maxRank:info.maxRank,masteries:info.masteries,heroic:false};
   var base:st.skill.BaseSkill=item;
   var sourceItem=base.getSourceItem();
   var hasDetails=false;
   var details=new hl.Ref<Bool>(hasDetails);
   var name=solarflare.ui.ByteUtil.materialize(HText.skill(cast definition,ETextKind.Name,cast source,details,base,sourceItem));
   details.set(false);
   var description="";
   try { description=solarflare.ui.ByteUtil.materialize(HText.skill(cast definition,ETextKind.Desc,cast source,details,base,sourceItem)); } catch (_:Dynamic) {}
   var caption="";
   if (info.rank>1) try { caption=solarflare.ui.ByteUtil.materialize(Texts.skill_rank({rank:info.rank})); } catch (_:Dynamic) {}
   #else
   if (source == null) source=hero;
   var name=HText.statusName(status,info,source);
   var description=""; try { description=HText.statusDescription(status,info,source); } catch (_:Dynamic) {}
   var caption=info.rank>1 ? "Rank "+info.rank : "";
   #end
   var title=StatusBoardText.plain(StatusBoardText.parse(name));
   return {title:title,description:description,caption:caption};
  } catch (_:Dynamic) { return null; }
 }
}
