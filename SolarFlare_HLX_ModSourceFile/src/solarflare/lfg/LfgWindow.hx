package solarflare.lfg;
import imgui.ImGui;
import imgui.ref.BoolRef;
import imgui.ref.FloatRef;
import imgui.Structs.ImVec2;
import solarflare.lfg.Types;
import solarflare.lfg.LfgUi;
import solarflare.lfg.SocialService;
import solarflare.lfg.SteamContactLookup.SteamContactMatch;
import solarflare.ui.EditorWindow;
import solarflare.ui.HUDWidgetWindow;
import solarflare.ui.SettingsStore;
import solarflare.ui.UiChrome;
import solarflare.ui.UiScope;
import solarflare.ui.UiActionQueue;
import solarflare.ui.ThemePalette;

private class ListingRow {
    public var row:Listing;public var label:String;public var metadata:String;public var tag:String;
    public function new(r:Listing,now:Float){row=r;label=r.senderName+" / "+r.kind+" / "+r.target+"##lfg_"+r.uiId;metadata=r.channel+" / "+Std.int(Math.max(0,now-r.seen)/60)+"m / "+r.composition;tag=r.contextDetected?"Context Detected":"No Context Detected";}
}
private typedef PersonRow={person:SocialPerson,label:String,detail:String};
private class LfgSound {
    @:hlNative("?sfcursor","notify_sound") public static function notify():Void {}
}
/** Local-only workspace. Rendering displays owned records and queues all native work. */
class LfgWindow {
    public var open=new BoolRef(false);
    public var overlay=new BoolRef(false);
    public var chrome=new solarflare.ui.HudChrome(40,180);
    public var overlayWidth=new FloatRef(360);
    public var overlayHeight=new FloatRef(200);
    public var controller(default,null)=new LfgController();
    public var watching=new BoolRef(false);
    public var openLoot:Void->Void;
    var view="Browse";
    var post:LfgPostPanel;var settings:LfgSettingsPanel;
    var filter=new LfgText("##lfg_filter","Search player, activity, class or message",192);
    var targetSearch=new LfgText("##lfg_target_search","Search activity filter",128);
    var peopleSearch=new LfgText("##lfg_people_search","Search friends and realm players",128);
    var message=new LfgText("##lfg_whisper","Write a whisper (manual send)",1024);
    var friendCode=new LfgText("##lfg_friendcode","XXXX-XXXX-XXXX",64);
    var kind=new LfgChoice("##lfg_kind",["All","LFM","LFG","Mention"]);
    var sort=new LfgChoice("##lfg_sort",["age","target","player","type","channel"]);
    var peopleKind=new LfgChoice("##lfg_people_kind",["All","Friends","Realm"]);
    var descending=new BoolRef(false);var onlineOnly=new BoolRef(false);var onlineFirst=new BoolRef(true);
    var selected="";var selectedName="";var selectedText="";var selectedKey="";var selectedRow:Listing;
    var selectedPerson:SocialPerson;var selectedContacts:Array<SteamContactMatch>=[];
    var contactSearch=false;var pendingProfile="";var selectedCode="";
    var activity="all";var activityName="All activities";var targets:Array<{id:String,name:String,label:String}>=[];
    var rows:Array<ListingRow>=[];var people:Array<PersonRow>=[];var history:Array<String>=[];
    var historyRevision=-1;var feedRevision=-1;var settingsRevision=-1;var peopleRevision=-1;
    var lastGeneration=-1;var refresh=true;var nextRows=0.;var now=0.;
    var removeConfirm="";var ignoreConfirm="";var leaveConfirm=false;
    var overlayLines:Array<String>=[];var unreadLabel="Unread: 0##lfg_unread";var toastStamp=0.;
    var overlayTitle="LFG / last 10 min";var partyLine="Solo";
    var imported=false;
    var body:Void->Void;var left:Void->Void;var right:Void->Void;var listingBody:Void->Void;
    var overlayBody:ImVec2->Void;var overlayRows:Void->Void;var overlayResize:Single->Single->Void;var openEditor:Void->Void;var hideOverlay:Void->Void;
    public function new(){
        post=new LfgPostPanel(controller);settings=new LfgSettingsPanel(controller);
        body=drawBody;left=drawLeft;right=drawRight;listingBody=drawListings;
        overlayBody=drawOverlayBody;overlayRows=drawOverlayRows;overlayResize=resizeOverlay;openEditor=showEditor;hideOverlay=closeOverlay;
    }
    public function pollHotkey():Void {
        if(KeyCapture.listening){if(KeyCapture.poll()){controller.feed.config.panelKey=KeyCapture.resultName;controller.feed.config.panelMods=KeyCapture.resultMods;controller.changed();}return;}
        if(!solarflare.ui.CursorCaptureFix.cursorFree||ImGui.isAnyItemActive())return;
        var c=controller.feed.config;
        if(KeyCapture.pressed(c.panelKey,c.panelMods)){open.set(!open.get());if(!open.get())clearTransientState();}
    }
    public function observe(app:GameApp,time:Float):Void {
        now=time;controller.watch=watching.get();controller.observe(app,open.get(),time);
        if(lastGeneration!=controller.generation){lastGeneration=controller.generation;clearTransientState();rows=[];people=[];history=[];overlayLines=[];refresh=true;}
        if(!imported){imported=true;if(!controller.hasSettings)importPreferences();}
        if(settings.importRequested){settings.importRequested=false;importPreferences();}
        if(pendingProfile!=""){var profile=pendingProfile;pendingProfile="";if(controller.available&&open.get()&&app.isCursorFree())hxd.System.openURL(profile);}
        if(contactSearch){contactSearch=false;var texts=[for(e in controller.feed.history.forSender(selected))e.text];texts.reverse();selectedContacts=SteamContactLookup.find(texts);if(selectedContacts.length==0)controller.status="No supported Steam contact was found in this sender's observed messages.";}
        if(controller.alerts.toastUntil>toastStamp){toastStamp=controller.alerts.toastUntil;if(toastStamp>time)solarflare.ui.ToastManager.info(controller.alerts.title+": "+controller.alerts.body,8);}
        if(controller.alerts.soundRequested){controller.alerts.soundRequested=false;try{if(controller.available&&hxd.Window.getInstance().get_isFocused()&&hl.Api.isPrimLoaded(LfgSound.notify))LfgSound.notify();}catch(_:Dynamic){}}
        if(!open.get()&&!overlay.get())return;
        if(refresh||time>=nextRows||feedRevision!=controller.feed.revision||settingsRevision!=controller.settingsRevision||peopleRevision!=controller.peopleRevision){
            refresh=false;nextRows=time+1;feedRevision=controller.feed.revision;settingsRevision=controller.settingsRevision;peopleRevision=controller.peopleRevision;
            rows=[for(r in controller.feed.filtered(kind.value,activity,filter.value,sort.value,!descending.get()))new ListingRow(r,time)];
            targets=[for(a in TargetDefaults.activities())if(targetSearch.value==""||a.name.toLowerCase().indexOf(targetSearch.value.toLowerCase())>=0){id:a.id,name:a.name,label:a.name+"##lfg_filter_target_"+a.id}];
            overlayLines=[for(r in controller.feed.filtered("LFM"))if(r.contextDetected&&time-r.seen<600)r.senderName+" / "+r.target+" / "+Std.int(Math.max(0,time-r.seen)/60)+"m"];
            unreadLabel="Unread: "+controller.alerts.unread+"##lfg_unread";
            people=[];for(p in controller.people)if((peopleKind.value=="All"||peopleKind.value=="Friends"&&p.friend||peopleKind.value=="Realm"&&p.realm)&&(!onlineOnly.get()||p.online)&&SearchTerms.matches([p.name,p.detail],SearchTerms.parse(peopleSearch.value)))people.push({person:p,label:p.name+(p.friend?" [friend]":"")+(p.online?"":" [offline]")+"##lfg_person_"+p.uid,detail:p.detail+(p.pending?" / request pending":"")});
            people.sort(function(a,b){if(onlineFirst.get()&&a.person.online!=b.person.online)return a.person.online?-1:1;return Reflect.compare(a.person.name.toLowerCase(),b.person.name.toLowerCase());});
            selectedPerson=null;for(p in controller.people)if(p.uid==selected)selectedPerson=p;
            if(selectedKey!=""){selectedRow=null;for(r in controller.feed.filtered())if(r.key==selectedKey)selectedRow=r;if(selectedRow==null){selectedKey=selectedCode="";selectedText="This listing expired or was hidden. Select a current listing.";}else{selectedText=selectedRow.text;selectedCode=selectedRow.fareverCode;}}
            partyLine=controller.party.members.length>1?"Party "+controller.party.members.length+"/"+controller.party.capacity+(controller.party.leader?" / leader":""):"Solo";
            rebuildHistory();
        }
        if(historyRevision!=controller.feed.history.revision||refresh){historyRevision=controller.feed.history.revision;rebuildHistory();}
        if(open.get()){post.observe();settings.observe();}
    }
    function importPreferences():Void {
        try{
            var path=haxe.io.Path.normalize(haxe.io.Path.join([solarflare.ui.ModPaths.modDir(),"..","..","config","simplelfg","config.json"]));
            if(!sys.FileSystem.exists(path)){controller.status="No previous SimpleLFG settings were found.";return;}
            if(sys.FileSystem.stat(path).size>1048576)throw "Previous settings exceed the import limit.";
            var raw:Dynamic=haxe.Json.parse(sys.io.File.getContent(path));
            if(raw==null||!Reflect.isObject(raw)||Std.isOfType(raw,Array)||Std.isOfType(raw,String))throw "Settings must contain an object.";
            controller.applySettings(raw);controller.changed();refresh=true;controller.status="Imported local SimpleLFG filters, channels, watches, drafts, templates and ignores. Relay settings were excluded.";
        }catch(_:Dynamic){controller.status="Could not read the previous SimpleLFG settings. Current settings were kept.";}
    }
    function rebuildHistory():Void {history=[for(e in controller.feed.history.forSender(selected))if(ChannelPolicy.enabled(controller.feed.config,e.channel))e.channel+" / "+Std.int(Math.max(0,now-e.receivedAt)/60)+"m: "+e.text];}
    public function clearTransientState():Void {selected=selectedName=selectedText=selectedKey=removeConfirm=ignoreConfirm="";selectedRow=null;selectedPerson=null;selectedContacts=[];history=[];leaveConfirm=false;message.set("");friendCode.set("");controller.clearPending();post.clear();settings.clear();contactSearch=false;pendingProfile="";}
    public function draw():Void {
        if(open.get())EditorWindow.drawMenuWindow("LFG###SolarFlare.LFG",open,1200,800,body,false,true,900,650);
        if(overlay.get()&&!solarflare.ui.HudSuppress.active()&&controller.available)HUDWidgetWindow.draw("SolarFlare.LFG.Overlay",overlayTitle,chrome,overlayWidth.get(),overlayHeight.get(),overlayBody,openEditor,hideOverlay,false,null,overlayResize);
    }
    function showEditor():Void open.set(true);
    function closeOverlay():Void {overlay.set(false);SettingsStore.markDirty();}
    function resizeOverlay(w:Single,h:Single):Void {overlayWidth.set(Math.max(240,Math.min(1200,w)));overlayHeight.set(Math.max(120,Math.min(1000,h)));SettingsStore.markDirty();}
    function drawOverlayBody(size:ImVec2):Void {if(LfgUi.button("Open LFG##lfg_overlay_open",100))open.set(true);UiScope.child("##lfg_overlay_rows",ImGui.vec2(size.x,Math.max(20,size.y-32)),overlayRows);}
    function drawOverlayRows():Void {ImGui.textWrapped("Recently advertised; availability unconfirmed.");if(overlayLines.length==0)ImGui.textDisabled("No recent group advertisements.");for(line in overlayLines)ImGui.textWrapped(line);}
    function drawBody():Void {
        if(LfgUi.button("Browse##lfg_tab_browse",90))view="Browse";ImGui.sameLine(0,6);if(LfgUi.button("Post##lfg_tab_post",80))view="Post";ImGui.sameLine(0,6);if(LfgUi.button("People##lfg_tab_people",90))view="People";ImGui.sameLine(0,6);if(LfgUi.button("Settings##lfg_tab_settings",100))view="Settings";
        ImGui.sameLine(0,6);if(openLoot!=null&&LfgUi.button("Loot Browser##lfg_loot",125))openLoot();
        if(ImGui.checkbox("Watch chat##lfg_watch",watching))SettingsStore.markDirty();ImGui.sameLine(0,8);if(ImGui.checkbox("10-minute overlay##lfg_overlay",overlay)){if(overlay.get())watching.set(true);SettingsStore.markDirty();}ImGui.sameLine(0,8);if(ImGui.checkbox("Lock overlay##lfg_overlay_lock",chrome.locked))SettingsStore.markDirty();
        ImGui.text(partyLine);if(controller.feed.config.quickLeaveChip&&controller.party.canLeave){ImGui.sameLine(0,8);drawLeave();}
        ImGui.sameLine(0,8);if(LfgUi.button(unreadLabel,130)){controller.alerts.acknowledge();refresh=true;}
        ImGui.textWrapped(controller.status);
        var avail=ImGui.getContentRegionAvail();var gap:Single=12;var w:Single=(avail.x-gap)*0.60;
        UiChrome.celChild("##lfg_workspace",ImGui.vec2(w,avail.y),left);ImGui.sameLine(0,gap);UiChrome.celChild("##lfg_inspector",ImGui.vec2(avail.x-w-gap,avail.y),right);
    }
    function drawLeft():Void {switch(view){case "Post":post.left();case "Settings":settings.left();case "People":drawPeople();default:drawFeed();}}
    function drawRight():Void {switch(view){case "Post":post.right();case "Settings":settings.right();default:drawDetails();}}
    function drawFeed():Void {
        UiChrome.subHeader("Local chat board");if(filter.draw(320))refresh=true;
        if(kind.draw(120))refresh=true;ImGui.sameLine(0,8);if(sort.draw(130))refresh=true;ImGui.sameLine(0,8);if(ImGui.checkbox("Reverse##lfg_sort_reverse",descending))refresh=true;
        ImGui.setNextItemWidth(280);if(ImGui.beginCombo("##lfg_activity_filter",activityName)){
            if(targetSearch.draw(260))refresh=true;
            if(ImGui.selectable("All activities##lfg_activity_all",activity=="all")){activity="all";activityName="All activities";refresh=true;}
            for(a in targets)if(ImGui.selectable(a.label,activity==a.id)){activity=a.id;activityName=a.name;refresh=true;}ImGui.endCombo();}
        ImGui.textWrapped("Only newly observed messages are listed. Context tags describe recruiting language, not confirmed group availability.");
        UiScope.child("##lfg_board_rows",ImGui.vec2(0,0),listingBody);
    }
    function choose(r:Listing):Void {selected=r.senderId;selectedName=r.senderName;selectedText=r.text;selectedKey=r.key;selectedRow=r;selectedCode=r.fareverCode;selectedContacts=[];removeConfirm=ignoreConfirm="";refresh=true;rebuildHistory();}
    function drawListings():Void {
        for(r in rows){if(ImGui.selectable(r.label,selectedKey==r.row.key))choose(r.row);
            if(ImGui.beginPopupContextItem(r.row.uiId)){if(ImGui.menuItem("Whisper"))choose(r.row);if(ImGui.menuItem("Hide listing")){controller.feed.hide(r.row.key);refresh=true;}if(ImGui.menuItem("Ignore for 30 minutes")){controller.feed.ignore(r.row.senderId,r.row.senderName);controller.changed();refresh=true;}if(ImGui.menuItem("Watch activity")){watch(r.row);}if(ImGui.menuItem("Copy message"))UiActionQueue.copyText(r.row.text);ImGui.endPopup();}
            ImGui.textColored(ThemePalette.status(r.row.contextDetected?ThemePalette.STATUS_SUCCESS:ThemePalette.STATUS_WARN),r.tag);ImGui.sameLine(0,8);ImGui.textDisabled(r.metadata);}
        if(rows.length==0)ImGui.textWrapped(watching.get()?"No matching messages. Check Settings > General channels and Settings > Filters.":"Enable Watch chat to collect newly received messages.");
    }
    function watch(r:Listing):Void {var id=r.activityId=="other"||r.activityId=="ambiguous"?"custom:"+Parser.normalized(r.target):r.activityId;var list=controller.feed.config.watchActivities;if(list.length<64&&list.indexOf(id)<0){list.push(id);controller.changed();}}
    function drawPeople():Void {
        UiChrome.subHeader("Party");for(p in controller.party.members)ImGui.text(p.name+(p.leader?" (leader)":""));if(controller.party.canLeave)drawLeave();
        UiChrome.subHeader("Farever friend code");if(controller.code!=""){ImGui.text(controller.code);if(LfgUi.button("Copy code##lfg_copy",110))UiActionQueue.copyText(controller.code);}
        friendCode.draw(240);if(LfgUi.button("Add by code##lfg_addcode",125)){controller.queue("addCode","","",friendCode.value);friendCode.set("");}
        UiChrome.subHeader("Friends and realm players");if(peopleSearch.draw(300))refresh=true;if(peopleKind.draw(130))refresh=true;
        if(ImGui.checkbox("Online only##lfg_online_only",onlineOnly))refresh=true;ImGui.sameLine(0,8);if(ImGui.checkbox("Online first##lfg_online_first",onlineFirst))refresh=true;
        for(r in people){if(ImGui.selectable(r.label,selected==r.person.uid)){selected=r.person.uid;selectedName=r.person.name;selectedText=r.detail;selectedPerson=r.person;selectedKey="";selectedRow=null;selectedCode="";selectedContacts=[];removeConfirm="";rebuildHistory();}ImGui.textWrapped(r.detail);}
        if(people.length==0)ImGui.textWrapped("No matching friends or realm players.");
    }
    function drawLeave():Void {if(LfgUi.button(leaveConfirm?"Confirm leave##lfg_leave":"Leave party##lfg_leave",140)){if(leaveConfirm){controller.queue("leaveParty");leaveConfirm=false;}else leaveConfirm=true;}}
    function drawDetails():Void {
        if(selected==""){UiChrome.subHeader("Player details");ImGui.textWrapped("Select a listing or a player for whisper, contact, party and recent chat options.");return;}
        UiChrome.subHeader(selectedName);ImGui.textWrapped(selectedText);
        if(selectedRow!=null){
            ImGui.textColored(ThemePalette.status(selectedRow.contextDetected?ThemePalette.STATUS_SUCCESS:ThemePalette.STATUS_WARN),selectedRow.contextDetected?"Context Detected":"No Context Detected");
            if(LfgUi.button("Hide listing##lfg_hide")){controller.feed.hide(selectedKey);refresh=true;}
            if(LfgUi.button("Watch activity##lfg_watch_selected",140))watch(selectedRow);
            if(LfgUi.button("Ignore 30 minutes##lfg_ignore_timed",155)){controller.feed.ignore(selected,selectedName);controller.changed();refresh=true;}
            if(LfgUi.button(ignoreConfirm==selected?"Confirm permanent##lfg_ignore_perm":"Ignore permanently##lfg_ignore_perm",170)){if(ignoreConfirm==selected){controller.feed.ignore(selected,selectedName,true);controller.changed();ignoreConfirm="";refresh=true;}else ignoreConfirm=selected;}
        }
        if(LfgUi.button("Copy player name##lfg_copy_name",155))UiActionQueue.copyText(selectedName);
        ImGui.beginDisabled(!controller.available||selectedPerson==null||!selectedPerson.online||!controller.party.canInvite);
        if(LfgUi.button("Invite to party##lfg_invite",140))controller.queue("invite",selected);ImGui.endDisabled();
        if(selectedPerson!=null){ImGui.beginDisabled(selectedPerson.pending);if(!selectedPerson.friend){if(LfgUi.button("Add friend##lfg_addfriend",120))controller.queue("addFriend",selected);}else if(LfgUi.button(removeConfirm==selected?"Confirm remove##lfg_remove_friend":"Remove friend##lfg_remove_friend",145)){if(removeConfirm==selected){controller.queue("removeFriend",selected);removeConfirm="";}else removeConfirm=selected;}ImGui.endDisabled();}
        UiChrome.subHeader("Whisper");message.draw(300);
        ImGui.beginDisabled(!controller.available||selected==controller.playerId||message.value==""||message.value.length>240);if(LfgUi.button("Send whisper##lfg_send",140)){controller.queue("whisper",selected,selectedName,message.value);message.set("");}ImGui.endDisabled();
        if(LfgUi.button("Attach Farever##lfg_whisper_farever",150))message.set(FareverContact.attach(message.value,controller.code));
        if(LfgUi.button("Attach Steam ID##lfg_whisper_steam",150))message.set(SteamContact.attach(message.value,controller.feed.config.steamId,240));
        if(LfgUi.button("Remove Steam ID##lfg_whisper_no_steam",150))message.set(SteamContact.detach(message.value));
        if(selectedCode!=""){ImGui.text(selectedCode);if(LfgUi.button("Add Farever contact##lfg_contact_add",175))controller.queue("addCode","","",selectedCode);}
        if(LfgUi.button("Find Steam contact##lfg_find_steam",170))contactSearch=true;
        for(c in selectedContacts){ImGui.text(c.value);if(LfgUi.button(c.label,210))pendingProfile=c.profile;if(LfgUi.button(c.copyLabel,140))UiActionQueue.copyText(c.value);}
        UiChrome.subHeader("Recent sender chat");for(line in history)ImGui.textWrapped(line);if(history.length==0)ImGui.textWrapped("No recent messages were observed from this sender.");
    }
}
