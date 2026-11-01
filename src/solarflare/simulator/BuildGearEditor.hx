package solarflare.simulator;
import solarflare.simulator.BuildTypes;
import imgui.ImGui;
import imgui.ref.IntRef;
import imgui.ref.FloatRef;
import solarflare.ui.ByteUtil;
import solarflare.ui.UiChrome;

private typedef GearChoice={id:String,name:String,label:String,search:String};
private typedef GearRollRow={index:Int,label:String,id:String,value:FloatRef};

/** Search and edits queue primitive requests. CDB/native template capture happens only in observe. */
class BuildGearEditor {
    var catalog:BuildCatalog;
    var snapshot:BuildSnapshot;
    var slots:Array<{id:String,label:String}>=[];
    var choices:Array<GearChoice>=[];
    var slot="";var item="";var query="";var dirty=true;
    var levelSlot="";
    var filter=new hl.Bytes(160);var level=new IntRef(1);
    var requested=false;var restore=false;
    var requestSlot="";var requestItem="";var requestLevel=1;
    var current="No build captured.";
    public var status(default,null)="Select a combat gear slot and search the CDB catalogue.";
    var rollRows:Array<GearRollRow>=[];var shownCandidate:BuildScenario;var rollSlot="";
    var editIndex=-1;var editValue=0.;var editSlot="";
    public function new(){filter.setUI8(0,0);}
    public function queuePreview(targetSlot:String,id:String,itemLevel:Int):Void {
        ByteUtil.clearBytes(filter,160);
        slot=targetSlot;item=id;levelSlot=targetSlot;level.set(itemLevel);dirty=true;
        requestSlot=targetSlot;requestItem=id;requestLevel=itemLevel;requested=true;
    }
    public function clear():Void {requested=restore=false;snapshot=null;slot=item=levelSlot="";choices=[];dirty=true;editIndex=-1;rollRows=[];shownCandidate=null;}
    public function observe(b:BuildSnapshot,candidate:BuildScenario):BuildScenario {
        if(b==null){clear();return null;}
        if(catalog==null){catalog=BuildCatalog.load();slots=[for(id in catalog.gearSlots){id:id,label:catalog.slotName(id)+"##sim_slot_"+id}];}
        if(snapshot!=b){snapshot=b;requested=restore=false;slot=b.gear.length>0?b.gear[0].slot:(slots.length>0?slots[0].id:"");levelSlot="";dirty=true;}
        var captured:GearSnapshot=null;for(g in b.gear)if(g.slot==slot)captured=g;
        current=captured==null?"Captured slot: empty":"Captured: "+captured.name+" / item level "+captured.itemLevel;
        if(dirty){
            dirty=false;query=ByteUtil.readString(filter,160,true).toLowerCase();choices=[];
            if(levelSlot!=slot){levelSlot=slot;level.set(captured!=null?Std.int(Math.max(1,Math.min(10000,captured.itemLevel))):b.level);}
            for(id in catalog.itemIdsForSlot(slot)){
                var row=catalog.items.get(id);
                var name=BuildCatalog.string(row,"name",id);if(name=="")name=id;var search=(name+" "+id).toLowerCase();
                if(query!=""&&search.indexOf(query)<0)continue;
                choices.push({id:id,name:name,label:name+"##sim_item_"+id,search:search});
            }
            choices.sort((a,b)->Reflect.compare(a.name,b.name));
            if(!contains(item))item=choices.length>0?choices[0].id:"";
        }
        if(shownCandidate!=candidate||rollSlot!=slot){
            shownCandidate=candidate;rollSlot=slot;rollRows=[];
            if(candidate.gear.exists(slot)){var g=candidate.gear.get(slot);for(i in 0...g.contributions.length){var c=g.contributions[i];rollRows.push({index:i,label:c.stat+" ("+c.operation+")",id:"##sim_assumed_roll_"+i,value:new FloatRef(c.rawValue)});}}
        }
        if(editIndex>=0){var index=editIndex;editIndex=-1;try{return BuildEquipment.setRoll(candidate,editSlot,index,editValue);}catch(e:Dynamic){status=Std.string(e);}}
        if(restore){restore=false;var next=candidate.copy();next.gear.remove(requestSlot);status="Restored the captured item for this slot.";return next;}
        if(requested){
            requested=false;
            try{var gear=BuildGearPreview.capture(b,requestSlot,requestItem,requestLevel);status="Candidate item loaded from CDB. Inspect Gear and Skills for its contributions and coverage.";return BuildEquipment.replace(b,candidate,gear);}
            catch(e:Dynamic){status="Could not preview item: "+Std.string(e);}
        }
        return null;
    }
    function contains(id:String):Bool {for(c in choices)if(c.id==id)return true;return false;}
    public function draw():Void {
        ImGui.textWrapped("Hypothetical equipment only. Your character's items stay equipped.");
        var title=slot;for(s in slots)if(s.id==slot)title=catalog.slotName(slot);
        ImGui.setNextItemWidth(230);
        if(ImGui.beginCombo("##sim_gear_slot",title)){
            for(s in slots)if(ImGui.selectable(s.label,s.id==slot)){slot=s.id;dirty=true;}
            ImGui.endCombo();
        }
        ImGui.textWrapped(current);
        ImGui.setNextItemWidth(260);
        if(ImGui.inputTextWithHint("##sim_item_search","Search gear from data.cdb",filter,160))dirty=true;
        var selected="No compatible CDB items";for(c in choices)if(c.id==item)selected=c.name;
        ImGui.setNextItemWidth(260);
        if(ImGui.beginCombo("##sim_gear_item",selected)){
            for(c in choices)if(ImGui.selectable(c.label,c.id==item))item=c.id;
            ImGui.endCombo();
        }
        ImGui.alignTextToFramePadding();ImGui.text("Item level");ImGui.sameLine();ImGui.setNextItemWidth(110);ImGui.inputInt("##sim_item_level",level,1,5);
        ImGui.textWrapped("Item level controls CDB stat generation. The new template starts without augments or infusion.");
        ImGui.beginDisabled(snapshot==null||item==""||dirty);
        if(UiChrome.ghostButton("Preview item##sim_preview_item",ImGui.vec2(140,26))){requestSlot=slot;requestItem=item;requestLevel=level.get();requested=true;}
        ImGui.endDisabled();
        if(UiChrome.ghostButton("Restore slot##sim_restore_slot",ImGui.vec2(140,26))){requestSlot=slot;restore=true;}
        ImGui.textWrapped(status);
        if(rollRows.length>0){
            UiChrome.subHeader("Assumed item rolls");ImGui.textWrapped("Edit raw stat values before the slot multiplier. These are what-if assumptions, not guaranteed server rolls.");
            for(r in rollRows){ImGui.text(r.label);ImGui.setNextItemWidth(170);if(ImGui.inputFloat(r.id,r.value,1,10,"%.2f")){editSlot=slot;editIndex=r.index;editValue=r.value.get();}}
        }
    }
}
