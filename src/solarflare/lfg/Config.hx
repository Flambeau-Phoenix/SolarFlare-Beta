package solarflare.lfg;
import solarflare.lfg.Types.TargetAlias;
/** Local recognition defaults copied from SimpleLFG. No relay or HTTP configuration. */
class Config {
    public var requireRecruitingContext:Bool = false;
    public var lfgWords:Array<String> = ["lfg","looking for group","looking for a group","looking to join","need a group","seeking a group","any groups","lf party","looking for party","looking for a party","inv me","invite me","lfp","lft","lf group","lf grp","lf team","lf raid","looking for team","looking for a team","looking for raid","need party","need group","need team","seeking group","seeking party","invite pls","inv pls","invite please","inv please","can join","available for group"];
    public var lfmWords:Array<String> = ["lfm","lf#m","looking for more","recruiting","need","needs","seeking","join us","looking for","forming","starting a group","group forming","pst for invite","pm for invite","whisper for invite","spots open","slots open","need more","come join","anyone up for","anyone for","lf more","lf members","lf players","looking for members","looking for players","looking for tank","looking for healer","looking for dps","need tank","need healer","need dps","need people","need players","need members","open spot","open spots","last spot","last slot","group up","party forming","pst","pm","dm","whisper","inv","invite"];
    public var contextWords:Array<String> = ContextDefaults.merge(["run","runs","running","boss","bosses","farm","farming","clear","clears","dungeon","dungeons","bonus run","bonus runs","glory run","glory runs","heroic run","heroic runs","veteran run","veteran runs","normal run","normal runs","norm","vet","hc","hm","nm","heroic","veteran","normal","dung","dgn","farm run","farm runs","lf run","lf runs"]);
    public var targetAliases:Array<TargetAlias> = TargetDefaults.aliases();
    public var excludedWords:Array<String> = ["wts","wtb","selling","buying"];
    public function new() {}
    public static function clean(s:String,max:Int):String {
        if(s==null)return "";
        var end=s.indexOf("\x00");if(end>=0)s=s.substr(0,end);
        return StringTools.trim(~/[\x01-\x1f\x7f]/g.replace(s," ")).substr(0,max);
    }
    public static function difficulty(s:String):String return ["Normal","Veteran","Heroic"].indexOf(s)>=0?s:"Normal";
    public static function playerClass(s:String):String return clean(s,40);
}
