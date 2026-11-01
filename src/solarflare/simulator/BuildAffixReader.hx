package solarflare.simulator;
import solarflare.simulator.BuildTypes;
import solarflare.ui.ByteUtil;

private typedef NativeAffix={ref:{id:String},target:ETargetKind,target2:ETargetKind,val:Float,
    conds:{mastery:String,heroic:Null<Bool>,minRank:Null<Float>,maxRank:Null<Float>,equalRank:Null<Float>},mod:Dynamic};

/** Native virtual-record boundary. Typed fields preserve the target and affix identity. */
class BuildAffixReader {
    public static function attributeTarget(target:ETargetKind):String {
        if(target==null||target.getConstructorName()!="ETAttribute")return "";
        var params=target.getParams();return params.length>0?ByteUtil.materialize(cast params[0]):"";
    }
    public static function read(raw:Dynamic,label:String):StatContribution {
        var a:NativeAffix=cast raw;
        var kind=a==null||a.ref==null?"":ByteUtil.materialize(a.ref.id);var stat=a==null?"":attributeTarget(a.target);
        var c=BuildCatalog.affix(kind,stat,a==null?Math.NaN:a.val,ByteUtil.materialize(label));
        if(a==null)return c;
        if(stat=="")c.stat=a.target==null?"(target unavailable)":a.target.getConstructorName()+":"+a.target.getParams().join(",");
        if(a.target2!=null||a.mod!=null)c.known=false;
        var cond=a.conds;
        if(cond!=null&&(cond.mastery!=null||cond.heroic!=null||cond.minRank!=null||cond.maxRank!=null||cond.equalRank!=null))c.known=false;
        return c;
    }
}
