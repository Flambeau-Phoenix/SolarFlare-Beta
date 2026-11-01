package solarflare.simulator;
import solarflare.simulator.BuildTypes;

typedef WeaponStatFit={stat:String,weapons:Int};
typedef GearFit={id:String,name:String,slot:String,stats:Array<String>,score:Float,detail:String,button:String};

/** A transparent trait heuristic, independent of the gated damage simulator. No native reads. */
class BuildAdvice {
    public static function profile(b:BuildSnapshot,s:BuildScenario):Array<WeaponStatFit> {
        var counts:Map<String,Int>=[];var skills=BuildEquipment.skills(b,s);
        for(g in BuildEquipment.gear(b,s))if(BuildEquipment.isWeaponSlot(g.slot)){
            var stats:Array<String>=[];
            for(id in g.primaryStats)if(BuildEvaluator.PRIMARY.indexOf(id)>=0&&stats.indexOf(id)<0)stats.push(id);
            for(skill in skills)if(skill.weaponSlot==g.slot)for(hit in skill.hits)for(id=>coefficient in hit.scaling)
                if(coefficient>0&&BuildEvaluator.PRIMARY.indexOf(id)>=0&&stats.indexOf(id)<0)stats.push(id);
            for(id in stats)counts.set(id,counts.exists(id)?counts.get(id)+1:1);
        }
        var result=[for(id=>count in counts){stat:id,weapons:count}];
        result.sort((a,b)->a.weapons!=b.weapons?b.weapons-a.weapons:Reflect.compare(a.stat,b.stat));
        return result;
    }
    public static function lines(b:BuildSnapshot,s:BuildScenario,catalog:BuildCatalog):Array<String> {
        var p=profile(b,s);var out:Array<String>=[];
        out.push("Weapon-based guide: shared scaling, not a simulated DPS ranking.");
        if(p.length==0){out.push("No primary-stat scaling is available for these weapons. Refresh or select another item.");return out;}
        var leaders=[for(x in p)if(x.weapons==p[0].weapons)x.stat];
        out.push("Start by looking for "+leaders.join(" or ")+" on gear: "+(leaders.length>1?"they support":"it supports")+" the most equipped weapon profiles.");
        for(x in p)out.push(x.stat+": supports "+x.weapons+" weapon profile"+(x.weapons==1?"":"s")+"; captured total "+AdviceFormat.number(BuildEvaluator.value(b.effective,x.stat,Math.NaN))+".");
        out.push("Each main hand, off hand and arsenal item gets one vote per supported primary stat. Repeated hits and attack-chain steps do not add votes. Tied stats have equal priority.");
        out.push("This uses positive direct CDB scaling and each item's WeaponPower attributes. It does not predict an ideal split or value crit, penetration, procs, talent interactions or server rolls.");
        for(g in BuildEquipment.gear(b,s))if(BuildEquipment.isWeaponSlot(g.slot)){
            out.push(g.name+" / "+(g.slot=="Slot_OffhandWeapon"?"Off hand":g.slot=="Slot_Weapon1"?"Main hand":"Arsenal"));
            for(c in g.contributions)if(c.known)out.push("  "+c.stat+": "+AdviceFormat.number(c.value)+" ("+c.operation+", gear source contribution)");
            for(id in g.skillIds){var row=catalog.rawSkills.get(id);if(BuildCatalog.number(row,"nature",-1)==5)
                out.push("  Passive: "+BuildCatalog.string(row,"name",id)+". Its conditional effects are not ranked by this guide.");}
        }
        out.push("Use Gear picks for matching aptitude examples, then compare actual rolled stats in Gear and Stats. An aptitude match does not establish best-in-slot.");
        return out;
    }
    public static function picks(catalog:BuildCatalog,b:BuildSnapshot,s:BuildScenario,slot:String,limit:Int=5):Array<GearFit> {
        var p=profile(b,s);var result:Array<GearFit>=[];
        if(p.length==0)return result;
        for(id in catalog.itemIdsForSlot(slot)){
            var row=catalog.items.get(id);
            var stats=[for(v in BuildCatalog.array(row,"primaryStats"))Std.string(v)];
            if(stats.length==0)continue;
            var score=0.;for(stat in stats)for(x in p)if(x.stat==stat)score+=x.weapons;
            if(score<=0)continue;
            score/=stats.length;
            var name=BuildCatalog.string(row,"name",id);
            result.push({id:id,name:name,slot:slot,stats:stats,score:score,
                detail:stats.join(" + ")+" / "+BuildCatalog.string(row,"aptitudeLabel")+" / "+BuildCatalog.string(row,"rarity")+" / CDB level "+BuildCatalog.number(row,"level")+" / trait fit "+AdviceFormat.number(score),
                button:"Preview##sim_fit_"+slot+"_"+id});
        }
        result.sort((a,b)->a.score!=b.score?(a.score>b.score?-1:1):Reflect.compare(a.name+"/"+a.id,b.name+"/"+b.id));
        return result.slice(0,Std.int(Math.max(0,limit)));
    }
}

/** Keep the heuristic usable in pure tests without pulling in the ImGui window. */
private class AdviceFormat {
    public static function number(v:Float):String return BuildEvaluator.finite(v)?Std.string(Math.round(v*100)/100):"unknown";
}
