package solarflare.simulator;
import solarflare.simulator.BuildTypes;

/** Detached candidate gear, skill grants and source removal. No native objects. */
class BuildEquipment {
    public static function isWeaponSlot(slot:String):Bool return slot=="Slot_Weapon1"||slot=="Slot_Weapon2"||slot=="Slot_OffhandWeapon";
    public static function loadout(b:BuildSnapshot,s:BuildScenario):String {
        var items=gear(b,s);var labels:Array<String>=[];
        for(slot in ["Slot_Weapon1","Slot_OffhandWeapon","Slot_Weapon2"]){
            var name="Empty";for(g in items)if(g.slot==slot)name=g.name;
            labels.push((slot=="Slot_Weapon1"?"Main hand":slot=="Slot_OffhandWeapon"?"Off hand":"Arsenal")+": "+name);
        }
        return labels.join(" / ");
    }
    public static function gear(b:BuildSnapshot,s:BuildScenario):Array<GearSnapshot> {
        var result:Array<GearSnapshot>=[];var seen:Map<String,Bool>=[];
        for(g in b.gear){result.push(s.gear.exists(g.slot)?s.gear.get(g.slot):g);seen.set(g.slot,true);}
        for(slot=>g in s.gear)if(!seen.exists(slot))result.push(g);
        return result;
    }
    public static function skills(b:BuildSnapshot,s:BuildScenario):Array<SkillModel> {
        var result:Array<SkillModel>=[];var seen:Map<String,Bool>=[];
        for(skill in b.skills)if(!s.gear.exists(skill.weaponSlot)){result.push(skill);seen.set(skill.id,true);}
        var slots=[for(slot in s.gear.keys())slot];slots.sort(Reflect.compare);
        for(slot in slots)for(skill in s.gear.get(slot).skills)if(!seen.exists(skill.id)){result.push(skill);seen.set(skill.id,true);}
        return result;
    }
    public static function removedGrants(b:BuildSnapshot,s:BuildScenario):Map<String,Bool> {
        var removed:Map<String,Bool>=[];
        for(g in b.gear)if(s.gear.exists(g.slot))for(id in g.skillIds)removed.set(id,true);
        for(g in gear(b,s))for(id in g.skillIds)removed.remove(id);
        return removed;
    }
    public static function replace(b:BuildSnapshot,s:BuildScenario,g:GearSnapshot):BuildScenario {
        var next=s.copy();next.gear.set(g.slot,g.copy());
        for(skill in skills(b,next))if(next.priority.indexOf(skill.id)<0)next.priority.push(skill.id);
        return next;
    }
    public static function setRoll(s:BuildScenario,slot:String,index:Int,raw:Float):BuildScenario {
        if(!BuildEvaluator.finite(raw)||Math.abs(raw)>1e9||!s.gear.exists(slot))throw "Invalid assumed roll.";
        var next=s.copy();var gear=next.gear.get(slot);
        if(index<0||index>=gear.contributions.length)throw "The selected stat row changed.";
        var c=gear.contributions[index];c.rawValue=raw;c.value=raw*gear.affixFactor;c.source="Assumed roll: "+gear.name;
        var note="Stat rolls edited as explicit assumptions; server roll probabilities are unknown.";if(gear.notes.indexOf(note)<0)gear.notes.push(note);return next;
    }
}
