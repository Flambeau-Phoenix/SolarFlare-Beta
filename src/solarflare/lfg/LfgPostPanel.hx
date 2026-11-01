package solarflare.lfg;
import imgui.ImGui;
import imgui.ref.BoolRef;
import solarflare.lfg.LfgUi;
import solarflare.lfg.Types;
import solarflare.ui.UiChrome;

class LfgPostPanel {
    var owner:LfgController;
    var activity=new LfgText("##lfg_post_activity","Catalogue or custom activity",160);
    var note=new LfgText("##lfg_post_note","Optional short note",512);
    var search=new LfgText("##lfg_post_search","Search activities",128);
    var kind=new LfgChoice("##lfg_post_kind",["LFM","LFG"]);
    var difficulty=new LfgChoice("##lfg_post_difficulty",["Normal","Veteran","Heroic"]);
    var playerClass=new LfgChoice("##lfg_post_class",["Not specified","Warrior","Mage","Priest","Rogue"]);
    var channel=new LfgChoice("##lfg_post_channel",["All","Local"]);
    var members=new LfgChoice("##lfg_post_members",["0","1","2","3"]);
    var capacity=new LfgChoice("##lfg_post_capacity",["1","2","3","4"],"4");
    var bonus=new BoolRef(false);var reminder=new BoolRef(false);
    var revision=-1;var confirm=-1;var label="Post##lfg_post_submit";var ready=false;var preview="";
    var activities:Array<{activity:Activity,label:String}>=[];
    var lastSearch:String=null;
    var templates:Array<{draft:Draft,label:String,load:String,remove:String,index:Int}>=[];
    public function new(owner:LfgController){this.owner=owner;}
    public function clear():Void {confirm=-1;}
    public function observe():Void {
        var c=owner.feed.config;
        if(revision!=owner.settingsRevision){revision=owner.settingsRevision;var d=c.draft;activity.set(d.activity);note.set(d.note);kind.value=d.kind;difficulty.value=d.difficulty;playerClass.value=d.playerClass==""?"Not specified":d.playerClass;channel.value=d.channel;members.value=Std.string(d.members);capacity.value=Std.string(d.capacity);bonus.set(d.bonusRuns);reminder.set(c.reminder);
            templates=[for(i in 0...c.templates.length){draft:c.templates[i],label:c.templates[i].kind+" / "+c.templates[i].activity,load:"Load##lfg_template_load_"+i,remove:"Delete##lfg_template_delete_"+i,index:i}];}
        preview=owner.preview;ready=preview==Parser.preview(c.draft)&&c.draft.activity!=""&&owner.available&&owner.cooldown==0;
        label=owner.cooldown>0?"Wait "+owner.cooldown+"s##lfg_post_submit":"Post##lfg_post_submit";
        if(lastSearch!=search.value){lastSearch=search.value;activities=[for(a in TargetDefaults.activities())if(search.value==""||a.name.toLowerCase().indexOf(search.value.toLowerCase())>=0){activity:a,label:a.name+"##lfg_post_target_"+a.id}];}
    }
    function changed():Void owner.changed();
    public function left():Void {
        var c=owner.feed.config;var d=c.draft;UiChrome.subHeader("Build your post");
        if(kind.draw(110)){d.kind=kind.value;changed();}ImGui.sameLine(0,8);if(channel.draw(140)){d.channel=channel.value;changed();}
        ImGui.text("Activity");if(activity.draw(300)){d.activity=Config.clean(activity.value,80);changed();}
        ImGui.text("Difficulty");if(difficulty.draw(140)){d.difficulty=difficulty.value;changed();}ImGui.sameLine(0,8);if(playerClass.draw(180)){d.playerClass=playerClass.value=="Not specified"?"":playerClass.value;changed();}
        if(d.kind=="LFM"){
            ImGui.text("Advertised members / capacity");if(members.draw(90)){d.members=Std.int(Math.min(Std.parseInt(members.value),d.capacity-1));members.value=Std.string(d.members);changed();}
            ImGui.sameLine(0,8);if(capacity.draw(90)){d.capacity=Std.parseInt(capacity.value);d.members=Std.int(Math.min(d.members,d.capacity-1));members.value=Std.string(d.members);changed();}
        }
        if(ImGui.checkbox("Bonus Runs##lfg_post_bonus",bonus)){d.bonusRuns=bonus.get();changed();}
        if(note.draw(340)){d.note=Config.clean(note.value,160);changed();}
        ImGui.beginDisabled(owner.code=="");if(LfgUi.button("Attach Farever##lfg_post_farever",150)){d.note=FareverContact.attach(d.note,owner.code,160);note.set(d.note);changed();}ImGui.endDisabled();
        if(LfgUi.button("Remove Farever##lfg_post_nofarever",150)){d.note=Config.clean(FareverContact.withoutTags(d.note),160);note.set(d.note);changed();}
        ImGui.beginDisabled(!SteamContact.valid(c.steamId));if(LfgUi.button("Attach Steam ID##lfg_post_steam",150)){d.note=SteamContact.attach(d.note,c.steamId,160);note.set(d.note);changed();}ImGui.endDisabled();
        if(LfgUi.button("Remove Steam ID##lfg_post_nosteam",150)){d.note=SteamContact.detach(d.note);note.set(d.note);changed();}
        UiChrome.subHeader("Reviewed preview");ImGui.textWrapped(preview);
        ImGui.beginDisabled(!ready||revision!=owner.settingsRevision);if(LfgUi.button(label,120))owner.queue("post","","",preview,d.channel);ImGui.endDisabled();
        if(ImGui.checkbox("Remind me when ready to repost##lfg_post_reminder",reminder)){c.reminder=reminder.get();changed();}
        if(owner.posting.reminderReady)ImGui.textWrapped("Your post is ready. Posting remains manual.");
        ImGui.textWrapped("Posts go through normal All or Local game chat. The 60-second cooldown and reminders never send automatically.");
    }
    public function right():Void {
        UiChrome.subHeader("Saved templates (up to five)");
        ImGui.beginDisabled(owner.feed.config.templates.length>=5);
        if(LfgUi.button("Save current post##lfg_template_save",160)){owner.feed.config.templates.push(owner.feed.config.draft.copy());changed();}ImGui.endDisabled();
        if(templates.length==0)ImGui.textWrapped("No saved templates. Create a post and save it here.");
        for(t in templates){ImGui.textWrapped(t.label);if(LfgUi.button(t.load,65)){owner.feed.config.draft=t.draft.copy();changed();}ImGui.sameLine(0,8);if(LfgUi.button(confirm==t.index?"Confirm delete##lfg_template_confirm":t.remove,135)){if(confirm==t.index){owner.feed.config.templates.remove(t.draft);confirm=-1;changed();}else confirm=t.index;}}
        UiChrome.subHeader("Activity catalogue");search.draw(260);
        for(a in activities)if(ImGui.selectable(a.label,owner.feed.config.draft.activity==a.activity.name)){owner.feed.config.draft.activity=a.activity.name;activity.set(a.activity.name);changed();}
        if(activities.length==0)ImGui.textWrapped("No matching activities. You can enter a custom target.");
    }
}
