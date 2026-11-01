package solarflare.lfg;
import imgui.ImGui;
import imgui.ref.BoolRef;
import imgui.ref.FloatRef;
import imgui.Structs.ImVec2;
import solarflare.ui.EditorWindow;
import solarflare.ui.HUDWidgetWindow;
import solarflare.ui.SettingsStore;
import solarflare.ui.UiChrome;
import solarflare.ui.UiScope;
import solarflare.ui.UiHints;
import solarflare.ui.ByteUtil;
import imgui.Enums.ImGuiTableFlags;
import imgui.Enums.ImGuiTableColumnFlags;

/** Local-only LFG: panels retain owned data and queue actions for observation. */
class LfgWindow {
    public var open=new BoolRef(false);
    public var overlay=new BoolRef(false);
    public var chrome=new solarflare.ui.HudChrome(40,180);
    public var overlayWidth=new FloatRef(360);
    public var overlayHeight=new FloatRef(200);
    public var controller(default,null)=new LfgController();
    public var watching=new BoolRef(false);
    public var openLoot:Void->Void;
    var recruiting=new BoolRef(false);
    var filter=new hl.Bytes(160);
    var message=new hl.Bytes(512);
    var friendCode=new hl.Bytes(64);
    var query="";var selected="";var selectedName="";var selectedText="";
    var lastGeneration=-1;
    var removeConfirm="";var leaveConfirm=false;
    var overlayLines:Array<String>=[];var nextOverlay=0.;
    var body:Void->Void;var left:Void->Void;var right:Void->Void;var listings:Void->Void;var roster:Void->Void;
    var overlayBody:ImVec2->Void;var overlayRows:Void->Void;var overlayResize:Single->Single->Void;var openEditor:Void->Void;var hideOverlay:Void->Void;
    public function new(){
        filter.setUI8(0,0);message.setUI8(0,0);friendCode.setUI8(0,0);
        body=drawBody;left=drawFeed;right=drawPeople;listings=drawListings;roster=drawRoster;
        overlayBody=drawOverlayBody;overlayRows=drawOverlayRows;overlayResize=resizeOverlay;openEditor=showEditor;hideOverlay=closeOverlay;
    }
    public function observe(app:GameApp,now:Float):Void {
        controller.watch=watching.get();controller.feed.config.requireRecruitingContext=recruiting.get();
        controller.observe(app,open.get(),now);
        if(lastGeneration!=controller.generation){lastGeneration=controller.generation;clearTransientState();overlayLines=[];nextOverlay=0;}
        if(overlay.get()&&now>=nextOverlay){nextOverlay=now+1;overlayLines=[];for(r in controller.feed.rows)if(r.contextDetected&&r.kind=="LFM")overlayLines.push(r.senderName+" / "+r.target+" / "+Std.int(Math.max(0,now-r.seen)/60)+"m");}
    }
    public function clearTransientState():Void {selected=selectedName=selectedText=removeConfirm="";leaveConfirm=false;message.setUI8(0,0);friendCode.setUI8(0,0);controller.clearPending();}
    public function draw():Void {
        if(open.get())EditorWindow.drawMenuWindow("LFG###SolarFlare.LFG",open,1100,760,body,false,true,820,580);
        if(overlay.get()&&!solarflare.ui.HudSuppress.active()&&controller.available){
            HUDWidgetWindow.draw("SolarFlare.LFG.Overlay","LFG / last 10 min",chrome,overlayWidth.get(),overlayHeight.get(),overlayBody,openEditor,hideOverlay,false,null,overlayResize);
        }
    }
    function showEditor():Void {open.set(true);}
    function closeOverlay():Void {overlay.set(false);SettingsStore.markDirty();}
    function resizeOverlay(w:Single,h:Single):Void {
        overlayWidth.set(Math.max(240,Math.min(1200,w)));overlayHeight.set(Math.max(120,Math.min(1000,h)));SettingsStore.markDirty();
    }
    function drawOverlayBody(size:ImVec2):Void {
        if(UiChrome.ghostButton("Open LFG##lfg_overlay_open",ImGui.vec2(100,26)))open.set(true);
        UiScope.child("##lfg_overlay_rows",ImGui.vec2(size.x,Math.max(20,size.y-32)),overlayRows);
    }
    function drawOverlayRows():Void {
        ImGui.textWrapped("Recently advertised; availability unconfirmed.");
        if(overlayLines.length==0)ImGui.textDisabled("No recent group advertisements.");
        for(line in overlayLines)ImGui.textWrapped(line);
    }
    function drawBody():Void {
        UiChrome.heading("LFG");
        if(openLoot!=null&&UiChrome.ghostButton("Loot Browser##lfg_loot",ImGui.vec2(140,26)))openLoot();
        if(ImGui.checkbox("Watch chat##lfg_watch",watching))solarflare.ui.SettingsStore.markDirty();
        ImGui.sameLine();ImGui.checkbox("Recruiting only##lfg_recruiting",recruiting);
        ImGui.sameLine();if(ImGui.checkbox("10-minute overlay##lfg_overlay",overlay)){if(overlay.get())watching.set(true);solarflare.ui.SettingsStore.markDirty();}
        ImGui.sameLine();if(ImGui.checkbox("Lock overlay##lfg_overlay_lock",chrome.locked))solarflare.ui.SettingsStore.markDirty();
        ImGui.setNextItemWidth(280);
        if(ImGui.inputTextWithHint("##lfg_filter","Filter player, activity or message",filter,160))query=ByteUtil.readString(filter,160,true).toLowerCase();
        if(ImGui.beginTable("##lfg_panes",2,ImGuiTableFlags.SizingStretchProp)){
            ImGui.tableSetupColumn("Chat",ImGuiTableColumnFlags.WidthStretch,60);ImGui.tableSetupColumn("People",ImGuiTableColumnFlags.WidthStretch,40);
            ImGui.tableNextColumn();UiChrome.celChild("##lfg_chat",ImGui.vec2(0,-52),left);
            ImGui.tableNextColumn();UiChrome.celChild("##lfg_people",ImGui.vec2(0,-52),right);
            ImGui.endTable();
        }
        ImGui.textWrapped(controller.status);
    }
    function drawFeed():Void {
        UiChrome.sectionHeader("Chat watcher");
        UiHints.noteWrapped("New messages received here are kept for ten minutes. Chat cannot confirm that a group is still open.");
        UiScope.child("##lfg_listings",ImGui.vec2(0,selected==""?-4:-190),listings);
        if(selected!=""){
            UiChrome.subHeader("Selected player");ImGui.text(selectedName);ImGui.textWrapped(selectedText);
            ImGui.setNextItemWidth(300);ImGui.inputTextWithHint("##lfg_whisper","Write a whisper",message,512);
            ImGui.beginDisabled(!controller.available);
            if(UiChrome.ghostButton("Send whisper##lfg_send",ImGui.vec2(140,26))){controller.queue("whisper",selected,selectedName,ByteUtil.readString(message,512,true));message.setUI8(0,0);}
            ImGui.endDisabled();
        }
    }
    function drawListings():Void {
        var shown=0;
        for(r in controller.feed.rows){
            if(recruiting.get()&&!r.contextDetected)continue;
            if(query!=""&&(r.senderName+" "+r.target+" "+r.text).toLowerCase().indexOf(query)<0)continue;
            shown++;
            if(ImGui.selectable(r.rowLabel,selected==r.senderId)){selected=r.senderId;selectedName=r.senderName;selectedText=r.text;removeConfirm="";}
        }
        if(shown==0)ImGui.textWrapped(watching.get()?"No matching messages yet.":"Enable Watch chat to start collecting messages.");
    }
    function drawPeople():Void {
        UiChrome.sectionHeader("Party");
        if(controller.party.members.length<=1)ImGui.textDisabled("You are not in a party.");
        for(p in controller.party.members)ImGui.text(p.name+(p.leader?" (leader)":""));
        if(controller.party.canLeave){
            if(UiChrome.ghostButton(leaveConfirm?"Confirm leave##lfg_leave":"Leave party##lfg_leave",ImGui.vec2(140,26))){if(leaveConfirm){controller.queue("leaveParty");leaveConfirm=false;}else leaveConfirm=true;}
        }
        UiChrome.subHeader("Friends and realm players");
        UiScope.child("##lfg_roster",ImGui.vec2(0,-130),roster);
        UiChrome.subHeader("Farever friend code");
        if(controller.code!=""){ImGui.text(controller.code);if(UiChrome.ghostButton("Copy code##lfg_copy",ImGui.vec2(110,26)))ImGui.setClipboardText(controller.code);}
        ImGui.setNextItemWidth(220);ImGui.inputTextWithHint("##lfg_friendcode","XXXX-XXXX-XXXX",friendCode,64);
        if(UiChrome.ghostButton("Add by code##lfg_addcode",ImGui.vec2(120,26)))controller.queue("addCode","","",ByteUtil.readString(friendCode,64,true));
    }
    function drawRoster():Void {
        if(controller.people.length==0)ImGui.textWrapped("No native friends or realm players are available.");
        for(p in controller.people){
            ImGui.pushID_Str(p.uid);
            if(ImGui.selectable(p.name+(p.friend?" [friend]":"")+(p.online?"":" [offline]"),selected==p.uid)){selected=p.uid;selectedName=p.name;selectedText=p.detail;removeConfirm="";}
            if(selected==p.uid){
                ImGui.beginDisabled(!controller.available||!p.online||!controller.party.canInvite);
                if(UiChrome.ghostButton("Invite##invite",ImGui.vec2(90,26)))controller.queue("invite",p.uid);
                ImGui.endDisabled();ImGui.sameLine();
                if(!p.friend){if(UiChrome.ghostButton("Add friend##add",ImGui.vec2(110,26)))controller.queue("addFriend",p.uid);}
                else if(UiChrome.ghostButton(removeConfirm==p.uid?"Confirm remove##remove":"Remove friend##remove",ImGui.vec2(140,26))){if(removeConfirm==p.uid){controller.queue("removeFriend",p.uid);removeConfirm="";}else removeConfirm=p.uid;}
            }
            ImGui.popID();
        }
    }
}
