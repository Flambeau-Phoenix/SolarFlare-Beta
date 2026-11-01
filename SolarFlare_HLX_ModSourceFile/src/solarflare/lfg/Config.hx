package solarflare.lfg;
import solarflare.lfg.Types;
/** Local recognition defaults copied from SimpleLFG. No relay or HTTP configuration. */
class Config {
    public var monitoredChannels:Array<String>=ChannelPolicy.names.copy();
    public var expirySeconds:Int=600;
    public var draft=new Draft();
    public var templates:Array<Draft>=[];
    public var ignored:Array<IgnoreRule>=[];
    public var alertsEnabled=false;
    public var alertSound=false;
    public var watchActivities:Array<String>=[];
    public var reminder=false;
    public var steamId="";
    public var panelKey="F5";
    public var panelMods=0;
    public var quickLeaveChip=false;
    public var requireRecruitingContext:Bool = false;
    public var lfgWords:Array<String> = ["lfg","looking for group","looking for a group","looking to join","need a group","seeking a group","any groups","lf party","looking for party","looking for a party","inv me","invite me","lfp","lft","lf group","lf grp","lf team","lf raid","looking for team","looking for a team","looking for raid","need party","need group","need team","seeking group","seeking party","invite pls","inv pls","invite please","inv please","can join","available for group"];
    public var lfmWords:Array<String> = ["lfm","lf#m","looking for more","recruiting","need","needs","seeking","join us","looking for","forming","starting a group","group forming","pst for invite","pm for invite","whisper for invite","spots open","slots open","need more","come join","anyone up for","anyone for","lf more","lf members","lf players","looking for members","looking for players","looking for tank","looking for healer","looking for dps","need tank","need healer","need dps","need people","need players","need members","open spot","open spots","last spot","last slot","group up","party forming","pst","pm","dm","whisper","inv","invite"];
    public var contextWords:Array<String> = ContextDefaults.merge(["run","runs","running","boss","bosses","farm","farming","clear","clears","dungeon","dungeons","bonus run","bonus runs","glory run","glory runs","heroic run","heroic runs","veteran run","veteran runs","normal run","normal runs","norm","vet","hc","hm","nm","heroic","veteran","normal","dung","dgn","farm run","farm runs","lf run","lf runs"]);
    public var targetAliases:Array<TargetAlias> = TargetDefaults.aliases();
    public var excludedWords:Array<String> = ["wts","wtb","selling","buying"];
    public function new() {}
    public static function decode(o:Dynamic):Config {
        var c=new Config();if(o==null||!Reflect.isObject(o)||Std.isOfType(o,Array)||Std.isOfType(o,String))return c;
        for(key in ["requireRecruitingContext","alertsEnabled","alertSound","reminder","quickLeaveChip"]){var v=Reflect.field(o,key);if(Std.isOfType(v,Bool))Reflect.setField(c,key,v);}
        c.expirySeconds=Std.int(number(o,"expirySeconds",600,60,1800));
        c.monitoredChannels=[for(v in words(Reflect.field(o,"monitoredChannels"),ChannelPolicy.names,32,6))if(ChannelPolicy.known(v))v];
        c.lfgWords=words(Reflect.field(o,"lfgWords"),c.lfgWords);c.lfmWords=words(Reflect.field(o,"lfmWords"),c.lfmWords);
        c.contextWords=words(Reflect.field(o,"contextWords"),c.contextWords);c.excludedWords=words(Reflect.field(o,"excludedWords"),c.excludedWords);
        c.watchActivities=words(Reflect.field(o,"watchActivities"),[],128,64);
        var key=KeyBinding.clean(str(o,"panelKey",24,"F5"),Std.int(number(o,"panelMods",0,0,7)));c.panelKey=key.name;c.panelMods=key.mods;
        c.steamId=str(o,"steamId",20);if(!SteamContact.valid(c.steamId))c.steamId="";
        c.draft=readDraft(Reflect.field(o,"draft"));
        var a:Dynamic=Reflect.field(o,"templates");if(Std.isOfType(a,Array)){var list:Array<Dynamic>=cast a;for(v in list.slice(0,5))c.templates.push(readDraft(v));}
        a=Reflect.field(o,"ignored");if(Std.isOfType(a,Array)){var list:Array<Dynamic>=cast a;for(v in list.slice(0,200)){var id=str(v,"id",128);if(id!="")c.ignored.push({id:id,name:str(v,"name",80),until:number(v,"until",0,0,1e14)});}}
        a=Reflect.field(o,"targetAliases");if(Std.isOfType(a,Array)){c.targetAliases=[];var list:Array<Dynamic>=cast a;var seen:Map<String,Bool>=[];for(v in list.slice(0,512)){var id=str(v,"targetId",128),name=str(v,"name",80),phrase=str(v,"phrase",80),key=id+"/"+phrase.toLowerCase();if(id!=""&&name!=""&&phrase!=""&&!seen.exists(key)&&!TargetDefaults.unavailableTarget(id)){seen.set(key,true);c.targetAliases.push({targetId:id,name:name,phrase:phrase});}}}
        return c;
    }
    public function data():Dynamic return {version:1,monitoredChannels:monitoredChannels.copy(),expirySeconds:expirySeconds,requireRecruitingContext:requireRecruitingContext,
        lfgWords:lfgWords.copy(),lfmWords:lfmWords.copy(),contextWords:contextWords.copy(),excludedWords:excludedWords.copy(),targetAliases:targetAliases.copy(),
        alertsEnabled:alertsEnabled,alertSound:alertSound,watchActivities:watchActivities.copy(),reminder:reminder,steamId:steamId,panelKey:panelKey,panelMods:panelMods,quickLeaveChip:quickLeaveChip,
        draft:draft.copy(),templates:[for(d in templates)d.copy()],ignored:ignored.copy()};
    public static function readDraft(o:Dynamic):Draft {
        var d=new Draft();d.kind=str(o,"kind",3)=="LFG"?"LFG":"LFM";d.activity=str(o,"activity",80);d.note=str(o,"note",160);d.difficulty=difficulty(str(o,"difficulty",16));d.playerClass=playerClass(str(o,"playerClass",16));
        d.capacity=Std.int(number(o,"capacity",4,1,4));d.members=Std.int(number(o,"members",0,0,d.capacity-1));d.channel=str(o,"channel",8)=="Local"?"Local":"All";d.bonusRuns=Reflect.field(o==null?{}:o,"bonusRuns")==true;
        if(TargetDefaults.unavailableTarget(d.activity))d.activity="";return d;
    }
    public function mergeDefaults():Void {
        var d=new Config();for(pair in [{a:lfgWords,b:d.lfgWords},{a:lfmWords,b:d.lfmWords},{a:contextWords,b:d.contextWords},{a:excludedWords,b:d.excludedWords}])for(v in pair.b)if(!Parser.matchesExact(pair.a,v)&&pair.a.length<256)pair.a.push(v);
        for(v in d.targetAliases){var found=false;for(a in targetAliases)if(a.targetId==v.targetId&&a.phrase.toLowerCase()==v.phrase.toLowerCase())found=true;if(!found&&targetAliases.length<512)targetAliases.push(v);}
    }
    public static function str(o:Dynamic,key:String,max:Int,fallback:String=""):String {var v=o==null?null:Reflect.field(o,key);return Std.isOfType(v,String)?clean(cast v,max):fallback;}
    static function number(o:Dynamic,key:String,fallback:Float,min:Float,max:Float):Float {
        var v:Dynamic=o==null?null:Reflect.field(o,key);
        if(!Std.isOfType(v,Int)&&!Std.isOfType(v,Float))return fallback;
        var n:Float=v;if(!Math.isFinite(n))return fallback;return Math.max(min,Math.min(max,n));
    }
    public static function words(v:Dynamic,fallback:Array<String>,max:Int=48,limit:Int=256):Array<String> {
        if(!Std.isOfType(v,Array))return fallback.copy();var out:Array<String>=[];var a:Array<Dynamic>=cast v;
        for(x in a.slice(0,limit))if(Std.isOfType(x,String)){var s=clean(cast x,max);if(s!=""&&!Parser.matchesExact(out,s))out.push(s);}return out;
    }
    public static function clean(s:String,max:Int):String {
        if(s==null)return "";
        #if hl
        s=solarflare.ui.ByteUtil.materialize(s);
        #end
        var end=s.indexOf("\x00");if(end>=0)s=s.substr(0,end);
        return StringTools.trim(~/[\x01-\x1f\x7f]/g.replace(s," ")).substr(0,max);
    }
    public static function difficulty(s:String):String return ["Normal","Veteran","Heroic"].indexOf(s)>=0?s:"Normal";
    public static function playerClass(s:String):String return ["Warrior","Mage","Priest","Rogue"].indexOf(s)>=0?s:"";
}
