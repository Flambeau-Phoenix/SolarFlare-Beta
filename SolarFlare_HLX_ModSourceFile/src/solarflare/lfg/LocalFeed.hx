package solarflare.lfg;
import solarflare.lfg.Types;

/** Owned session-only feed. Expiry, duplicate updates and bounds do not depend on rendering. */
class LocalFeed {
    public var rows(default,null):Array<Listing>=[];
    public var revision(default,null)=0;
    public var config(default,null)=new Config();
    var parser:Parser;
    public function new() { parser=new Parser(TargetDefaults.activities(),config); parser.prepare(config); }
    public function clear():Void { rows=[];revision++; }
    public function expire(now:Float):Void {
        var kept=[for(r in rows)if(now-r.seen<600&&now>=r.seen)r];
        if(kept.length!=rows.length){rows=kept;revision++;}
    }
    public function receive(e:ChatEnvelope):Void {
        var row=parser.parse(e,config);if(row==null)return;
        rows=[for(r in rows)if(r.key!=row.key)r];
        row.rowLabel=row.senderName+" / "+row.kind+" / "+row.target+"##lfg_"+row.uiId;
        rows.unshift(row);if(rows.length>200)rows.pop();revision++;
    }
}
