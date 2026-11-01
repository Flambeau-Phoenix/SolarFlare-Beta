package solarflare.lfg;

import solarflare.lfg.Types.Listing;

/** Bounded, session-only watch notifications derived from the accepted feed. */
class Alerts {
    public var unread(default,null):Int=0;
    public var title(default,null):String="";
    public var body(default,null):String="";
    public var listingKey(default,null):String="";
    public var toastUntil(default,null):Float=0;
    public var soundRequested:Bool=false;
    var seen:Map<String,Float>=new Map();
    var nextToast:Float=0;
    var pending:Map<String,Bool>=new Map();
    var unreadKeys:Map<String,Bool>=new Map();
    public function new() {}
    public function reset():Void {seen.clear();unreadKeys.clear();unread=0;toastUntil=0;pending.clear();nextToast=0;soundRequested=false;listingKey="";}
    public function acknowledge():Void {unreadKeys.clear();unread=0;toastUntil=0;pending.clear();soundRequested=false;}
    public static function matches(l:Listing,c:Config):Bool {
        if(l.kind!="LFM"||!l.contextDetected||l.hidden||!ChannelPolicy.enabled(c,l.channel))return false;
        var custom="custom:"+Parser.normalized(l.target);
        for(w in c.watchActivities) {
            if(w==l.activityId || w==custom)return true;
            if(StringTools.startsWith(w,"custom:")){
                var query=w.substr(7);var match:String=null;var ambiguous=false;
                for(a in c.targetAliases)if(Parser.normalized(a.phrase)==query){if(match!=null&&match!=a.targetId)ambiguous=true;match=a.targetId;}
                if(!ambiguous&&match==l.activityId)return true;
            }
        }
        return false;
    }
    public function update(board:LocalFeed,c:Config,playerId:String,now:Float):Void {
        if(!c.alertsEnabled){reset();return;}
        var active:Map<String,Bool>=new Map();
        for(key in seen.keys())if(now-seen.get(key)>=c.expirySeconds)seen.remove(key);
        for(l in board.rows) {
            if(l.senderId==playerId || !matches(l,c)||(now-l.seen>=c.expirySeconds)||board.ignored(l.senderId))continue;
            active.set(l.key,true);
            if(!seen.exists(l.key)) {
                pending.set(l.key,true);unreadKeys.set(l.key,true);
            }
            seen.set(l.key,l.seen);
        }
        // Hiding, ignoring or editing a watch must not reset deduplication before expiry.
        // Keep this bookkeeping bounded even when the board evicts busy-chat listings.
        var size=0;for(key in seen.keys())size++;
        while(size>200){
            var oldest:String=null;var stamp:Float=Math.POSITIVE_INFINITY;
            for(key in seen.keys())if(seen.get(key)<stamp){oldest=key;stamp=seen.get(key);}
            if(oldest==null)break;seen.remove(oldest);size--;
        }
        for(key in pending.keys())if(!active.exists(key))pending.remove(key);
        for(key in unreadKeys.keys())if(!active.exists(key))unreadKeys.remove(key);
        unread=0;for(key in unreadKeys.keys())unread++;
        unread=Std.int(Math.min(99,unread));
        var count=0;for(key in pending.keys())count++;
        if(count>0 && now>=nextToast) {
            var latest:Listing=null;
            for(l in board.rows)if(pending.exists(l.key)&&(latest==null||l.seen>=latest.seen))latest=l;
            listingKey=latest.key;body=latest.target+" - "+latest.senderName+" ("+latest.channel+")";
            title=count==1?"Matching group found":count+" matching groups found";
            pending.clear();toastUntil=now+8;nextToast=now+10;soundRequested=c.alertSound;
        }
    }
}
