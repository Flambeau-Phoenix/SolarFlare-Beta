package solarflare.simulator;

import solarflare.simulator.BuildTypes;

class BuildSuggestions {
    /** 35 quarter-step allocations; largest remainders, ties in PRIMARY order. */
    public static function allocations(budget:Int):Array<Array<Int>> {
        var out=[];
        for (a in 0...5) for (b in 0...(5-a)) for (c in 0...(5-a-b)) {
            var weights=[a,b,c,4-a-b-c]; var parts=[]; var remainders=[]; var used=0;
            for (w in weights) { var n=Std.int(budget*w/4); parts.push(n); remainders.push(budget*w%4); used+=n; }
            while (used<budget) {
                var best=0; for (i in 1...4) if (remainders[i]>remainders[best]) best=i;
                parts[best]++; remainders[best]=-1; used++;
            }
            out.push(parts);
        }
        return out;
    }
    public static function candidates(b:BuildSnapshot,s:BuildScenario):Array<BuildSuggestion> {
        var out:Array<BuildSuggestion>=[];
        for (stat in ["Strength","Dexterity","Intellect","Faith","CritChanceRating","FervorRating","PhysicalMastery","MagicMastery"]) {
            var c=s.copy(); c.deltas.set(stat,BuildEvaluator.value(c.deltas,stat)+1);
            out.push(new BuildSuggestion(stat+" +1 native unit","stat",c));
        }
        if (s.adjustableBudget>0) for (a in allocations(s.adjustableBudget)) {
            var c=s.copy(); c.allocation=a;
            var parts=[]; for (i in 0...4) if (a[i]>0) parts.push(a[i]+" "+BuildEvaluator.PRIMARY[i]);
            out.push(new BuildSuggestion(parts.join(" / "),"split",c));
        }
        for (from in b.talents) if (BuildEvaluator.rank(b,s,from.id)>0 && from.legalityKnown)
            for (to in b.talents) if (to.id!=from.id && to.legalityKnown && BuildEvaluator.rank(b,s,to.id)<to.maxRank) {
                var c=s.copy(); c.talents.set(from.id,BuildEvaluator.rank(b,s,from.id)-1); c.talents.set(to.id,BuildEvaluator.rank(b,s,to.id)+1);
                out.push(new BuildSuggestion(from.name+" -1 / "+to.name+" +1","talent",c));
            }
        return out;
    }
    public static function gain(candidate:Float,baseline:Float):Float return baseline>0?100*(candidate/baseline-1):Math.NaN;
}
