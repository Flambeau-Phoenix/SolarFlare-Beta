package solarflare.simulator;

/** Pure, owned data only. None of these records may contain a game object. */
class StatContribution {
    public var stat:String;
    public var value:Float;
    public var source:String;
    public var operation:String;
    public var rawValue:Float;
    public var known:Bool = true;
    public var affix:String="";
    public function new(stat:String, value:Float, source:String, operation:String="flat") {
        this.stat=stat; this.value=value; rawValue=value; this.source=source; this.operation=operation;
    }
    public function copy():StatContribution {
        var c=new StatContribution(stat,value,source,operation); c.known=known; c.rawValue=rawValue;c.affix=affix; return c;
    }
}

class GearSnapshot {
    public var id:String;
    public var name:String;
    public var slot:String;
    public var level:Int=0;
    public var upgrade:Int=0;
    public var itemLevel:Int=0;
    public var skills:Array<SkillModel>=[];
    public var skillIds:Array<String>=[];
    public var primaryStats:Array<String>=[];
    public var issues:Array<String>=[];
    public var infusion:String="";
    public var affixFactor:Float=1;
    public var contributions:Array<StatContribution>=[];
    public var notes:Array<String>=[];
    public function new(id:String,name:String,slot:String) { this.id=id; this.name=name; this.slot=slot; }
    public function copy():GearSnapshot {
        var g=new GearSnapshot(id,name,slot);g.level=level;g.upgrade=upgrade;g.itemLevel=itemLevel;g.infusion=infusion;g.affixFactor=affixFactor;
        g.contributions=[for(c in contributions)c.copy()];g.notes=notes.copy();g.issues=issues.copy();g.skills=[for(s in skills)s.copy()];g.skillIds=skillIds.copy();g.primaryStats=primaryStats.copy();return g;
    }
}

class ScalingTerm {
    public var stat:String;
    public var ratio:Float;
    public var operation:String="linear";
    public var cap:Float=0;
    public var half:Float=1;
    public var end:Float=1;
    public var maxLevel:Float=50;
    public function new(stat:String,ratio:Float) { this.stat=stat; this.ratio=ratio; }
}

class AttributeRule {
    public var id:String;
    public var index:Int=0;
    public var defaultValue:Float=0;
    public var ceil:Bool=false;
    public var allowNegative:Bool=false;
    public var scaling:Array<ScalingTerm>=[];
    public function new(id:String) this.id=id;
}

class DamageComponent {
    public var affinity:String="Physical";
    public var damageType:String="";
    public var base:Float=0;
    public var scaling:Map<String,Float>=new Map();
    public var delay:Float=0;
    public var ticks:Int=1;
    public var interval:Float=0;
    public var probability:Float=1;
    public var canCrit:Bool=true;
    public var dotGroup:String="";
    public var tickPolicy:String="stack";
    public function new() {}
}

class SkillModel {
    public var id:String;
    public var name:String;
    public var rank:Int=1;
    public var weaponSlot:String="";
    public var actionTime:Float=1;
    public var cooldown:Float=0;
    public var charges:Int=1;
    public var filler:Bool=false;
    public var comboGroup:String="";
    public var comboIndex:Int=0;
    public var comboResetSeconds:Float=0;
    public var isCast:Bool=false;
    public var hits:Array<DamageComponent>=[];
    public var costs:Map<String,Float>=new Map();
    public var gains:Map<String,Float>=new Map();
    public var validated:Bool=false;
    public var issues:Array<String>=[];
    public var evidence:String="";
    public function new(id:String,name:String) { this.id=id; this.name=name; }
    public function copy():SkillModel {
        var s=new SkillModel(id,name);s.rank=rank;s.weaponSlot=weaponSlot;s.actionTime=actionTime;s.cooldown=cooldown;s.charges=charges;s.filler=filler;
        s.comboGroup=comboGroup;s.comboIndex=comboIndex;s.comboResetSeconds=comboResetSeconds;s.isCast=isCast;s.costs=costs.copy();s.gains=gains.copy();s.validated=validated;s.issues=issues.copy();s.evidence=evidence;
        for(h in hits){var d=new DamageComponent();d.affinity=h.affinity;d.damageType=h.damageType;d.base=h.base;d.scaling=h.scaling.copy();d.delay=h.delay;d.ticks=h.ticks;d.interval=h.interval;d.probability=h.probability;d.canCrit=h.canCrit;d.dotGroup=h.dotGroup;d.tickPolicy=h.tickPolicy;s.hits.push(d);}return s;
    }
}

class TalentModel {
    public var id:String;
    public var name:String;
    public var maxRank:Int=1;
    public var tier:Int=0;
    public var branch:Int=0;
    public var tree:String="";
    public var requires:Map<String,Int>=new Map();
    public var perRank:Array<StatContribution>=[];
    public var byRank:Array<Array<StatContribution>>=[];
    public var requiredLowerPoints:Int=0;
    public var validated:Bool=false;
    public var legalityKnown:Bool=true;
    public var reason:String="";
    public function new(id:String,name:String) { this.id=id; this.name=name; }
}

class BuildSnapshot {
    public var character:String="";
    public var capturedAt:String="";
    public var identity:Int=0;
    public var profileGeneration:Int=0;
    public var level:Int=1;
    public var activeWeaponSlot:String="";
    public var weapons:Array<String>=[];
    public var modelVersion:String="";
    public var buildHash:String="";
    public var compatible:Bool=false;
    public var runtimeValidated:Bool=false;
    public var rulesValidated:Bool=false;
    public var base:Map<String,Float>=new Map();
    public var effective:Map<String,Float>=new Map();
    public var permanent:Array<StatContribution>=[];
    public var temporary:Array<StatContribution>=[];
    public var gear:Array<GearSnapshot>=[];
    public var skills:Array<SkillModel>=[];
    public var attributes:Array<AttributeRule>=[];
    public var talents:Array<TalentModel>=[];
    public var talentRanks:Map<String,Int>=new Map();
    public var talentBudget:Int=-1;
    public var resourceCaps:Map<String,Float>=new Map();
    public var resourceMax:Map<String,String>=new Map();
    public var regenRules:Map<String,Array<ResourceRegenRule>>=new Map();
    public var regen:Map<String,Float>=new Map();
    public var issues:Array<String>=[];
    public function new() {}
}

class ResourceRegenRule {
    public var stat:String;
    public var factor:Float;
    public function new(stat:String,factor:Float) { this.stat=stat; this.factor=factor; }
}

class BuildScenario {
    public var label:String="Candidate";
    public var deltas:Map<String,Float>=new Map();
    public var talents:Map<String,Int>=new Map();
    public var priority:Array<String>=[];
    /** Slot replacements are detached primitive snapshots; nothing is equipped in-game. */
    public var gear:Map<String,GearSnapshot>=new Map();
    /** An added, hypothetical gear budget. Base stats and equipped items remain locked. */
    public var adjustableBudget:Int=0;
    public var allocation:Array<Int>=[0,0,0,0];
    public function new() {}
    public function copy():BuildScenario {
        var c=new BuildScenario(); c.label=label; c.deltas=deltas.copy(); c.talents=talents.copy();
        c.priority=priority.copy(); c.adjustableBudget=adjustableBudget; c.allocation=allocation.copy();
        for(slot=>g in gear)c.gear.set(slot,g.copy());return c;
    }
}

class BenchmarkConfig {
    public var sustainedSeconds:Float=60;
    public var burstSeconds:Float=10;
    public var physicalMitigation:Float=0.4;
    public var magicMitigation:Float=0.4;
    public var weaponSwitchSeconds:Float=0;
    public var switchVerified:Bool=false;
    public var targetLabel:String="Reference boss: 40% physical / magic mitigation";
    public function new() {}
    public function copy():BenchmarkConfig {
        var c=new BenchmarkConfig(); c.sustainedSeconds=sustainedSeconds; c.burstSeconds=burstSeconds;
        c.physicalMitigation=physicalMitigation; c.magicMitigation=magicMitigation;
        c.weaponSwitchSeconds=weaponSwitchSeconds; c.switchVerified=switchVerified; c.targetLabel=targetLabel; return c;
    }
}

class DamageTotals {
    public var total:Float=0;
    public var physical:Float=0;
    public var magic:Float=0;
    public var raw:Float=0;
    public var bySkill:Map<String,Float>=new Map();
    public var casts:Map<String,Int>=new Map();
    public function new() {}
    public function add(id:String,amount:Float,category:String):Void {
        total+=amount;
        if (category=="physical") physical+=amount; else if(category=="magic") magic+=amount; else raw+=amount;
        bySkill.set(id,(bySkill.exists(id)?bySkill.get(id):0)+amount);
    }
}

class SimulationResult {
    public var sustained=new DamageTotals();
    public var burst=new DamageTotals();
    public var complete:Bool=false;
    public var issues:Array<String>=[];
    public var stats:Map<String,Float>=new Map();
    public var actions:Int=0;
    public function new() {}
}

class BuildSuggestion {
    public var label:String;
    public var scenario:BuildScenario;
    public var result:SimulationResult;
    public var sustainedGain:Float=0;
    public var burstGain:Float=0;
    public var kind:String;
    public function new(label:String,kind:String,scenario:BuildScenario) {
        this.label=label; this.kind=kind; this.scenario=scenario;
    }
}
