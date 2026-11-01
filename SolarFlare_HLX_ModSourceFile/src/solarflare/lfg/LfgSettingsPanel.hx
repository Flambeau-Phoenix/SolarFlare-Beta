package solarflare.lfg;
import imgui.ImGui;
import imgui.ref.BoolRef;
import imgui.ref.IntRef;
import solarflare.lfg.LfgUi;
import solarflare.ui.UiChrome;
import solarflare.ui.UiLayout;
import solarflare.ui.UiActionQueue;

private class LfgFlag {
    public var label:String;public var ref=new BoolRef(false);public var draw:Void->Void;
    var get:Void->Bool;
    public function new(label:String,id:String,get:Void->Bool,set:Bool->Void,changed:Void->Void){this.label=label;this.get=get;draw=function(){if(ImGui.checkbox(id,ref)){set(ref.get());changed();}};}
    public function sync():Void ref.set(get());
}
class LfgSettingsPanel {
    var owner:LfgController;
    var category=new LfgChoice("##lfg_settings_category",["General","Alerts","Filters","Appearance"]);
    var phraseKind=new LfgChoice("##lfg_phrase_kind",["LFG phrases","LFM phrases","Run / boss context","Excluded phrases","Target aliases"]);
    var phrase=new LfgText("##lfg_new_phrase","Literal phrase or alias",128);
    var phraseSearch=new LfgText("##lfg_phrase_search","Search configured phrases",128);
    var targetSearch=new LfgText("##lfg_watch_search","Search activities",128);
    var customWatch=new LfgText("##lfg_custom_watch","Custom target to watch",160);
    var steam=new LfgText("##lfg_saved_steam","Optional Steam ID or friend code",64);
    var keyChoice=new LfgChoice("##lfg_key_choice",KeyBinding.all());
    var modsChoice=new LfgChoice("##lfg_key_mods",["None","Ctrl","Shift","Ctrl+Shift","Alt","Ctrl+Alt","Shift+Alt","Ctrl+Shift+Alt"]);
    var mods=["None","Ctrl","Shift","Ctrl+Shift","Alt","Ctrl+Alt","Shift+Alt","Ctrl+Shift+Alt"];
    var general:Array<LfgFlag>=[];var alertFlags:Array<LfgFlag>=[];var require:LfgFlag;
    var expiry=new IntRef(10);var expiryControl:Void->Void;var generalBody:Void->Void;var alertsBody:Void->Void;
    var aliases:Array<{id:String,name:String,label:String}>=[];var aliasTarget="";var aliasName="";
    var phraseRows:Array<{text:String,button:String,kind:String,phrase:String,target:String}>=[];
    var ignoreRows:Array<{text:String,id:String,button:String}>=[];
    var watchRows:Array<{text:String,id:String,button:String}>=[];
    var rowsKind="";var confirm="";var revision=-1;
    var lastPhraseSearch:String=null;var lastTargetSearch:String=null;var lastIgnoreSecond=-1;
    public var importRequested=false;
    public function new(owner:LfgController){
        this.owner=owner;
        for(channel in ChannelPolicy.names){var id=channel;general.push(new LfgFlag(channel,"Monitor##lfg_channel_"+id,()->ChannelPolicy.enabled(owner.feed.config,id),function(value){var c=owner.feed.config;if(value){if(c.monitoredChannels.indexOf(id)<0)c.monitoredChannels.push(id);}else c.monitoredChannels.remove(id);},owner.changed));}
        general.push(new LfgFlag("Quick leave","Show in party bar##lfg_quick_leave",()->owner.feed.config.quickLeaveChip,v->owner.feed.config.quickLeaveChip=v,owner.changed));
        alertFlags.push(new LfgFlag("Group alerts","Enabled##lfg_alerts",()->owner.feed.config.alertsEnabled,v->owner.feed.config.alertsEnabled=v,owner.changed));
        alertFlags.push(new LfgFlag("Alert sound","Foreground only##lfg_alert_sound",()->owner.feed.config.alertSound,v->owner.feed.config.alertSound=v,owner.changed));
        require=new LfgFlag("Context","Require recruiting context##lfg_require_context",()->owner.feed.config.requireRecruitingContext,v->owner.feed.config.requireRecruitingContext=v,owner.changed);
        expiryControl=function(){ImGui.setNextItemWidth(110);if(ImGui.inputInt("##lfg_expiry",expiry,1,5)){owner.feed.config.expirySeconds=Std.int(Math.max(1,Math.min(30,expiry.get())))*60;expiry.set(Std.int(owner.feed.config.expirySeconds/60));owner.changed();}};
        generalBody=function(){for(f in general)UiLayout.propertyRow(f.label,f.draw);UiLayout.propertyRow("Expiry (minutes)",expiryControl);};
        alertsBody=function(){for(f in alertFlags)UiLayout.propertyRow(f.label,f.draw);};
    }
    public function clear():Void {confirm="";KeyCapture.cancel();}
    public function observe():Void {
        var c=owner.feed.config;
        var changed=revision!=owner.settingsRevision;
        if(changed){revision=owner.settingsRevision;for(f in general)f.sync();for(f in alertFlags)f.sync();require.sync();expiry.set(Std.int(c.expirySeconds/60));steam.set(c.steamId);keyChoice.value=c.panelKey;modsChoice.value=mods[c.panelMods];}
        if(changed||rowsKind!=phraseKind.value||lastPhraseSearch!=phraseSearch.value){
        lastPhraseSearch=phraseSearch.value;
        rowsKind=phraseKind.value;var words=wordList(rowsKind);phraseRows=[];
        if(rowsKind=="Target aliases"){for(a in c.targetAliases)if(phraseSearch.value==""||(a.phrase+" "+a.name).toLowerCase().indexOf(phraseSearch.value.toLowerCase())>=0)phraseRows.push({text:a.phrase+" -> "+a.name,button:"Remove##lfg_alias_"+haxe.crypto.Sha256.encode(a.targetId+"/"+a.phrase),kind:rowsKind,phrase:a.phrase,target:a.targetId});}
        else for(w in words)if(phraseSearch.value==""||w.toLowerCase().indexOf(phraseSearch.value.toLowerCase())>=0)phraseRows.push({text:w,button:"Remove##lfg_word_"+haxe.crypto.Sha256.encode(rowsKind+"/"+w),kind:rowsKind,phrase:w,target:""});
        }
        if(lastTargetSearch!=targetSearch.value){lastTargetSearch=targetSearch.value;
        aliases=[for(a in TargetDefaults.activities())if(targetSearch.value==""||a.name.toLowerCase().indexOf(targetSearch.value.toLowerCase())>=0){id:a.id,name:a.name,label:a.name+"##lfg_watch_target_"+a.id}];
        if(aliasTarget==""&&aliases.length>0){aliasTarget=aliases[0].id;aliasName=aliases[0].name;}
        }
        if(changed||lastIgnoreSecond!=Std.int(Sys.time())){lastIgnoreSecond=Std.int(Sys.time());
        ignoreRows=[for(r in c.ignored)if(r.until==0||r.until>Sys.time()){text:r.name+(r.until==0?" / permanent":" / timed"),id:r.id,button:"Unignore##lfg_unignore_"+r.id}];
        }
        if(changed){
        watchRows=[];for(id in c.watchActivities){var name=StringTools.startsWith(id,"custom:")?id.substr(7):id;for(a in TargetDefaults.activities())if(a.id==id)name=a.name;watchRows.push({id:id,text:name,button:"Unwatch##lfg_unwatch_"+id});}
        }
    }
    function wordList(kind:String):Array<String> return switch(kind){case "LFG phrases":owner.feed.config.lfgWords;case "LFM phrases":owner.feed.config.lfmWords;case "Run / boss context":owner.feed.config.contextWords;case "Excluded phrases":owner.feed.config.excludedWords;default:[];};
    public function left():Void {
        category.draw(230);var c=owner.feed.config;
        switch(category.value){
            case "General":
                UiChrome.subHeader("Chat channel monitoring");UiLayout.propertyGrid("##lfg_general_properties",generalBody);
                ImGui.textWrapped("Channel switches apply to newly received messages and the visible board. Senderless system notices are excluded. The overlay shows up to ten minutes, bounded by listing expiry.");
                UiChrome.subHeader("Panel shortcut");if(keyChoice.draw(170))applyKey();ImGui.sameLine(0,8);if(modsChoice.draw(170))applyKey();
                if(LfgUi.button("Rebind key##lfg_rebind"))KeyCapture.begin();
                if(KeyCapture.listening)ImGui.textWrapped("Press a key or chord; Escape cancels.");
                if(LfgUi.button("Reset to F5##lfg_key_reset")){c.panelKey="F5";c.panelMods=0;owner.changed();}
                ImGui.textWrapped("The panel uses SolarFlare's cursor and camera lifecycle. F6 and F12 are already used by SolarFlare.");
                UiChrome.subHeader("Local contacts");if(steam.draw(260)){c.steamId=SteamContact.valid(steam.value)?steam.value:"";owner.changed();}
                ImGui.textWrapped("Contact details are attached only when you press an Attach button. There is no public relay profile.");
                if(LfgUi.button(confirm=="import"?"Confirm import##lfg_import":"Import SimpleLFG settings##lfg_import",200)){if(confirm=="import"){importRequested=true;confirm="";}else confirm="import";}
            case "Alerts":
                UiChrome.subHeader("Watched group notifications");UiLayout.propertyGrid("##lfg_alert_properties",alertsBody);
                ImGui.textWrapped("Only contextual LFM advertisements can alert. Reposts stay silent, bursts coalesce, and no messages or invitations are sent automatically.");
                for(w in watchRows){ImGui.textWrapped(w.text);if(LfgUi.button(w.button,110)){c.watchActivities.remove(w.id);owner.changed();}}
                if(watchRows.length==0)ImGui.textWrapped("No watched activities yet. Pick one on the right.");
                customWatch.draw(260);if(LfgUi.button("Watch custom target##lfg_watch_custom",180)){var id="custom:"+Parser.normalized(customWatch.value);if(id!="custom:"&&c.watchActivities.length<64&&c.watchActivities.indexOf(id)<0){c.watchActivities.push(id);customWatch.set("");owner.changed();}}
            case "Filters":
                UiChrome.subHeader("Recognition filters");require.draw();phraseKind.draw(230);phraseSearch.draw(280);
                if(rowsKind!=phraseKind.value){ImGui.textWrapped("Updating phrase list...");return;}
                for(r in phraseRows){ImGui.textWrapped(r.text);if(LfgUi.button(confirm==r.button?"Confirm remove##lfg_phrase_confirm":r.button,140)){if(confirm==r.button){if(r.kind=="Target aliases")c.targetAliases=[for(a in c.targetAliases)if(a.targetId!=r.target||a.phrase!=r.phrase)a];else wordList(r.kind).remove(r.phrase);confirm="";owner.changed();}else confirm=r.button;}}
                if(phraseRows.length==0)ImGui.textWrapped("No phrases match this filter.");
            case "Appearance":
                UiChrome.subHeader("SolarFlare appearance");ImGui.textWrapped("LFG uses your SolarFlare theme, text scaling, and window controls. Change the shared theme in Hub Settings. Move and resize the LFG window using its title and edges; unlock the overlay to reposition it.");
        }
    }
    function applyKey():Void {var pair=KeyBinding.clean(keyChoice.value,mods.indexOf(modsChoice.value));if(KeyBinding.needsModifier(keyChoice.value)&&pair.name=="F5")pair={name:keyChoice.value,mods:KeyBinding.CTRL};owner.feed.config.panelKey=pair.name;owner.feed.config.panelMods=pair.mods;owner.changed();}
    public function right():Void {
        var c=owner.feed.config;
        switch(category.value){
            case "General":
                UiChrome.subHeader("Ignored players");for(r in ignoreRows){ImGui.textWrapped(r.text);if(LfgUi.button(r.button,110)){c.ignored=[for(i in c.ignored)if(i.id!=r.id)i];owner.changed();}}
                if(ignoreRows.length==0)ImGui.textWrapped("No ignored players.");
                ImGui.textWrapped("Received chat is session-only: 50 messages per sender, 30 minutes, 2000 messages total. It is never saved with settings.");
            case "Filters":
                UiChrome.subHeader("Add a phrase");phrase.draw(270);
                if(phraseKind.value=="Target aliases"){ImGui.textWrapped(aliasName);targetSearch.draw(260);for(a in aliases)if(ImGui.selectable(a.label,aliasTarget==a.id)){aliasTarget=a.id;aliasName=a.name;}}
                if(LfgUi.button("Add phrase##lfg_phrase_add",130)){
                    var word=Config.clean(phrase.value,48);if(word!=""){
                        if(phraseKind.value=="Target aliases"){var duplicate=false;for(a in c.targetAliases)if(a.targetId==aliasTarget&&a.phrase.toLowerCase()==word.toLowerCase())duplicate=true;if(!duplicate&&aliasTarget!=""&&c.targetAliases.length<512)c.targetAliases.push({targetId:aliasTarget,name:aliasName,phrase:word});}
                        else{var list=wordList(phraseKind.value);if(list.length<256&&!Parser.matchesExact(list,word))list.push(word);}phrase.set("");owner.changed();}
                }
                if(LfgUi.button("Merge defaults##lfg_phrase_merge",150)){c.mergeDefaults();owner.changed();}
                if(LfgUi.button(confirm=="reset"?"Confirm reset##lfg_phrase_reset":"Restore defaults##lfg_phrase_reset",150)){if(confirm=="reset"){var d=new Config();c.lfgWords=d.lfgWords;c.lfmWords=d.lfmWords;c.contextWords=d.contextWords;c.excludedWords=d.excludedWords;c.targetAliases=d.targetAliases;confirm="";owner.changed();}else confirm="reset";}
                ImGui.textWrapped("Matching is case-insensitive and uses literal word boundaries. LF#M recognizes numbered slots. Exclusions win. Phrase edits affect future messages; the context checkbox also filters current rows.");
            case "Alerts":
                UiChrome.subHeader("Activity catalogue");targetSearch.draw(270);for(a in aliases)if(ImGui.selectable(a.label,c.watchActivities.indexOf(a.id)>=0)){if(c.watchActivities.indexOf(a.id)<0&&c.watchActivities.length<64){c.watchActivities.push(a.id);owner.changed();}}
            default:ImGui.textWrapped("Overlay position, size and lock state are saved with SolarFlare settings.");
        }
    }
}
