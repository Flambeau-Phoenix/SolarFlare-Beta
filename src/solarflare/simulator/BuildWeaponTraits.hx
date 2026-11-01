package solarflare.simulator;
import solarflare.simulator.BuildTypes;

/** HSkill.convertWeaponPowerScaling divides the coefficient equally across item primary attributes. */
class BuildWeaponTraits {
    public static function bind(skill:SkillModel,gear:GearSnapshot):Void {
        if(gear.primaryStats.length==0)return;
        for(hit in skill.hits)if(hit.scaling.exists("WeaponPower")){
            var ratio=hit.scaling.get("WeaponPower")/gear.primaryStats.length;hit.scaling.remove("WeaponPower");
            for(id in gear.primaryStats)hit.scaling.set(id,BuildEvaluator.value(hit.scaling,id)+ratio);
        }
        skill.issues.remove("WeaponPower item scaling is not yet covered");
    }
    public static function describe(b:BuildSnapshot,s:BuildScenario):Array<String> {
        var result:Array<String>=[];
        for(g in BuildEquipment.gear(b,s))if(g.slot=="Slot_Weapon1"||g.slot=="Slot_Weapon2"||g.slot=="Slot_OffhandWeapon"){
            result.push(g.name+" / "+g.slot);
            result.push(g.primaryStats.length>0?"WeaponPower attributes: "+g.primaryStats.join(" + ")+" (equal coefficient shares).":"No primary-attribute mapping is available for this item.");
            for(skill in BuildEquipment.skills(b,s))if(skill.weaponSlot==g.slot){
                var types:Array<String>=[];var stats:Array<String>=[];
                for(hit in skill.hits){if(types.indexOf(hit.damageType)<0)types.push(hit.damageType);for(id in hit.scaling.keys())if(stats.indexOf(id)<0)stats.push(id);}
                stats.sort(Reflect.compare);
                result.push("  "+skill.name+": "+(types.length>0?types.join(" / "):"damage effect requires script model")+(stats.length>0?"; scaling: "+stats.join(", "):""));
            }
        }
        result.push("Damage type and attribute scaling are independent. Derived critical/penetration effects are evaluated separately from direct scaling.");
        result.push("A complete stat ranking requires modeled skill, talent, resource and timing coverage. CDB traits alone do not establish the best build.");
        return result;
    }
}
