package solarflare.simulator;

import solarflare.simulator.BuildTypes;

/** Manifest-pinned, projected CDB data. Parsed once during observation, never during drawing. */
class BuildCatalog {
    public var buildHash:String="";
    public var cdbHash:String="";
    public var version:String="";
    public var rulesValidated:Bool=false;
    public var runtimeValidated:Bool=false;
    public var talentRulesValidated:Bool=false;
    var validatedSkills:Map<String,Bool>=new Map();
    var validatedTalents:Map<String,Bool>=new Map();
    public var attributes:Array<AttributeRule>=[];
    public var rawSkills:Map<String,Dynamic>=new Map();
    public var rawClasses:Map<String,Dynamic>=new Map();
    public var resourceMax:Map<String,String>=new Map();
    public var resourceRegen:Map<String,Array<ResourceRegenRule>>=new Map();
    public var unknownResourceRegen:Map<String,String>=new Map();
    public var affinities:Map<String,String>=new Map();
    public var items:Map<String,Dynamic>=new Map();
    public var itemTypes:Map<String,Dynamic>=new Map();
    public var gearSlots:Array<String>=[];
    var slotItems:Map<String,Array<String>>=[];
    static var cached:BuildCatalog;
    var tierThresholds:Array<Int>=[];
    public function new() {}
    public static function load():BuildCatalog {
        if(cached!=null)return cached;
        var text=haxe.Resource.getString("build-simulator");
        if (text==null) throw "Build simulator catalog is not packaged.";
        cached=parse(text);return cached;
    }
    public static function parse(text:String):BuildCatalog {
        var raw:Dynamic=haxe.Json.parse(text); var out=new BuildCatalog();
        if (number(raw,"schema")!=1) throw "Unsupported simulator catalog schema.";
        out.buildHash=string(raw,"hlbootSha256").toLowerCase(); out.cdbHash=string(raw,"cdbSha256").toLowerCase();
        out.version=string(raw,"modelVersion");
        // Verification is a release artifact, never an editable UI override.
        out.rulesValidated=field(raw,"rulesValidated")==true;
        out.runtimeValidated=field(raw,"runtimeValidated")==true;
        out.talentRulesValidated=field(raw,"talentRulesValidated")==true;
        for (id in array(raw,"validatedSkillIds")) out.validatedSkills.set(Std.string(id),true);
        for (id in array(raw,"validatedTalentIds")) out.validatedTalents.set(Std.string(id),true);
        var constants=field(raw,"constants");
        for (v in array(constants,"Talents_TierThresholds")) out.tierThresholds.push(Std.int(v));
        var affinityRecords=new Map<String,Dynamic>();
        for (a in array(raw,"affinities")) affinityRecords.set(string(a,"id"),a);
        for (id=>a in affinityRecords) {
            var current=id, depth=0;
            while (depth++<20 && current!="Physical" && current!="Magic" && current!="Raw") {
                var record=affinityRecords.get(current); var parent=string(record,"parent");
                if (parent=="" || parent==current) break; current=parent;
            }
            if (current=="Physical") out.affinities.set(id,"physical");
            else if (current=="Magic") out.affinities.set(id,"magic");
            else if (current=="Raw") out.affinities.set(id,"raw");
        }
        for (row in array(raw,"skills")) out.rawSkills.set(string(row,"id"),row);
        for (row in array(raw,"classes")) out.rawClasses.set(string(row,"id"),row);
        for(row in array(raw,"items"))out.items.set(string(row,"id"),row);
        for(row in array(raw,"itemTypes"))out.itemTypes.set(string(row,"id"),row);
        for(row in array(raw,"itemTypes")){
            var slot=field(row,"slot");var category=number(slot,"displayCategory",-1);
            if(field(slot,"isSlot")==true&&(category==0||category==1||category==3))out.gearSlots.push(string(row,"id"));
        }
        // Build a detached compatibility index once at catalog load, not on each UI request.
        for(slot in out.gearSlots)out.slotItems.set(slot,[]);
        for(id=>row in out.items){
            var type=string(row,"type"),depth=0;var gear=false;var slots:Array<String>=[];
            while(type!=""&&depth++<24){
                if(type=="Gear")gear=true;
                var t=out.itemTypes.get(type);
                for(s in array(field(t,"slot"),"equippableOn")){var slot=string(s,"ref");if(out.slotItems.exists(slot)&&slots.indexOf(slot)<0)slots.push(slot);}
                type=string(t,"inherit");
            }
            if(gear)for(slot in slots)out.slotItems.get(slot).push(id);
        }
        for (row in array(raw,"attributes")) {
            var a=new AttributeRule(string(row,"id")); a.index=Std.int(number(row,"index"));
            a.defaultValue=number(row,"defVal"); var flags=Std.int(number(row,"flags"));
            a.ceil=(flags&2048)!=0; a.allowNegative=(flags&128)!=0;
            for (term in array(row,"scaling")) {
                var t=new ScalingTerm(string(term,"attribute"),number(term,"scale"));
                var op:Array<Dynamic>=field(term,"scalingOperator");
                if (op!=null && op.length>0 && op[0]!=0) {
                    if (op[0]==2 && op.length==4) {
                        t.operation="rating"; t.half=op[1]; t.end=op[2]; t.cap=op[3];
                        t.maxLevel=number(constants,"LevelScalingFormula_EarlyMaxLevel",Math.NaN);
                    } else t.operation="unsupported";
                }
                a.scaling.push(t);
            }
            out.attributes.push(a);
            if (string(row,"maxAtb")!="") out.resourceMax.set(a.id,string(row,"maxAtb"));
            var regeneration:Array<ResourceRegenRule>=[];
            for (r in array(row,"regenAtbs")) {
                var cond=field(r,"conds");
                if (field(cond,"timeOutsideCombat")!=null) continue;
                if (fields(cond).length>0) { out.unknownResourceRegen.set(a.id,"Conditional regeneration is not modeled for "+a.id); continue; }
                regeneration.push(new ResourceRegenRule(string(r,"atb"),number(r,"factor",1)));
            }
            out.resourceRegen.set(a.id,regeneration);
        }
        return out;
    }
    public function slotName(id:String):String return string(itemTypes.get(id),"name",id);
    public function itemIdsForSlot(slot:String):Array<String> return slotItems.exists(slot)?slotItems.get(slot):[];
    public function slotFactor(id:String):Float return number(field(itemTypes.get(id),"slot"),"affixFactor",1);
    public function itemFits(id:String,slot:String):Bool {
        if(gearSlots.indexOf(slot)<0)return false;
        var item=items.get(id);if(item==null)return false;
        var type=string(item,"type"),depth=0;var gear=false;var fits=false;
        while(type!=""&&depth++<24){
            if(type=="Gear")gear=true;
            var row=itemTypes.get(type);for(s in array(field(row,"slot"),"equippableOn"))if(string(s,"ref")==slot)fits=true;
            type=string(row,"inherit");
        }
        return gear&&fits;
    }
    public function itemSkillIds(id:String):Array<String> {
        var row=items.get(id);var result:Array<String>=[];
        for(s in array(row,"skills")){var skill=string(s,"skill");if(skill!=""&&result.indexOf(skill)<0)result.push(skill);}
        var type=string(row,"type"),depth=0;
        while(type!=""&&depth++<24){var t=itemTypes.get(type);for(s in array(t,"skills")){var skill=string(s,"skill");if(skill!=""&&result.indexOf(skill)<0)result.push(skill);}type=string(t,"inherit");}
        return result;
    }

    public function skill(id:String,rank:Int=1):SkillModel {
        var row=rawSkills.get(id); var m=new SkillModel(id,row==null?id:string(row,"name",id)); m.rank=rank;
        m.evidence="CastleDB skill:"+id+"; model "+version;
        if (row==null) { m.issues.push("No record in the pinned catalog"); return m; }
        var props=field(row,"props");
        m.cooldown=number(row,"cooldown"); m.charges=Std.int(number(props,"charges",1));
        var duration=number(row,"duration"); var anim=field(row,"anim");
        m.actionTime=duration>0?duration:number(anim,"duration",1);
        m.filler=number(row,"nature")==0;
        if (duration<=0 && number(anim,"duration")<=0) m.issues.push("Animation/cast recovery time requires runtime validation");
        if (field(row,"scripted")==true) m.issues.push("Scripted skill effects are not yet covered");
        if (m.charges>1) m.issues.push("Charge recovery policy requires validation");
        for (cost in array(props,"costs")) {
            var atb=string(cost,"atb"); if (atb!="") m.costs.set(atb,number(cost,"amount"));
        }
        for (step in array(row,"steps")) {
            var p=field(step,"props");
            if (field(p,"summon")!=null || field(p,"projectile")!=null || field(p,"status")!=null
                || field(p,"targetSkill")!=null || array(p,"startSteps").length>0)
                m.issues.push("Summon, projectile, status or linked-step behavior requires a dedicated model");
            var delay:Dynamic=field(step,"delay");
            var delayKnown=delay==null || Std.isOfType(delay,Float) || Std.isOfType(delay,Int);
            if (!delayKnown) m.issues.push("Dynamic step timing is not covered");
            for (effect in array(step,"effects")) {
                if (number(effect,"effect")!=0) continue;
                var h=new DamageComponent(); h.affinity=string(effect,"affinity","Physical");
                h.damageType=affinities.exists(h.affinity)?affinities.get(h.affinity):"unknown";
                if (h.damageType=="unknown" || field(effect,"affinity")==null) m.issues.push("Unknown damage affinity");
                if (h.damageType=="raw") m.issues.push("Raw damage multiplier policy requires verification");
                h.base=number(effect,"baseVal"); h.delay=delayKnown?number(step,"delay"):0;
                if (field(effect,"dynVal")!=null) m.issues.push("Dynamic damage value requires script evaluation");
                if (string(effect,"status")!="") m.issues.push("Applied status affects the simulated target/build");
                if (number(effect,"flags")!=0) m.issues.push("Damage effect flags require verification");
                if (number(step,"on")!=0 || field(step,"loop")!=null) m.issues.push("Triggered/repeating step requires a dedicated model");
                for (scale in array(effect,"scaling")) {
                    var stat=string(scale,"atb"); h.scaling.set(stat,number(scale,"ratio"));
                    if (stat=="WeaponPower") m.issues.push("WeaponPower item scaling is not yet covered");
                }
                m.hits.push(h);
            }
        }
        if (rank>1 && (field(props,"rankOverride")!=null || field(props,"rank2")!=null || field(props,"rank3")!=null))
            m.issues.push("Rank overrides require a dedicated model");
        if (array(row,"affixes").length>0 || array(props,"subskills").length>0 || array(props,"rankPassives").length>0)
            m.issues.push("Skill passives/affixes have not been evaluated");
        if (m.hits.length==0) m.issues.push("No independently modeled direct damage component");
        if (!validatedSkills.exists(id)) m.issues.push("Skill-specific model verification is pending");
        m.issues=unique(m.issues); m.validated=rulesValidated && validatedSkills.exists(id) && m.issues.length==0;
        return m;
    }

    public function talents(classId:String):Array<TalentModel> {
        var c=rawClasses.get(classId); var out:Array<TalentModel>=[]; var seen=new Map<String,Bool>();
        for (tree in array(c,"talentTrees")) for (node in array(tree,"talents")) {
            var id=string(node,"skill"); if (seen.exists(id)) continue; seen.set(id,true);
            var row=rawSkills.get(id); var t=new TalentModel(id,string(row,"name",id));
            t.maxRank=Std.int(number(field(field(row,"props"),"talent"),"maxPoints",1));
            t.tier=Std.int(number(node,"tier")); t.branch=Std.int(number(node,"branch")); t.tree=string(tree,"root");
            // Tier/branch filtering is captured for inspection. Tree switching and refund legality remain gated.
            t.legalityKnown=talentRulesValidated && t.tier<tierThresholds.length;
            if (t.tier>0) t.requires.set(t.tree,1);
            if (t.tier<tierThresholds.length) t.requiredLowerPoints=tierThresholds[t.tier];
            t.byRank.push([]);
            var issues=[];
            if (field(row,"scripted")==true) issues.push("scripted talent effect");
            for (r in 1...(t.maxRank+1)) {
                var values=[];
                for (a in array(row,"affixes")) {
                    var cond=field(a,"conds");
                    if (r<number(cond,"minRank",1) || r>number(cond,"maxRank",t.maxRank)) continue;
                    var mod=field(field(a,"mod"),"dynVal");
                    var contribution=affix(string(a,"ref"),string(field(a,"target"),"attribute"),number(a,"val"),t.name);
                    if (mod!=null || field(cond,"mastery")!=null || field(cond,"heroic")!=null || field(cond,"equalRank")!=null
                        || fields(field(a,"target2")).length>0) contribution.known=false;
                    if (!contribution.known) issues.push("conditional or unsupported talent affix");
                    values.push(contribution);
                }
                t.byRank.push(values);
            }
            if (t.byRank.length>1 && t.byRank[1].length==0) issues.push("talent skill/status interaction not modeled");
            if (!validatedTalents.exists(id)) issues.push("talent-specific model verification pending");
            t.reason=unique(issues).join("; "); t.validated=rulesValidated && validatedTalents.exists(id) && issues.length==0;
            out.push(t);
        }
        return out;
    }

    /** Raw ratios are fractions in CDB; contribution UI consistently uses percent units. */
    public static function affix(kind:String,stat:String,value:Float,source:String):StatContribution {
        var op=switch kind { case "TAttribute_Flat": "flat"; case "TAttribute_ARatio": "percent"; case "TAttribute_MRatio": "multiply"; default: "unsupported"; };
        var c=new StatContribution(stat,value*(op=="percent" || op=="multiply"?100:1),source,op);
        c.affix=kind;c.known=stat!="" && op!="unsupported" && BuildEvaluator.finite(value); return c;
    }
    public static function field(o:Dynamic,key:String):Dynamic return o==null?null:Reflect.field(o,key);
    public static function string(o:Dynamic,key:String,fallback:String=""):String {
        var v=field(o,key); return v==null?fallback:Std.string(v);
    }
    public static function number(o:Dynamic,key:String,fallback:Float=0):Float {
        var v=field(o,key); if (v==null) return fallback;
        if (!Std.isOfType(v,Float) && !Std.isOfType(v,Int)) return fallback;
        return v;
    }
    public static function array(o:Dynamic,key:String):Array<Dynamic> {
        var v=field(o,key); return Std.isOfType(v,Array)?cast v:[];
    }
    static function fields(o:Dynamic):Array<String> return o==null?[]:Reflect.fields(o);
    static function unique(values:Array<String>):Array<String> {
        var out=[]; for (v in values) if (out.indexOf(v)<0) out.push(v); return out;
    }
}
