package solarflare.lfg;
import solarflare.lfg.Types;

/** Owned local feed, sender history and filters. No relay state or persisted chat. */
class LocalFeed {
    public var rows(default,null):Array<Listing>=[];
    public var history(default,null)=new SessionHistory();
    public var revision(default,null)=0;
    public var config(default,null)=new Config();
    var parser:Parser;
    public function new() { parser=new Parser(TargetDefaults.activities(),config); parser.prepare(config); }
    public function configure(c:Config):Void {config=c;prepare();}
    public function prepare():Void {parser.prepare(config);revision++;}
    public function clear():Void {rows=[];history.clear();revision++;}
    public function ignored(id:String,wall:Float=-1):Bool {if(wall<0)wall=Sys.time();for(r in config.ignored)if(r.id==id&&(r.until==0||r.until>wall))return true;return false;}
    public function hide(key:String):Void {for(r in rows)if(r.key==key){r.hidden=true;revision++;break;}}
    public function ignore(id:String,name:String,permanent:Bool=false,wall:Float=-1):Void {
        if(wall<0)wall=Sys.time();config.ignored=[for(r in config.ignored)if(r.id!=id)r];
        if(config.ignored.length>=200)config.ignored.shift();config.ignored.push({id:id,name:name,until:permanent?0:wall+1800});
        rows=[for(r in rows)if(r.senderId!=id)r];revision++;
    }
    public function expire(now:Float):Void {
        history.expire(now);var kept=[for(r in rows)if(now-r.seen<config.expirySeconds&&now>=r.seen&&!ignored(r.senderId))r];
        if(kept.length!=rows.length){rows=kept;revision++;}
    }
    public function receive(e:ChatEnvelope):Void {
        if(!SessionHistory.valid(e)||!ChannelPolicy.enabled(config,e.channel)||ignored(e.senderId))return;
        history.add(e,e.receivedAt);
        var row=parser.parse(e,config);if(row==null)return;
        for(r in rows)if(r.key==row.key&&r.hidden&&row.seen-r.seen<config.expirySeconds)return;
        rows=[for(r in rows)if(r.key!=row.key)r];
        row.rowLabel=row.senderName+" / "+row.kind+" / "+row.target+"##lfg_"+row.uiId;
        rows.unshift(row);if(rows.length>200)rows.pop();revision++;
    }
    public function filtered(kind:String="All",activity:String="all",query:String="",sort:String="age",ascending:Bool=true):Array<Listing> {
        var terms=SearchTerms.parse(query);
        var out=[for(r in rows)if(!r.hidden&&!ignored(r.senderId)&&ChannelPolicy.enabled(config,r.channel)&&(!config.requireRecruitingContext||r.contextDetected)
            &&(kind=="All"||r.kind==kind)&&(activity=="all"||r.activityId==activity||r.matchedTargetIds.indexOf(activity)>=0)
            &&SearchTerms.matches([r.text,r.target,r.senderName,r.playerClass,r.channel],terms))r];
        out.sort(function(a,b){var n=switch(sort){case "target":Reflect.compare(a.target.toLowerCase(),b.target.toLowerCase());case "player":Reflect.compare(a.senderName.toLowerCase(),b.senderName.toLowerCase());case "type":Reflect.compare(a.kind,b.kind);case "channel":Reflect.compare(a.channel,b.channel);default:a.seen>b.seen?-1:a.seen<b.seen?1:0;};if(n==0)n=Reflect.compare(a.key,b.key);return ascending?n:-n;});return out;
    }
}
