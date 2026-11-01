package solarflare.simulator;

import solarflare.simulator.BuildTypes;
import solarflare.FieldWalk;
import solarflare.ui.ByteUtil;


/** The only simulator layer allowed to read game objects. References are local to an observe call. */
class BuildCapture implements BuildSource {
    var catalog:BuildCatalog;
    var identityCheck=new BuildIdentity();
    var result:BuildSnapshot;
    var phase=0; var index=0; var ready=false;
    var fingerprint="";
    var ledgerKeys:Array<Int>=[];
    public function new() {}
    public function begin(identity:Int,profileGeneration:Int):Void {
        reset();
        if (catalog==null) catalog=BuildCatalog.load();
        result=new BuildSnapshot(); result.identity=identity; result.profileGeneration=profileGeneration;
        result.modelVersion=catalog.version; result.buildHash=catalog.buildHash;
        result.rulesValidated=catalog.rulesValidated; result.runtimeValidated=catalog.runtimeValidated;
        result.attributes=catalog.attributes.copy();
        result.capturedAt=Date.now().toString();
    }
    public function reset():Void { result=null; phase=index=0; ready=false; ledgerKeys=[]; fingerprint=""; }
    public function take():BuildSnapshot return result;
    public function advance(units:Int):Bool {
        if (ready) return true;
        if (result==null) return false;
        if (!identityCheck.advance()) return false;
        if (identityCheck.hash=="" || identityCheck.hash!=catalog.buildHash) {
            result.issues.push(identityCheck.message!=""?identityCheck.message:
                "Installed bytecode "+identityCheck.hash+" differs from model "+catalog.buildHash+". Update the corpus/model before capture.");
            ready=true; return true;
        }
        result.compatible=true;
        var hero=solarflare.HealthCache.localHero;
        if (!solarflare.HealthCache.isHeroObject(hero)) { result.issues.push("No local hero is available."); ready=true; return true; }
        if (solarflare.HealthCache.identityGen!=result.identity) { result.issues.push("Character changed during capture."); ready=true; return true; }
        var h:ent.Hero=hero;
        var start=haxe.Timer.stamp();
        for (_ in 0...units) {
            if (haxe.Timer.stamp()-start>=0.003) break;
            switch phase {
                case 0:
                    if (!isType(h.attr,"ent.HeroAttributes")) { result.issues.push("Local hero attributes are not ready."); ready=true; return true; }
                    result.character=ByteUtil.materialize(h.name); result.level=h.getEffectiveLevel(); fingerprint=loadoutKey(h);
                    result.weapons=[weaponName(h.get_weapon1()),weaponName(h.get_weapon2())];
                    var active=h.get_activeWeapon();
                    if (active!=null && isType(active,"st.Item") && h.get_equipment()!=null) {
                        var activeItem:st.Item=cast active;
                        result.activeWeaponSlot=ByteUtil.materialize(h.get_equipment().getEquipSlot(activeItem));
                    }
                    result.talents=catalog.talents(h.inf.id);
                    var spec=h.specialization;
                    if (spec!=null) result.talentBudget=spec.getTotalTalentPoints();
                    if (spec!=null && spec.talents!=null) {
                        var map=spec.talents.map; var keys=map.keys(); var count=0;
                        while (keys.hasNext() && count++<256) {
                            var key=keys.next(); result.talentRanks.set(ByteUtil.materialize(key),Std.int(map.get(key)));
                        }
                        if (count>=256) result.issues.push("Talent capture limit reached.");
                    }
                    phase=1; index=0;
                case 1:
                    if (index>=catalog.attributes.length) { phase=2; index=0; continue; }
                    var a=catalog.attributes[index++];
                    if (!isType(h.attr,"ent.HeroAttributes")) { result.issues.push("Hero attributes changed during capture."); ready=true; return true; }
                    var attrs:ent.HeroAttributes=cast h.attr;
                    result.base.set(a.id,attrs.get(a.index)+h.getAtbLevelScaling(a.index));
                    result.effective.set(a.id,h.atb(a.index,null,null));
                case 2:
                    var equipment=h.get_equipment();
                    if(!isType(equipment,"st.Equipment")){result.issues.push("Equipment is not ready.");ready=true;return true;}
                    if(index>=catalog.gearSlots.length){phase=3;index=0;continue;}
                    var slot=catalog.gearSlots[index++];var item=equipment.getSlot(slot);
                    if(isType(item,"st.item.Gear"))captureItem(item,equipment,slot);
                case 3:
                    var skills=h.skills;
                    if (skills==null || index>=skills.length || index>=512) {
                        if (skills!=null && skills.length>512) result.issues.push("Skill capture limit reached.");
                        var manager=h.affixes;
                        if (manager!=null && manager.appsByUid!=null) {
                            var map=manager.appsByUid.map; var keys=map.keys(); var count=0;
                            while (keys.hasNext() && count++<1024) ledgerKeys.push(Std.int(keys.next()));
                            if (count>=1024) result.issues.push("Affix ledger capture limit reached.");
                        }
                        phase=4; index=0; continue;
                    }
                    var raw=skills.getDyn(index++);
                    if (!isType(raw,"st.skill.BaseSkill")) continue;
                    var skill:st.skill.BaseSkill=raw;
                    if (skill.inf==null) continue;
                    var nature=skill.inf.nature;
                    if (nature==5 && !result.talentRanks.exists(skill.inf.id)) {
                        var row=catalog.rawSkills.get(skill.inf.id);
                        if (row==null || BuildCatalog.field(row,"scripted")==true || BuildCatalog.array(row,"steps").length>0)
                            result.issues.push("Unmodeled permanent skill behavior: "+skill.inf.id);
                    }
                    if (nature!=0 && nature!=1 && nature!=2 && nature!=3) continue;
                    var model=catalog.skill(ByteUtil.materialize(skill.inf.id),skill.get_rank());
                    // The native lists decide which skills are equipped, rather than every known spell.
                    var nativeAttack=contains(h.attackSkills,raw) || (cast h.attackComboSkill:Dynamic)==raw;
                    if (!nativeAttack && !contains(h.weaponSkills,raw) && !slotContains(h.skillSlots,skill.inf.id)
                        && (cast h.secondarySkill:Dynamic)!=raw) continue;
                    var origin=skill.originItem;
                    if (origin!=null && h.get_equipment()!=null) model.weaponSlot=ByteUtil.materialize(h.get_equipment().getEquipSlot(origin));
                    if(model.weaponSlot!=""&&catalog.gearSlots.indexOf(model.weaponSlot)<0)continue;
                    if (nativeAttack) {
                        model.filler=true; model.comboGroup=model.weaponSlot!=""?model.weaponSlot:"native";
                        model.comboIndex=indexOf(h.attackSkills,raw);
                        if (model.comboIndex<0) model.comboIndex=h.attackSkills==null?0:h.attackSkills.length;
                        model.validated=false; model.issues.push("Native combo reset/recovery timing requires verification");
                    }
                    result.skills.push(model);
                    for(g in result.gear)if(g.slot==model.weaponSlot){BuildWeaponTraits.bind(model,g);g.skills.push(model);}
                case 4:
                    if (index>=ledgerKeys.length) { phase=5; continue; }
                    var manager=h.affixes;
                    if (manager==null || manager.appsByUid==null) { phase=5; continue; }
                    var raw=manager.appsByUid.map.get(ledgerKeys[index++]);
                    if (!isType(raw,"ent.AffixApplication")) continue;
                    var app:ent.AffixApplication=raw;
                    var source=app.source;
                    if (source==null) { result.issues.push("Affix with unknown source"); continue; }
                    var sourceType=source.getConstructorName(); var params=source.getParams();
                    var id=sourceType=="ESkill" && params.length>0?ByteUtil.materialize(cast params[0]):sourceType;
                    if (sourceType=="EItem") continue; // Already represented by disjoint gear aggregate rows.
                    if (sourceType=="ESkill" && result.talentRanks.exists(id)) continue; // Rebuilt from candidate talent ranks.
                    var c=application(app,id);
                    var row=catalog.rawSkills.get(id);
                    if (sourceType=="ESkill" && BuildCatalog.number(row,"nature")==5) {
                        result.permanent.push(c); if (!c.known) result.issues.push("Unmodeled permanent effect: "+id);
                    } else result.temporary.push(c);
                case 5:
                    if (fingerprint!=loadoutKey(h)) { result.issues.push("Loadout changed during capture. Refresh while the build is stable."); result.compatible=false; }
                    var solo=BuildEvaluator.stats(result,new BuildScenario());
                    result.resourceMax=catalog.resourceMax.copy(); result.regenRules=catalog.resourceRegen.copy();
                    for (id=>max in catalog.resourceMax) result.resourceCaps.set(id,BuildEvaluator.value(solo,max));
                    for (id=>regs in catalog.resourceRegen) {
                        var regen=0.; for (r in regs) regen+=BuildEvaluator.value(solo,r.stat)*r.factor; result.regen.set(id,regen);
                    }
                    for (s in result.skills) for (id in s.costs.keys()) if (catalog.unknownResourceRegen.exists(id)) result.issues.push(catalog.unknownResourceRegen.get(id));
                    if (!catalog.runtimeValidated) result.issues.push("Base/gear/permanent source reconciliation against the game is pending.");
                    else if (result.temporary.length==0) for (id=>v in result.effective) {
                        var modeled=BuildEvaluator.value(solo,id,Math.NaN);
                        if (!BuildEvaluator.finite(modeled) || Math.abs(modeled-v)>0.01+Math.abs(v)*0.00001)
                            result.issues.push("Source reconciliation mismatch: "+id);
                    }
                    BuildCaptureDebug.write(result);
                    ready=true; return true;
            }
        }
        return false;
    }
    function captureItem(item:st.Item,equipment:st.Equipment,slot:String):Void {
        var id=ByteUtil.materialize(item.kind);
        var g=new GearSnapshot(id,id,slot);
        g.skillIds=catalog.itemSkillIds(id);
        if(slot=="Slot_Weapon1"||slot=="Slot_Weapon2"||slot=="Slot_OffhandWeapon")g.primaryStats=primaryStats(item.inf);
        var factor=equipment.getAffixFactor(item,slot);
        if (factor==null || !BuildEvaluator.finite(factor)) { result.issues.push(item.kind+": unknown equipment affix factor"); g.affixFactor=1; }
        else g.affixFactor=factor;
        if (item.inf!=null && item.inf.texts!=null && item.inf.texts.name!=null) g.name=ByteUtil.materialize(item.inf.texts.name);
        var aggregate:hl.types.ArrayBase=null;
        var labels:Array<{key:String,label:String}>=[];
        if (isType(item,"st.item.Gear")) {
            var gear:st.item.Gear=item; g.level=gear.level; g.upgrade=gear.upgradeLevel; g.infusion=ByteUtil.materialize(gear.infusion);g.itemLevel=gear.getILevel();
            aggregate=gear.getAffixes(); // Resolve the Gear override explicitly through its typed wrapper.
            if (gear.slots!=null) {
                var length=FieldWalk.arrayLen(gear.slots);
                for (i in 0...Std.int(Math.min(32,length))) {
                    var raw=FieldWalk.arrayAt(gear.slots,i); var id:String=Std.isOfType(raw,String)?cast raw:"";
                    if (id=="") continue;
                    var affixes=gear.getSlotAffixes(id);
                    if (affixes!=null) for (j in 0...Std.int(Math.min(128,affixes.length))) labels.push({key:affixKey(affixes.getDyn(j)),label:"Augment "+(i+1)+": "+id});
                }
            }
            if (gear.isInfusionBonusActive()) {
                var bonus=gear.getInfusionBonusAffix(); if (bonus!=null) labels.push({key:affixKey(bonus),label:"Infusion: "+g.infusion});
            }
        }
        else aggregate=item.getAffixes();
        if (aggregate!=null) for (i in 0...Std.int(Math.min(256,aggregate.length))) {
            var a=aggregate.getDyn(i); var key=affixKey(a); var label=g.name;
            for (j in 0...labels.length) if (labels[j].key==key) { label=labels[j].label; labels.splice(j,1); break; }
            var c=rawAffix(a,label); c.value*=g.affixFactor; g.contributions.push(c);
            if (!c.known) { g.notes.push("Unsupported affix: "+c.affix+" / "+c.stat); if(result.issues.indexOf(g.name+": unmodeled gear affix")<0)result.issues.push(g.name+": unmodeled gear affix"); }
        }
        if (aggregate!=null && aggregate.length>256) result.issues.push(g.name+": affix capture limit reached");
        if (labels.length>0) result.issues.push(g.name+": socket/infusion source attribution could not be reconciled");
        result.gear.push(g);
    }
    static function target(target:ETargetKind):String {
        return BuildAffixReader.attributeTarget(target);
    }
    public static function primaryStats(inf:Dynamic):Array<String> {
        var result:Array<String>=[];var native=HSkill.getItemPrimaryAttributes(cast inf);
        if(native!=null)for(i in 0...Std.int(Math.min(16,native.length))){var row:{id:String}=cast native.getDyn(i);if(row!=null&&row.id!=null)result.push(solarflare.ui.ByteUtil.materialize(row.id));}
        return result;
    }
    public static function rawAffix(raw:Dynamic,label:String):StatContribution {
        return BuildAffixReader.read(raw,label);
    }
    static function affixKey(a:Dynamic):String {
        var c=rawAffix(a,""); return c.stat+":"+c.operation+":"+c.value;
    }
    static function application(a:ent.AffixApplication,label:String):StatContribution {
        var c=BuildCatalog.affix(ByteUtil.materialize(a.kind),target(a.target),a.get_val(),label);
        if (a.target2!=null) c.known=false; return c;
    }
    static function contains(array:hl.types.ArrayBase,value:Dynamic):Bool {
        return indexOf(array,value)>=0;
    }
    static function indexOf(array:hl.types.ArrayBase,value:Dynamic):Int {
        if (array==null) return -1;
        for (i in 0...Std.int(Math.min(128,array.length))) if (array.getDyn(i)==value) return i;
        return -1;
    }
    static function slotContains(array:hl.types.ArrayBase,id:String):Bool {
        if (array==null) return false;
        for (i in 0...Std.int(Math.min(128,array.length))) if (array.getDyn(i)==id) return true;
        return false;
    }
    function loadoutKey(h:ent.Hero):String {
        var parts=[h.name]; var e=h.get_equipment();
        var active=h.get_activeWeapon(); if (active!=null) parts.push("active:"+active.kind);
        if(isType(e,"st.Equipment"))for(slot in catalog.gearSlots){
            var item=e.getSlot(slot);if(!isType(item,"st.item.Gear"))continue;parts.push(slot);
            var it:st.Item=item; parts.push(it.kind); if (it.flags!=null) parts.push(Std.string(it.flags.value));
            if (isType(item,"st.item.Gear")) {
                var g:st.item.Gear=item; parts.push(g.level+":"+g.upgradeLevel+":"+g.infusion+":"+g.infusionBonusStat);
                if(g.slots!=null)for(i in 0...Std.int(Math.min(32,FieldWalk.arrayLen(g.slots))))parts.push(Std.string(FieldWalk.arrayAt(g.slots,i)));
            }
        }
        var spec=h.specialization;
        if (spec!=null && spec.talents!=null) {
            var m=spec.talents.map; var it=m.keys(); var entries=[]; var count=0;
            while (it.hasNext() && count++<256) { var key=it.next(); entries.push(Std.string(key)+":"+Std.string(m.get(key))); }
            entries.sort(Reflect.compare); for (s in entries) parts.push(s);
        }
        var skills=h.skills;
        if (skills!=null) for (i in 0...Std.int(Math.min(512,skills.length))) {
            var raw=skills.getDyn(i); if (!isType(raw,"st.skill.BaseSkill")) continue;
            var s:st.skill.BaseSkill=raw;
            if (s.inf!=null) parts.push(s.inf.id+":"+s.internalRank);
        }
        if (h.skillSlots!=null) for (i in 0...Std.int(Math.min(128,h.skillSlots.length))) {
            var id=h.skillSlots.getDyn(i); if (Std.isOfType(id,String)) parts.push(cast id);
        }
        return parts.join("|");
    }
    static function weaponName(weapon:st.item.Weapon):String {
        if (weapon==null) return "Empty";
        var info=weapon.inf;
        return ByteUtil.materialize(info!=null && info.texts!=null && info.texts.name!=null?info.texts.name:weapon.kind);
    }
    static function isType(value:Dynamic,name:String):Bool {
        if (value==null) return false;
        var t=hl.Type.getDynamic(value); var depth=0;
        while (t.kind==hl.Type.TypeKind.HObj && depth++<20) {
            if (t.getTypeName()==name) return true;
            t=t.getSuper();
        }
        return false;
    }
}
