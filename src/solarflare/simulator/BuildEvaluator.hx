package solarflare.simulator;

import solarflare.simulator.BuildTypes;

/** Offline evaluator. No engine calls, reflection, filesystem access or random sampling. */
class BuildEvaluator {
    public static var PRIMARY(default,null):Array<String>=["Strength","Dexterity","Intellect","Faith"];
    public static inline function value(m:Map<String,Float>,key:String,fallback:Float=0):Float
        return m.exists(key)?m.get(key):fallback;
    public static inline function finite(v:Float):Bool return Math.isFinite(v) && !Math.isNaN(v);
    public static inline function clamp(v:Float,lo:Float,hi:Float):Float return Math.max(lo,Math.min(hi,v));

    public static function rank(b:BuildSnapshot,s:BuildScenario,id:String):Int
        return s.talents.exists(id)?s.talents.get(id):(b.talentRanks.exists(id)?b.talentRanks.get(id):0);

    public static function validate(b:BuildSnapshot,s:BuildScenario,c:BenchmarkConfig):Array<String> {
        var errors=b.issues.copy();
        if (!b.compatible) errors.push("Installed game and model builds do not match.");
        if (!b.runtimeValidated) errors.push("Live damage and stat reconciliation have not been validated for this model.");
        if (!b.rulesValidated) errors.push("Damage/defense rules still require source verification.");
        if (!finite(c.sustainedSeconds) || !finite(c.burstSeconds) || c.sustainedSeconds<=0 || c.burstSeconds<=0
            || c.sustainedSeconds>300 || c.burstSeconds>300) errors.push("Benchmark duration must be 0 < seconds <= 300.");
        if (!finite(c.physicalMitigation) || !finite(c.magicMitigation) || c.physicalMitigation<0 || c.physicalMitigation>=1
            || c.magicMitigation<0 || c.magicMitigation>=1) errors.push("Target mitigation must be between 0 and 100% (exclusive).");
        if (!finite(c.weaponSwitchSeconds) || c.weaponSwitchSeconds<0) errors.push("Invalid weapon switch time.");
        var availableSkills=BuildEquipment.skills(b,s);
        if (availableSkills.length==0) errors.push("No equipped damaging skills were captured.");
        var slots=new Map<String,Bool>();
        for (skill in availableSkills) {
            if (!skill.validated) errors.push(skill.name+": "+(skill.issues.length>0?skill.issues.join("; "):"skill model not verified"));
            if (!finite(skill.actionTime) || skill.actionTime<=0 || !finite(skill.cooldown) || skill.cooldown<0)
                errors.push(skill.name+": invalid action/cooldown timing");
            if (skill.weaponSlot!="") slots.set(skill.weaponSlot,true);
            if (skill.charges<1 || skill.charges>20) errors.push(skill.name+": unsupported charge count");
            for (id=>cost in skill.costs) {
                if (!finite(cost) || cost<0) errors.push(skill.name+": invalid resource cost");
                if (!b.resourceCaps.exists(id) && !b.resourceMax.exists(id) && !b.base.exists(id)) errors.push("Unknown resource capacity: "+id);
            }
            for (h in skill.hits) {
                if (!finite(h.base) || !finite(h.delay) || h.delay<0 || !finite(h.interval) || h.interval<0 || h.ticks<1 || h.ticks>1000
                    || !finite(h.probability) || h.probability<0 || h.probability>1) errors.push(skill.name+": invalid damage component");
                if (h.tickPolicy!="stack" && h.tickPolicy!="refresh") errors.push(skill.name+": unsupported ticking policy");
                if (h.tickPolicy=="refresh" && h.dotGroup=="") errors.push(skill.name+": refreshing damage requires an explicit status group");
                for (id=>v in h.scaling) if (!finite(v)) errors.push(skill.name+": non-finite scaling for "+id);
            }
        }
        for(g in BuildEquipment.gear(b,s)){for(issue in g.issues)errors.push(g.name+": "+issue);for(c in g.contributions)if(!c.known||!finite(c.value))errors.push(g.name+": unsupported contribution");}
        var removed=BuildEquipment.removedGrants(b,s);
        for (c in b.permanent) if (!removed.exists(c.source)&&(!c.known || !finite(c.value))) errors.push(c.source+": unsupported permanent contribution");
        for (id=>v in b.regen) if (!finite(v) || v<0) errors.push("Unsupported resource regeneration: "+id);
        var slotCount=0; for (_ in slots) slotCount++;
        if (slotCount>1 && !c.switchVerified) errors.push("Weapon switching restrictions have not been verified.");
        var oldBudget=0; for (v in b.talentRanks) oldBudget+=v;
        if (b.talentBudget>=0) oldBudget=b.talentBudget;
        var newBudget=0; var known=new Map<String,Bool>();
        for (t in b.talents) {
            known.set(t.id,true);
            var r=rank(b,s,t.id); newBudget+=r;
            if (r<0 || r>t.maxRank) errors.push(t.name+": rank outside allowed range");
            if (r>0 && !t.validated) errors.push(t.name+": "+(t.reason!=""?t.reason:"talent damage effect not verified"));
            var old=b.talentRanks.exists(t.id)?b.talentRanks.get(t.id):0;
            if (r!=old && !t.legalityKnown) errors.push(t.name+": talent unlock rules have not been verified");
            if (r>0) for (id=>minimum in t.requires)
                if (rank(b,s,id)<minimum) errors.push(t.name+": requires "+id+" rank "+minimum);
            if (r>0 && t.requiredLowerPoints>0) {
                var points=0;
                for (other in b.talents) if (other.tree==t.tree && other.tier<t.tier
                    && (other.branch==0 || t.branch==0 || other.branch==t.branch)) points+=rank(b,s,other.id);
                if (points<t.requiredLowerPoints) errors.push(t.name+": lower-tier point requirement not met");
            }
        }
        for (id=>r in b.talentRanks) if (!known.exists(id) && r>0) errors.push("Unknown allocated talent: "+id);
        for (id=>r in s.talents) if (!known.exists(id) && r!=0) errors.push("Unknown candidate talent: "+id);
        if (newBudget>oldBudget) errors.push("Candidate exceeds captured talent point budget.");
        var total=0;
        if (s.allocation.length!=4 || s.adjustableBudget<0 || s.adjustableBudget>10000) errors.push("Invalid adjustable primary-stat budget.");
        for (v in s.allocation) { total+=v; if (v<0) errors.push("Primary-stat allocations cannot be negative."); }
        if (total!=s.adjustableBudget) errors.push("Primary-stat allocation must equal its hypothetical gear budget.");
        for (k=>v in s.deltas) if (!finite(v)) errors.push("Non-finite stat delta: "+k);
        return errors;
    }

    /** Re-evaluate derived stats from raw base + disjoint sources, never add deltas to baked effective stats. */
    public static function stats(b:BuildSnapshot,s:BuildScenario):Map<String,Float> {
        var raw=b.base.copy(); var adds=new Map<String,Float>(); var mults=new Map<String,Float>();
        function apply(c:StatContribution):Void {
            if (!c.known || !finite(c.value)) return;
            switch c.operation {
                case "flat": raw.set(c.stat,value(raw,c.stat)+c.value);
                case "percent": adds.set(c.stat,value(adds,c.stat)+c.value/100);
                case "multiply": mults.set(c.stat,value(mults,c.stat,1)*(1+c.value/100));
                default:
            }
        }
        for (g in BuildEquipment.gear(b,s)) for (c in g.contributions) apply(c);
        var removed=BuildEquipment.removedGrants(b,s);
        for (c in b.permanent) if(!removed.exists(c.source))apply(c);
        for (t in b.talents) {
            var r=rank(b,s,t.id);
            if (t.byRank.length>r && r>=0) for (c in t.byRank[r]) apply(c);
            else for (c in t.perRank) { var copy=c.copy(); copy.value*=r; apply(copy); }
        }
        for (k=>v in s.deltas) raw.set(k,value(raw,k)+v);
        for (i in 0...4) if (i<s.allocation.length) raw.set(PRIMARY[i],value(raw,PRIMARY[i])+s.allocation[i]);
        var out=new Map<String,Float>(); var visiting=new Map<String,Bool>(); var rules=new Map<String,AttributeRule>();
        for (a in b.attributes) rules.set(a.id,a);
        function resolve(id:String):Float {
            if (out.exists(id)) return out.get(id);
            if (visiting.exists(id)) return Math.NaN;
            visiting.set(id,true);
            var rule=rules.get(id); var v=value(raw,id,rule==null?0:rule.defaultValue);
            if (rule!=null) for (term in rule.scaling) {
                var x=resolve(term.stat);
                v+=switch term.operation {
                    case "linear": x*term.ratio;
                    case "saturating": term.half>0 && x>=0 ? term.ratio*term.cap*x/(x+term.half) : Math.NaN;
                    case "rating": term.half>0 && term.end>0 && term.maxLevel>1
                        ? x*term.cap/(term.half*Math.pow(term.end/term.half,(b.level-1)/(term.maxLevel-1))) : Math.NaN;
                    default: Math.NaN;
                };
            }
            v*= (1+value(adds,id))*value(mults,id,1);
            if (rule!=null) { if (rule.ceil) v=Math.ceil(v); if (!rule.allowNegative) v=Math.max(0,v); }
            visiting.remove(id); out.set(id,v); return v;
        }
        for (id in raw.keys()) resolve(id);
        for (id in rules.keys()) resolve(id);
        return out;
    }

    public static function suggestedPriority(b:BuildSnapshot,s:BuildScenario):Array<String> {
        var st=stats(b,s); var skills=BuildEquipment.skills(b,s);
        skills.sort(function(a,b) {
            if (a.filler!=b.filler) return a.filler?1:-1;
            var x=rawDamage(a,st)/Math.max(0.05,a.actionTime), y=rawDamage(b,st)/Math.max(0.05,b.actionTime);
            return x==y?Reflect.compare(a.id,b.id):(x>y?-1:1);
        });
        return [for (skill in skills) skill.id];
    }
    static function rawDamage(skill:SkillModel,st:Map<String,Float>):Float {
        var total=0.; for (h in skill.hits) { var v=h.base; for (id=>c in h.scaling) v+=value(st,id)*c; total+=v*h.ticks*h.probability; } return total;
    }
    public static function run(b:BuildSnapshot,s:BuildScenario,c:BenchmarkConfig):SimulationResult {
        var job=new EvaluationJob(b,s,c); while (!job.done) job.advance(128); return job.result;
    }
}

/** One scenario can be paused between actions; no partly-built result is published. */
class EvaluationJob {
    public var result(default,null)=new SimulationResult();
    public var done(default,null)=false;
    var b:BuildSnapshot; var s:BuildScenario; var c:BenchmarkConfig;
    var skills:Array<SkillModel>=[];
    var ready:Array<Array<Float>>=[];
    var resources=new Map<String,Float>(); var caps=new Map<String,Float>();
    var regeneration=new Map<String,Float>();
    var comboNext=new Map<String,Int>(); var comboCounts=new Map<String,Int>(); var comboLast=new Map<String,Float>();
    var dotGenerations=new Map<String,Int>();
    var events:Array<PendingDamage>=[]; var eventHead=0;
    var time:Float=0; var lastResourceTime:Float=0; var horizon:Float=0; var weapon:String="";
    public function new(b:BuildSnapshot,s:BuildScenario,c:BenchmarkConfig) {
        this.b=b; this.s=s.copy(); this.c=c.copy();
        weapon=b.activeWeaponSlot;
        result.issues=BuildEvaluator.validate(b,s,c); result.stats=BuildEvaluator.stats(b,s);
        for (id=>v in result.stats) if (!BuildEvaluator.finite(v)) result.issues.push("Unresolved attribute conversion: "+id);
        for (id in BuildEvaluator.PRIMARY) if (BuildEvaluator.value(result.stats,id)<0) result.issues.push("Negative primary stat: "+id);
        result.complete=result.issues.length==0;
        var priority=s.priority.length==0?BuildEvaluator.suggestedPriority(b,s):s.priority;
        var availableSkills=BuildEquipment.skills(b,s);
        var seen=new Map<String,Bool>();
        for (id in priority) {
            if (seen.exists(id)) continue; seen.set(id,true);
            for (skill in availableSkills) if (skill.id==id) { skills.push(skill); break; }
        }
        if (skills.length!=availableSkills.length) { result.complete=false; result.issues.push("Priority must include every available skill exactly once."); }
        for (skill in skills) ready.push([for (_ in 0...Std.int(Math.max(1,Math.min(20,skill.charges)))) 0.]);
        for (skill in skills) if (skill.comboGroup!="") {
            var n=comboCounts.exists(skill.comboGroup)?comboCounts.get(skill.comboGroup):0;
            comboCounts.set(skill.comboGroup,Std.int(Math.max(n,skill.comboIndex+1)));
            comboNext.set(skill.comboGroup,0);
        }
        for (skill in skills) for (id in skill.costs.keys()) {
            var max=b.resourceMax.exists(id)?BuildEvaluator.value(result.stats,b.resourceMax.get(id))
                :BuildEvaluator.value(b.resourceCaps,id,BuildEvaluator.value(result.stats,id));
            caps.set(id,Math.max(0,max)); resources.set(id,Math.max(0,max));
        }
        regeneration=b.regen.copy();
        for (id=>rules in b.regenRules) {
            var amount=0.; for (r in rules) amount+=BuildEvaluator.value(result.stats,r.stat)*r.factor;
            regeneration.set(id,amount);
        }
        horizon=Math.max(c.sustainedSeconds,c.burstSeconds);
        if (!BuildEvaluator.finite(horizon) || horizon<=0 || horizon>300 || skills.length==0) done=true;
    }
    public function advance(maxActions:Int,budgetSeconds:Float=0):Void {
        var count=0;
        var deadline=budgetSeconds>0?haxe.Timer.stamp()+budgetSeconds:0;
        while (!done && count++<maxActions) {
            step();
            if (deadline>0 && haxe.Timer.stamp()>=deadline) break;
        }
    }
    function step():Void {
        flushDamage(Math.min(time,horizon));
        if (time>=horizon || result.actions>=10000) { done=true; if (result.actions>=10000) { result.complete=false; result.issues.push("Action budget exceeded."); } return; }
        replenish(time);
        var chosen=-1, charge=0; var next=horizon;
        for (i in 0...skills.length) {
            var skill=skills[i]; var r=ready[i]; var slot=0;
            if (skill.comboGroup!="") {
                if (skill.comboResetSeconds>0 && comboLast.exists(skill.comboGroup) && time-comboLast.get(skill.comboGroup)>skill.comboResetSeconds)
                    comboNext.set(skill.comboGroup,0);
                if (skill.comboIndex!=comboNext.get(skill.comboGroup)) continue;
            }
            for (j in 1...r.length) if (r[j]<r[slot]) slot=j;
            if (r[slot]>time+0.000001) { next=Math.min(next,r[slot]); continue; }
            var affordable=true;
            for (id=>cost in skill.costs) if (cost>BuildEvaluator.value(resources,id)+0.000001) {
                affordable=false; var regen=BuildEvaluator.value(regeneration,id);
                if (regen>0 && cost<=BuildEvaluator.value(caps,id)) next=Math.min(next,time+(cost-BuildEvaluator.value(resources,id))/regen);
            }
            if (affordable) { chosen=i; charge=slot; break; }
        }
        if (chosen<0) { time=Math.max(time+0.0001,next); return; }
        var skill=skills[chosen];
        if (weapon!="" && skill.weaponSlot!="" && weapon!=skill.weaponSlot) {
            time+=Math.max(0,c.weaponSwitchSeconds); flushDamage(Math.min(time,horizon)); if (time>=horizon) { done=true; return; }
            replenish(time);
        }
        if (skill.weaponSlot!="") weapon=skill.weaponSlot;
        for (id=>cost in skill.costs) resources.set(id,BuildEvaluator.value(resources,id)-cost);
        for (id=>gain in skill.gains) if (caps.exists(id)) resources.set(id,Math.min(caps.get(id),BuildEvaluator.value(resources,id)+gain));
        var st=result.stats;
        var crit=BuildEvaluator.clamp(BuildEvaluator.value(st,"CritChance")/100,0,1);
        var critMult=Math.max(1,BuildEvaluator.value(st,"CritDamage",150)/100);
        for (hit in skill.hits) {
            var amount=hit.base;
            for (id=>ratio in hit.scaling) amount+=BuildEvaluator.value(st,id)*ratio;
            var category=hit.damageType!=""?hit.damageType:(hit.affinity=="Physical"?"physical":"magic");
            var physical=category=="physical";
            if (category!="raw") amount*=1+BuildEvaluator.value(st,physical?"PhysicalMastery":"MagicMastery")/100;
            amount*=1+BuildEvaluator.value(st,"Fervor")/100;
            amount*=BuildEvaluator.value(st,"DamageModifier",100)/100;
            if (hit.canCrit) amount*=1+crit*(critMult-1);
            var mitigation=category=="raw"?0:(physical?c.physicalMitigation:c.magicMitigation);
            var pen=BuildEvaluator.clamp(BuildEvaluator.value(st,physical?"ArmorPenetration":"SpellPenetration")/100,0,1);
            // R/(R+K), R' = R*(1-penetration). Substituting R = mitigation*K/(1-mitigation) cancels K.
            var reduced=mitigation*(1-pen)/(1-mitigation*pen);
            amount*=hit.probability*(1-reduced);
            if (!BuildEvaluator.finite(amount) || amount<0) { result.complete=false; continue; }
            var ticks=Std.int(Math.max(1,Math.min(1000,hit.ticks)));
            var group=hit.tickPolicy=="refresh"?hit.dotGroup:"";
            var generation=0;
            if (group!="") { generation=(dotGenerations.exists(group)?dotGenerations.get(group):0)+1; dotGenerations.set(group,generation); }
            for (j in 0...ticks) {
                var at=time+hit.delay+j*hit.interval;
                if (BuildEvaluator.finite(at) && at<horizon) schedule(new PendingDamage(at,skill.id,amount,category,group,generation));
            }
        }
        for (bucket in [result.sustained,result.burst]) {
            var limit=bucket==result.sustained?c.sustainedSeconds:c.burstSeconds;
            if (time<limit) bucket.casts.set(skill.id,(bucket.casts.exists(skill.id)?bucket.casts.get(skill.id):0)+1);
        }
        result.actions++;
        if (skill.comboGroup!="") {
            comboNext.set(skill.comboGroup,(skill.comboIndex+1)%comboCounts.get(skill.comboGroup));
            comboLast.set(skill.comboGroup,time);
        }
        var cd=skill.cooldown*Math.max(0,1-BuildEvaluator.value(st,"CooldownReduction")/100);
        ready[chosen][charge]=time+cd;
        time+=Math.max(0.05,skill.actionTime*(skill.isCast?Math.max(0.05,1-BuildEvaluator.value(st,"SpellCastTimeReduction")/100):1));
    }
    function replenish(at:Float):Void {
        for (id in resources.keys()) resources.set(id,Math.min(caps.get(id),resources.get(id)+BuildEvaluator.value(regeneration,id)*(at-lastResourceTime)));
        lastResourceTime=at;
    }
    function schedule(event:PendingDamage):Void {
        if (done) return;
        if (events.length-eventHead>=10000) { result.complete=false; result.issues.push("Pending damage budget exceeded."); done=true; return; }
        var lo=eventHead, hi=events.length;
        while (lo<hi) { var mid=(lo+hi)>>1; if(events[mid].at<=event.at) lo=mid+1; else hi=mid; }
        events.insert(lo,event);
    }
    function flushDamage(until:Float):Void {
        while (eventHead<events.length && events[eventHead].at<=until+0.000001) {
            var event=events[eventHead++];
            if (event.group!="" && dotGenerations.get(event.group)!=event.generation) continue;
            if (event.at<c.sustainedSeconds-0.000001) result.sustained.add(event.skill,event.amount,event.category);
            if (event.at<c.burstSeconds-0.000001) result.burst.add(event.skill,event.amount,event.category);
        }
        if (eventHead>256 && eventHead*2>=events.length) { events=events.slice(eventHead); eventHead=0; }
    }
}

private class PendingDamage {
    public var at:Float; public var skill:String; public var amount:Float; public var category:String;
    public var group:String; public var generation:Int;
    public function new(at:Float,skill:String,amount:Float,category:String,group:String,generation:Int) {
        this.at=at; this.skill=skill; this.amount=amount; this.category=category; this.group=group; this.generation=generation;
    }
}
