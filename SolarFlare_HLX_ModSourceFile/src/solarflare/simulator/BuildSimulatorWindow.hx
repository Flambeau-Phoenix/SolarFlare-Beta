package solarflare.simulator;

import imgui.ImGui;
import imgui.Enums.ImGuiTableFlags;
import imgui.Enums.ImGuiTableColumnFlags;
import imgui.ref.BoolRef;
import imgui.ref.FloatRef;
import imgui.ref.IntRef;
import solarflare.simulator.BuildTypes;
import solarflare.simulator.BuildAdvice.GearFit;
import solarflare.ui.EditorWindow;
import solarflare.ui.UiChrome;
import solarflare.ui.UiLayout;
import solarflare.ui.UiScope;
import solarflare.ui.UiHints;
import solarflare.ui.ThemePalette;
import solarflare.ui.ByteUtil;

private class SimFloatRow {
    public var id:String; public var label:String; public var inputId:String; public var ref:FloatRef;
    public var drawControl:Void->Void;
    public function new(id:String,label:String,value:Float,change:Float->Void) {
        this.id=id; this.label=label; inputId="##sim_delta_"+id; ref=new FloatRef(value);
        drawControl=function() { ImGui.setNextItemWidth(130); if (ImGui.inputFloat(inputId,ref,1,10,"%.2f")) change(ref.get()); };
    }
}
private class SimTalentRow {
    public var label:String; public var note:String; public var inputId:String; public var ref:IntRef;
    public var drawControl:Void->Void;
    public function new(t:TalentModel,value:Int,change:Int->Void) {
        label=t.name; note=t.validated?"Modeled talent":(t.reason!=""?t.reason:"Model verification pending");
        inputId="##sim_talent_"+t.id; ref=new IntRef(value);
        drawControl=function() {
            ImGui.setNextItemWidth(110);
            if (ImGui.inputInt(inputId,ref,1,1)) { var r=Std.int(Math.max(0,Math.min(t.maxRank,ref.get()))); ref.set(r); change(r); }
        };
    }
}
private class SimSkillRow {
    public var id:String; public var title:String; public var timing:String; public var coverage:String;
    public var upId:String; public var downId:String;
    public function new(s:SkillModel) {
        id=s.id; title=s.name; timing="Rank "+s.rank+" / "+s.actionTime+"s action / "+s.cooldown+"s cooldown";
        coverage=s.validated?"Covered":(s.issues.length>0?s.issues.join("; "):"Model verification pending");
        upId="^##sim_up_"+s.id; downId="v##sim_down_"+s.id;
    }
}
private class SimSuggestionRow {
    public var label:String; public var gains:String; public var button:String; public var scenario:BuildScenario;
    public function new(s:BuildSuggestion,index:Int) {
        label=s.label; gains=BuildSimulatorWindow.signed(s.sustainedGain)+" sustained / "+BuildSimulatorWindow.signed(s.burstGain)+" burst";
        button="Preview##sim_suggestion_"+index; scenario=s.scenario;
    }
}
private typedef SimStatLine={label:String,effective:String,solo:String};

/** Rendering owns retained input refs and reads cached strings/primitive records only. */
class BuildSimulatorWindow {
    public var open=new BoolRef(false);
    public var session(default,null):BuildSession;
    var lastRevision=-1;
    var lastSnapshot:BuildSnapshot;
    var lastCandidate:BuildScenario;
    var titleLine="No build captured";
    var modelLine="";
    var captureLine="";
    var capturedCounts="";
    var weaponLine="";
    var summary:Array<String>=[];
    var coverage:Array<String>=[];
    var gearLines:Array<String>=[];
    var traitLines:Array<String>=[];
    var adviceLines:Array<String>=[];
    var gearFits:Array<GearFit>=[];
    var adviceSlots:Array<{id:String,label:String}>=[];
    var adviceSlot="Slot_Chest";
    var adviceSlotTitle="Chest";
    var adviceCandidateLine="";
    var adviceDirty=false;
    var adviceLevel=1;
    var statLines:Array<SimStatLine>=[];
    var skillRows:Array<SimSkillRow>=[];
    var rotationRows:Array<SimSkillRow>=[];
    var statRows:Array<SimFloatRow>=[];
    var filteredStats:Array<SimFloatRow>=[];
    var talentRows:Array<SimTalentRow>=[];
    var filteredTalents:Array<SimTalentRow>=[];
    var suggestions:Array<SimSuggestionRow>=[];
    var filterBytes:hl.Bytes;
    var filter="";
    var filterDirty=false;
    var sortBurst=false;
    var suggestionsDirty=false;
    var pendingSuggestion:BuildScenario;
    var moveId=""; var moveDirection=0;
    var gearEditor=new BuildGearEditor();
    var budget=new IntRef(0);
    var allocations:Array<IntRef>=[new IntRef(0),new IntRef(0),new IntRef(0),new IntRef(0)];
    var allocationIds:Array<String>=["##sim_alloc_str","##sim_alloc_dex","##sim_alloc_int","##sim_alloc_faith"];
    var duration=new FloatRef(60);
    var burstDuration=new FloatRef(10);
    var physicalReduction=new FloatRef(40);
    var magicReduction=new FloatRef(40);
    var bodyFn:Void->Void; var leftFn:Void->Void; var rightFn:Void->Void;
    var statsFn:Void->Void; var statEditorFn:Void->Void; var talentEditorFn:Void->Void;
    var budgetFn:Void->Void; var benchmarkFn:Void->Void;
    var budgetControl:Void->Void; var sustainedControl:Void->Void; var burstControl:Void->Void;
    var physicalControl:Void->Void; var magicControl:Void->Void;
    var allocationControls:Array<Void->Void>=[];
    public function new() {
        session=new BuildSession(new BuildCapture());
        filterBytes=new hl.Bytes(128); ByteUtil.clearBytes(filterBytes,128);
        bodyFn=drawBody; leftFn=drawLeft; rightFn=drawRight; statsFn=drawStatsTable;
        statEditorFn=drawStatEditor; talentEditorFn=drawTalentEditor; budgetFn=drawBudgetProperties; benchmarkFn=drawBenchmarkProperties;
        budgetControl=function() {
            ImGui.setNextItemWidth(130);
            if (ImGui.inputInt("##sim_added_budget",budget,1,10)) {
                var amount=Std.int(Math.max(0,Math.min(10000,budget.get()))); budget.set(amount);
                session.candidate.adjustableBudget=amount;
                // Starting a new budget defaults to Strength; the four inputs then allow any exact split.
                session.candidate.allocation=[amount,0,0,0]; for (i in 0...4) allocations[i].set(session.candidate.allocation[i]);
                session.requestRun();
            }
        };
        for (i in 0...4) {
            var index=i;
            allocationControls.push(function() {
                ImGui.setNextItemWidth(130);
                if (ImGui.inputInt(allocationIds[index],allocations[index],1,10)) {
                    var amount=Std.int(Math.max(0,Math.min(10000,allocations[index].get()))); allocations[index].set(amount);
                    session.candidate.allocation[index]=amount; session.requestRun();
                }
            });
        }
        sustainedControl=function() { ImGui.setNextItemWidth(130); if (ImGui.inputFloat("##sim_sustained",duration,1,10,"%.1f s")) { session.benchmark.sustainedSeconds=duration.get(); session.requestRun(); } };
        burstControl=function() { ImGui.setNextItemWidth(130); if (ImGui.inputFloat("##sim_burst",burstDuration,1,10,"%.1f s")) { session.benchmark.burstSeconds=burstDuration.get(); session.requestRun(); } };
        physicalControl=function() { ImGui.setNextItemWidth(130); if (ImGui.inputFloat("##sim_physical_target",physicalReduction,1,5,"%.1f %%")) { session.benchmark.physicalMitigation=physicalReduction.get()/100; session.requestRun(); } };
        magicControl=function() { ImGui.setNextItemWidth(130); if (ImGui.inputFloat("##sim_magic_target",magicReduction,1,5,"%.1f %%")) { session.benchmark.magicMitigation=magicReduction.get()/100; session.requestRun(); } };
    }
    public function clearTransientState():Void {
        session.close(); pendingSuggestion=null; moveId=""; filter=""; filterDirty=true; ByteUtil.clearBytes(filterBytes,128);
        gearEditor.clear();
        gearFits=[];adviceLines=[];adviceDirty=false;
    }
    /** Called by TelemetryKernel. Idle work is primitive comparisons only. */
    public function observe(identity:Int,profile:Int):Void {
        if (pendingSuggestion!=null) { session.candidate=pendingSuggestion.copy(); pendingSuggestion=null; session.requestRun(); }
        if (moveId!="") {
            var priority=session.candidate.priority; var index=priority.indexOf(moveId); var to=index+moveDirection;
            if (index>=0 && to>=0 && to<priority.length) { var other=priority[to]; priority[to]=priority[index]; priority[index]=other; session.requestRun(); }
            moveId="";
        }
        session.observe(open.get(),identity,profile,32);
        if (!open.get()) return;
        var gearCandidate=gearEditor.observe(session.snapshot,session.candidate);
        if(gearCandidate!=null){session.candidate=gearCandidate;session.requestRun();}
        if (lastRevision!=session.revision || lastCandidate!=session.candidate) { lastRevision=session.revision; rebuild(); }
        if(adviceDirty){adviceDirty=false;rebuildGearFits();}
        if (filterDirty) { filterDirty=false; filter=ByteUtil.readString(filterBytes,128,true).toLowerCase(); filterRows(); }
        if (suggestionsDirty) { suggestionsDirty=false; rebuildSuggestions(); }
    }
    function rebuild():Void {
        var b=session.snapshot;
        traitLines=b==null?[]:BuildWeaponTraits.describe(b,session.candidate);
        adviceLines=b==null||!b.compatible?[]:BuildAdvice.lines(b,session.candidate,BuildCatalog.load());
        rebuildGearFits();
        titleLine=b==null || b.character==""?"No compatible local build captured":b.character+" / level "+b.level;
        modelLine=b==null?"Compatibility is checked before accessing the character.":"Model "+b.modelVersion+" / bytecode "+b.buildHash.substr(0,12);
        captureLine=b==null?"":("Captured "+b.capturedAt+". Open or Refresh takes a new snapshot.");
        var talentCount=0;if(b!=null)for(_ in b.talentRanks)talentCount++;
        capturedCounts=b==null?"":"Captured: "+b.gear.length+" items / "+b.skills.length+" equipped skills / "+talentCount+" talent entries";
        weaponLine=b==null?"":BuildEquipment.loadout(b,session.candidate);
        if (b!=lastSnapshot || session.candidate!=lastCandidate) {
            lastSnapshot=b; lastCandidate=session.candidate;
            statRows=[]; talentRows=[]; skillRows=[]; gearLines=[];
            budget.set(session.candidate.adjustableBudget);
            for (i in 0...4) allocations[i].set(session.candidate.allocation[i]);
            if (b!=null) {
                for (a in b.attributes) {
                    var id=a.id;
                    statRows.push(new SimFloatRow(id,id,BuildEvaluator.value(session.candidate.deltas,id),function(value) { session.candidate.deltas.set(id,value); session.requestRun(); }));
                }
                for (t in b.talents) {
                    var id=t.id;
                    talentRows.push(new SimTalentRow(t,BuildEvaluator.rank(b,session.candidate,id),function(value) { session.candidate.talents.set(id,value); session.requestRun(); }));
                }
                for (s in BuildEquipment.skills(b,session.candidate)) skillRows.push(new SimSkillRow(s));
                for (g in BuildEquipment.gear(b,session.candidate)) {
                    gearLines.push((session.candidate.gear.exists(g.slot)?"Candidate: ":"Captured: ")+g.name+" / "+g.slot+" / item level "+g.itemLevel+" / affix factor "+format(g.affixFactor));
                    for (c in g.contributions) gearLines.push("  "+c.source+": "+format(c.value)+" "+c.stat+" ("+c.operation+")"+(c.value!=c.rawValue?" / raw "+format(c.rawValue):"")+(c.known?"":" / not modeled"));
                    for (note in g.notes) gearLines.push("  "+note);
                }
            }
            filterRows();
        }
        rotationRows=[];
        for (id in session.candidate.priority) for (s in skillRows) if (s.id==id) { rotationRows.push(s); break; }
        summary=[]; coverage=[]; statLines=[];
        if (b!=null) {
            for(issue in b.issues) if(coverage.indexOf(issue)<0)coverage.push(issue);
            var solo=BuildEvaluator.stats(b,session.candidate);
            for (a in b.attributes) statLines.push({label:a.id,effective:format(BuildEvaluator.value(b.effective,a.id,Math.NaN)),solo:b.rulesValidated?format(BuildEvaluator.value(solo,a.id,Math.NaN)):"unverified"});
        }
        var comparison=session.comparison;
        if (comparison!=null) {
            var current=comparison.baseline, candidate=comparison.candidate;
            if (current.complete && candidate.complete) {
                summary.push("Sustained ("+format(session.benchmark.sustainedSeconds)+" seconds)");
                summary.push("Captured: "+format(current.sustained.total)+" damage / "+format(current.sustained.total/session.benchmark.sustainedSeconds)+" DPS");
                summary.push("Candidate: "+format(candidate.sustained.total)+" damage / "+signed(BuildSuggestions.gain(candidate.sustained.total,current.sustained.total)));
                summary.push("Burst ("+format(session.benchmark.burstSeconds)+" seconds)");
                summary.push("Captured: "+format(current.burst.total)+" / Candidate: "+format(candidate.burst.total)+" / "+signed(BuildSuggestions.gain(candidate.burst.total,current.burst.total)));
                summary.push("Candidate physical: "+format(candidate.sustained.physical)+" / magic: "+format(candidate.sustained.magic));
                for (s in skillRows) summary.push(s.title+": "+format(BuildEvaluator.value(candidate.sustained.bySkill,s.id))+" sustained / "+format(BuildEvaluator.value(candidate.burst.bySkill,s.id))+" burst");
            } else summary.push("A complete-build damage score is unavailable until the coverage checks below pass.");
            for (issue in current.issues.concat(candidate.issues)) if (coverage.indexOf(issue)<0) coverage.push(issue);
        }
        rebuildSuggestions();
    }
    function filterRows():Void {
        filteredStats=[]; for (r in statRows) if (filter=="" || r.label.toLowerCase().indexOf(filter)>=0) filteredStats.push(r);
        filteredTalents=[]; for (r in talentRows) if (filter=="" || r.label.toLowerCase().indexOf(filter)>=0) filteredTalents.push(r);
    }
    function rebuildGearFits():Void {
        var b=session.snapshot;gearFits=[];adviceCandidateLine="";
        if(b==null||!b.compatible)return;
        var catalog=BuildCatalog.load();
        if(adviceSlots.length==0)adviceSlots=[for(id in catalog.gearSlots){id:id,label:catalog.slotName(id)+"##sim_fit_slot_"+id}];
        adviceSlotTitle=catalog.slotName(adviceSlot);
        if(session.candidate.gear.exists(adviceSlot))adviceCandidateLine="Candidate: "+session.candidate.gear.get(adviceSlot).name;
        adviceLevel=0;for(g in b.gear)if(g.slot==adviceSlot)adviceLevel=g.itemLevel;
        // Preserve native item power levels (e.g. 370 at character level 25).
        if(adviceLevel<=0)for(g in b.gear)if(g.itemLevel>adviceLevel)adviceLevel=g.itemLevel;
        if(adviceLevel<=0)adviceLevel=1;
        gearFits=BuildAdvice.picks(catalog,b,session.candidate,adviceSlot);
    }
    function rebuildSuggestions():Void {
        suggestions=[]; var comparison=session.comparison;
        if (comparison==null || !comparison.candidate.complete) return;
        var ranked=comparison.suggestions.copy();
        if (sortBurst) ranked.sort(function(a,b) {
            var x=a.result.burst.total, y=b.result.burst.total;
            return x==y?Reflect.compare(a.label,b.label):(x>y?-1:1);
        });
        var talents=0, splits=0;
        for (s in ranked) {
            if (s.kind=="talent" && talents++>=5) continue;
            if (s.kind=="split" && splits++>=5) continue;
            suggestions.push(new SimSuggestionRow(s,suggestions.length));
        }
    }
    public function draw():Void {
        if (!open.get()) return;
        EditorWindow.drawMenuWindow("Build Simulator###SolarFlare.BuildSimulator",open,1100,760,bodyFn,false,true,900,650);
    }
    function drawBody():Void {
        if (UiChrome.ghostButton("Refresh##sim_refresh",ImGui.vec2(120,26))) session.requestCapture();
        ImGui.sameLine(0,8);
        if (UiChrome.ghostButton("Run Comparison##sim_run",ImGui.vec2(150,26))) session.requestRun();
        ImGui.sameLine(0,8);
        if (UiChrome.ghostButton("Reset Candidate##sim_reset",ImGui.vec2(150,26))) session.requestReset();
        ImGui.text(titleLine); if (weaponLine!="") ImGui.textWrapped(weaponLine);
        ImGui.textDisabled(modelLine); if (captureLine!="") ImGui.textDisabled(captureLine);
        if(capturedCounts!="")ImGui.textDisabled(capturedCounts);
        ImGui.textColored(ThemePalette.status(session.busy?ThemePalette.STATUS_INFO:(coverage.length>0?ThemePalette.STATUS_WARN:ThemePalette.STATUS_INFO)),session.status);
        UiChrome.gap(UiChrome.SP_S);
        var avail=ImGui.getContentRegionAvail(); var gap:Single=12; var leftW:Single=(avail.x-gap)*0.60;
        UiChrome.celChild("##sim_left",ImGui.vec2(leftW,avail.y),leftFn);
        ImGui.sameLine(0,gap);
        UiChrome.celChild("##sim_right",ImGui.vec2(avail.x-gap-leftW,avail.y),rightFn);
    }
    function drawLeft():Void {
        if (!ImGui.beginTabBar("##sim_details")) return;
        if(ImGui.beginTabItem("Weapon guide##sim_logic")){
            UiChrome.subHeader("Suggested stat direction");
            for(line in adviceLines)ImGui.textWrapped(line);
            UiChrome.subHeader("Skill scaling details");
            for(line in traitLines)ImGui.textWrapped(line);
            if(traitLines.length==0)ImGui.textWrapped("Refresh to capture equipped weapons and their skills.");
            ImGui.endTabItem();
        }
        if (ImGui.beginTabItem("Comparison##sim_results")) {
            UiChrome.subHeader("Build comparison");
            if (summary.length==0) ImGui.textWrapped("Capture a compatible build, then edit a candidate to compare it.");
            for (line in summary) ImGui.textWrapped(line);
            if (coverage.length>0) { UiChrome.subHeader("Model coverage"); for (line in coverage) ImGui.textWrapped(line); }
            ImGui.endTabItem();
        }
        if (ImGui.beginTabItem("Gear##sim_gear")) {
            UiChrome.subHeader("Items and their contributions");
            UiHints.noteWrapped("Raw flat values and modifiers are listed separately. Socket and infusion rows are parts of the item's aggregate, counted once.");
            if (gearLines.length==0) ImGui.textWrapped("No equipment snapshot is available. Press Refresh; captured item counts and any capture issues appear above and in Comparison.");
            for (line in gearLines) ImGui.textWrapped(line);
            ImGui.endTabItem();
        }
        if (ImGui.beginTabItem("Skills##sim_skills")) {
            if (skillRows.length==0) ImGui.textWrapped("No equipped skill snapshot is available.");
            for (r in skillRows) { UiChrome.subHeader(r.title); ImGui.textDisabled(r.timing); ImGui.textWrapped(r.coverage); }
            ImGui.endTabItem();
        }
        if (ImGui.beginTabItem("Stats##sim_stats")) {
            UiHints.noteWrapped("Captured effective stats include the conditions at capture. Solo candidate stats exclude identified temporary effects. Unverified values show as unknown.");
            UiScope.table("##sim_stats_table",3,statsFn,ImGuiTableFlags.BordersOuter|ImGuiTableFlags.BordersInnerH|ImGuiTableFlags.SizingStretchProp);
            ImGui.endTabItem();
        }
        ImGui.endTabBar();
    }
    function drawStatsTable():Void {
        ImGui.tableSetupColumn("Stat",ImGuiTableColumnFlags.WidthStretch,0.50);
        ImGui.tableSetupColumn("Captured",ImGuiTableColumnFlags.WidthStretch,0.25);
        ImGui.tableSetupColumn("Solo candidate",ImGuiTableColumnFlags.WidthStretch,0.25); ImGui.tableHeadersRow();
        for (r in statLines) { ImGui.tableNextRow(); ImGui.tableNextColumn(); ImGui.text(r.label); ImGui.tableNextColumn(); ImGui.text(r.effective); ImGui.tableNextColumn(); ImGui.text(r.solo); }
    }
    function drawRight():Void {
        UiHints.noteWrapped("Hypothetical changes only. Nothing is applied to your character.");
        if (ImGui.inputTextWithHint("##sim_filter","Filter stats or talents...",filterBytes,128)) filterDirty=true;
        if (!ImGui.beginTabBar("##sim_editors")) return;
        if(ImGui.beginTabItem("Gear picks##sim_gear_picks")){
            ImGui.textWrapped("CDB aptitude matches for the current weapon profiles. These are starting points to inspect, not proven BiS or guaranteed upgrades.");
            ImGui.setNextItemWidth(230);
            if(ImGui.beginCombo("##sim_fit_slot",adviceSlotTitle)){
                for(x in adviceSlots)if(ImGui.selectable(x.label,x.id==adviceSlot)){adviceSlot=x.id;adviceDirty=true;}
                ImGui.endCombo();
            }
            ImGui.textWrapped("Trait fit = average supported weapon count across the item's primary stats. Same-score items tie; five examples are shown alphabetically. Rarity, level, secondary stats and unique effects do not affect this fit score.");
            if(gearFits.length==0)ImGui.textWrapped("No matching primary-stat aptitude records for this slot. The Gear tab still allows browsing all compatible items.");
            ImGui.beginDisabled(adviceDirty||session.snapshot==null);
            for(x in gearFits){
                UiChrome.subHeader(x.name);ImGui.textWrapped(x.detail);
                if(UiChrome.ghostButton(x.button,ImGui.vec2(100,24)))gearEditor.queuePreview(x.slot,x.id,adviceLevel);
            }
            ImGui.endDisabled();
            if(adviceCandidateLine!="")ImGui.textWrapped(adviceCandidateLine);
            ImGui.textWrapped(gearEditor.status);
            ImGui.textWrapped("Preview uses the captured slot's item power level. Open Gear to inspect or restore the candidate; no items are equipped in-game.");
            ImGui.endTabItem();
        }
        if(ImGui.beginTabItem("Gear##sim_gear_edit_tab")){gearEditor.draw();ImGui.endTabItem();}
        if (ImGui.beginTabItem("Stats##sim_stat_edit_tab")) {
            UiChrome.subHeader("Gear stat deltas");
            UiHints.noteWrapped("Enter changes in each stat's native units. Percentage stats use percentage points.");
            if (filteredStats.length==0) UiHints.noteWrapped("No matching stats. Capture a build or clear the filter.");
            UiLayout.propertyGrid("##sim_stat_edits",statEditorFn);
            UiChrome.subHeader("Added primary-stat budget");
            UiHints.noteWrapped("Hypothetical gear allocation. Existing equipment and base stats remain fixed. The four allocations must sum to the added budget.");
            UiLayout.propertyGrid("##sim_budget",budgetFn);
            ImGui.endTabItem();
        }
        if (ImGui.beginTabItem("Talents##sim_talent_edit_tab")) {
            UiHints.noteWrapped("Candidate ranks share the captured point budget. Unsupported effects or unlock rules prevent a recommendation.");
            if (filteredTalents.length==0) UiHints.noteWrapped("No matching talents. Capture a build or clear the filter.");
            UiLayout.propertyGrid("##sim_talents",talentEditorFn);
            ImGui.endTabItem();
        }
        if (ImGui.beginTabItem("Rotation##sim_rotation_tab")) {
            UiHints.noteWrapped("Top priority is tried first when cooldowns, resources and weapon restrictions allow. The same priority is used for every comparison.");
            if (rotationRows.length==0) UiHints.noteWrapped("No equipped skills are available for a suggested rotation.");
            for (r in rotationRows) {
                if (UiChrome.ghostButton(r.upId,ImGui.vec2(24,22))) { moveId=r.id; moveDirection=-1; }
                ImGui.sameLine(0,4);
                if (UiChrome.ghostButton(r.downId,ImGui.vec2(24,22))) { moveId=r.id; moveDirection=1; }
                ImGui.sameLine(0,8); ImGui.alignTextToFramePadding(); ImGui.pushTextWrapPos(0); ImGui.text(r.title); ImGui.popTextWrapPos();
            }
            ImGui.endTabItem();
        }
        if (ImGui.beginTabItem("Benchmark##sim_benchmark_tab")) {
            UiHints.noteWrapped("Stationary solo reference target. Full starting resources and available cooldowns; temporary external buffs and encounter mechanics are excluded.");
            UiLayout.propertyGrid("##sim_benchmark",benchmarkFn);
            ImGui.endTabItem();
        }
        if (ImGui.beginTabItem("Suggestions##sim_suggestions_tab")) {
            if (UiChrome.ghostButton("Sustained##sim_sort_sustained",ImGui.vec2(110,24))) { sortBurst=false; suggestionsDirty=true; }
            ImGui.sameLine(0,8);
            if (UiChrome.ghostButton("Burst##sim_sort_burst",ImGui.vec2(90,24))) { sortBurst=true; suggestionsDirty=true; }
            UiHints.noteWrapped("Stat gains use +1 native unit; compare actual gear deltas before choosing between stats with different item budgets. Split and talent previews preserve their respective budgets.");
            if (suggestions.length==0) ImGui.textWrapped("Suggestions require complete, validated model coverage. Check the Comparison view for missing coverage.");
            for (r in suggestions) { ImGui.textWrapped(r.label); ImGui.textWrapped(r.gains); if (UiChrome.ghostButton(r.button,ImGui.vec2(100,24))) pendingSuggestion=r.scenario; }
            ImGui.endTabItem();
        }
        ImGui.endTabBar();
    }
    function drawStatEditor():Void { for (r in filteredStats) UiLayout.propertyRow(r.label,r.drawControl,r.label); }
    function drawTalentEditor():Void { for (r in filteredTalents) UiLayout.propertyRow(r.label,r.drawControl,r.note); }
    function drawBudgetProperties():Void {
        UiLayout.propertyRow("Added budget",budgetControl);
        for (i in 0...4) UiLayout.propertyRow(BuildEvaluator.PRIMARY[i],allocationControls[i]);
    }
    function drawBenchmarkProperties():Void {
        UiLayout.propertyRow("Sustained",sustainedControl); UiLayout.propertyRow("Burst",burstControl);
        UiLayout.propertyRow("Physical mitigation",physicalControl); UiLayout.propertyRow("Magic mitigation",magicControl);
    }
    public static function format(v:Float):String return BuildEvaluator.finite(v)?Std.string(Math.round(v*100)/100):"unknown";
    public static function signed(v:Float):String return BuildEvaluator.finite(v)?(v>=0?"+":"")+format(v)+"%":"n/a";
}
