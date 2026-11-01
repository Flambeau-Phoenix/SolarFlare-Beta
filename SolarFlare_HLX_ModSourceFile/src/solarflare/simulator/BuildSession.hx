package solarflare.simulator;

import solarflare.simulator.BuildTypes;
import solarflare.simulator.BuildEvaluator.EvaluationJob;

class BuildComparison {
    public var baseline:SimulationResult;
    public var candidate:SimulationResult;
    public var suggestions:Array<BuildSuggestion>=[];
    public var revision:Int;
    public function new(baseline:SimulationResult,candidate:SimulationResult,revision:Int) {
        this.baseline=baseline; this.candidate=candidate; this.revision=revision;
    }
}

/** Coalesced user requests, generation cancellation and atomic publication. No game objects. */
class BuildSession {
    public var snapshot(default,null):BuildSnapshot;
    public var candidate=new BuildScenario();
    public var benchmark=new BenchmarkConfig();
    public var comparison(default,null):BuildComparison;
    public var status(default,null):String="Open the simulator to capture a build.";
    public var revision(default,null):Int=0;
    public var captureCount(default,null):Int=0;
    public var calculationCount(default,null):Int=0;
    public var busy(get,never):Bool;
    public var changed(default,null):Bool=false;
    var source:BuildSource;
    var wasOpen=false;
    var identity=-1; var profile=-1;
    var refresh=false; var run=false; var resetCandidate=false; var capturing=false;
    var job:EvaluationJob;
    var jobIndex:Int=0;
    var tasks:Array<BuildSuggestion>=[];
    var scratch:BuildComparison;
    var requestVersion:Int=0;
    public function new(source:BuildSource) this.source=source;
    function get_busy():Bool return capturing || job!=null || refresh || run;
    function setStatus(s:String):Void { if (s!=status) { status=s; revision++; } }
    public function requestCapture():Void { refresh=true; changed=true; requestVersion++; }
    public function requestRun():Void { run=true; changed=true; requestVersion++; }
    public function requestReset():Void { resetCandidate=true; requestRun(); }
    public function close():Void {
        wasOpen=false; refresh=run=capturing=false; job=null; tasks=[]; scratch=null;
        source.reset(); revision++;
    }
    public function observe(open:Bool,identity:Int,profile:Int,units:Int=32):Void {
        try advance(open,identity,profile,units) catch (e:Dynamic) {
            capturing=refresh=run=false; job=null; tasks=[]; scratch=null; comparison=null; changed=false;
            try source.reset() catch (_:Dynamic) {}
            setStatus("Simulator unavailable: "+Std.string(e)); revision++;
        }
    }
    function advance(open:Bool,identity:Int,profile:Int,units:Int):Void {
        if (this.identity!=identity || this.profile!=profile) {
            this.identity=identity; this.profile=profile;
            source.reset(); snapshot=null; comparison=null; job=null; scratch=null; tasks=[]; capturing=false;
            refresh=run=resetCandidate=false; candidate=new BuildScenario(); changed=false;
            setStatus("Character/profile changed. Reopen or Refresh to capture this build."); revision++;
            if (open) refresh=true;
        }
        if (!open) { if (wasOpen) close(); return; }
        if (!wasOpen) refresh=true;
        wasOpen=true;
        if (refresh) {
            refresh=false; run=false; capturing=true; job=null; scratch=null; tasks=[]; comparison=null;
            source.begin(identity,profile); captureCount++; setStatus("Checking build compatibility and capturing...");
        }
        if (capturing) {
            try {
                if (!source.advance(Std.int(Math.max(1,Math.min(8,units))))) return;
                snapshot=source.take(); capturing=false;
                candidate=new BuildScenario();
                if (snapshot!=null) candidate.priority=BuildEvaluator.suggestedPriority(snapshot,candidate);
                run=true; revision++;
            } catch (e:Dynamic) {
                capturing=false; snapshot=null; source.reset(); setStatus("Capture failed: "+Std.string(e)); return;
            }
        }
        if (run && snapshot!=null) {
            run=false;
            if (resetCandidate) { candidate=new BuildScenario(); candidate.priority=BuildEvaluator.suggestedPriority(snapshot,candidate); resetCandidate=false; }
            tasks=[]; scratch=null; comparison=null;
            var baseline=new BuildScenario(); baseline.priority=candidate.priority.copy();
            tasks.push(new BuildSuggestion("Captured build","baseline",baseline));
            tasks.push(new BuildSuggestion("Candidate","candidate",candidate.copy()));
            jobIndex=0; job=new EvaluationJob(snapshot,tasks[0].scenario,benchmark);
            calculationCount++; setStatus("Calculating comparison..."); revision++;
        }
        if (job==null) return;
        // A strict action bound plus the caller's per-frame scheduling prevents full-sweep timers.
        job.advance(Std.int(Math.max(1,Math.min(128,units))),0.002);
        if (!job.done) return;
        tasks[jobIndex].result=job.result; jobIndex++;
        if (jobIndex==2) {
            scratch=new BuildComparison(tasks[0].result,tasks[1].result,requestVersion);
            if (scratch.baseline.complete && scratch.candidate.complete) {
                var suggestions=BuildSuggestions.candidates(snapshot,candidate);
                for (s in suggestions) tasks.push(s);
            }
        }
        if (jobIndex<tasks.length) { job=new EvaluationJob(snapshot,tasks[jobIndex].scenario,benchmark); return; }
        if (scratch!=null) {
            for (i in 2...tasks.length) {
                var s=tasks[i]; if (s.result==null || !s.result.complete) continue;
                s.sustainedGain=BuildSuggestions.gain(s.result.sustained.total,scratch.candidate.sustained.total);
                s.burstGain=BuildSuggestions.gain(s.result.burst.total,scratch.candidate.burst.total);
                scratch.suggestions.push(s);
            }
            scratch.suggestions.sort(function(a,b) {
                var x=a.result.sustained.total, y=b.result.sustained.total;
                return x==y?Reflect.compare(a.label,b.label):(x>y?-1:1);
            });
            comparison=scratch; changed=false; revision++;
            setStatus(comparison.candidate.complete?"Comparison complete. Estimates for the selected benchmark.":"Weapon guide ready. DPS comparison unavailable: model coverage incomplete.");
        }
        job=null; tasks=[]; scratch=null;
    }
}
