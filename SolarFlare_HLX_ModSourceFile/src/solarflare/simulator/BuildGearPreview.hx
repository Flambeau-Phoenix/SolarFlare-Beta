package solarflare.simulator;
import solarflare.simulator.BuildTypes;

/** Explicit CDB template capture, called only by observation. Creates no game item or state. */
class BuildGearPreview {
    public static function capture(b:BuildSnapshot,slot:String,id:String,itemLevel:Int):GearSnapshot {
        var catalog=BuildCatalog.load();
        if(!b.compatible||b.identity!=solarflare.HealthCache.identityGen||b.buildHash!=catalog.buildHash)throw "Refresh the current character before selecting gear.";
        if(!catalog.itemFits(id,slot))throw "This CDB item does not fit the selected combat gear slot.";
        if(itemLevel<1||itemLevel>10000)throw "Preview item level must be between 1 and the tool limit of 10000.";
        var inf:Dynamic=Data.item.byId.get(id);if(inf==null)throw "Item is missing from the running CDB.";
        var g=new GearSnapshot(id,BuildCatalog.string(catalog.items.get(id),"name",id),slot);
        g.level=Std.int(BuildCatalog.number(catalog.items.get(id),"level"));g.itemLevel=itemLevel;g.affixFactor=catalog.slotFactor(slot);
        if(slot=="Slot_Weapon1"||slot=="Slot_Weapon2"||slot=="Slot_OffhandWeapon")g.primaryStats=BuildCapture.primaryStats(inf);
        // Match Item.getItemAffixes: base definitions use authored descriptions;
        // an adjusted item level uses generated/scaled descriptions.
        var authored=itemLevel==HItem.getILevel(cast inf);
        var affixes=authored?HAffixes.getDescriptions(ESourceKind.EItem(id)):HItem.generateItemAffixes(cast inf,itemLevel);
        if(affixes==null||affixes.length>256)throw "CDB item affixes could not be captured safely.";
        for(i in 0...affixes.length){
            var native:Dynamic=authored?affixes.getDyn(i):HItem.convertDataAfxToAfxDesc(cast affixes.getDyn(i));var c=BuildCapture.rawAffix(native,g.name);c.value*=g.affixFactor;g.contributions.push(c);
            if(!c.known)g.issues.push("Unsupported template affix: "+c.affix+" / "+c.stat);
        }
        g.skillIds=catalog.itemSkillIds(id);var combo=0;
        for(skill in g.skillIds){
            var row=catalog.rawSkills.get(skill);var nature=BuildCatalog.number(row,"nature",-1);
            if(nature==5){g.issues.push("Granted passive requires evaluation: "+skill);continue;}
            if(nature<0||nature>3)continue;
            var model=catalog.skill(skill);model.weaponSlot=slot;
            if(nature==0||nature==1){model.filler=true;model.comboGroup=slot;model.comboIndex=combo++;model.validated=false;model.issues.push("Native combo timing requires validation.");}
            BuildWeaponTraits.bind(model,g);g.skills.push(model);
        }
        g.notes.push("CDB template at item level "+itemLevel+"; no augments or infusion copied from the old item.");
        g.issues.push("Template skill ranks and equipment/passive interactions require validation.");return g;
    }
}
