package solarflare.lfg;

import solarflare.lfg.Types.ChatEnvelope;

/** Received primitives only. Never populated from game history or serialized. */
class SessionHistory {
    public static inline var PER_SENDER=50;
    public static inline var LIMIT=2000;
    public static inline var MAX_AGE=1800;
    public var revision(default,null):Int=0;
    public var count(get,never):Int;
    var messages:Array<ChatEnvelope>=[];
    var lastSecond:Int=-1;
    public function new(){}
    function get_count():Int return messages.length;
    public function clear():Void {messages.resize(0);lastSecond=-1;revision++;}
    public function expire(now:Float):Void {
        if(lastSecond==Std.int(now))return;lastSecond=Std.int(now);
        var length=messages.length;
        messages=[for(e in messages)if(now-e.receivedAt<MAX_AGE)e];
        if(length!=messages.length)revision++;
    }
    public function add(e:ChatEnvelope,now:Float):Void {
        expire(now);
        if(!valid(e)||now-e.receivedAt>=MAX_AGE||e.receivedAt>now+1)return;
        messages.push({senderId:e.senderId,senderName:Config.clean(e.senderName,80),channel:e.channel,
            text:Config.clean(e.text,512),receivedAt:e.receivedAt});
        var senderCount=0;for(m in messages)if(m.senderId==e.senderId)senderCount++;
        while(senderCount>PER_SENDER){for(i in 0...messages.length)if(messages[i].senderId==e.senderId){messages.splice(i,1);break;}senderCount--;}
        while(messages.length>LIMIT)messages.shift();revision++;
    }
    public function forSender(id:String):Array<ChatEnvelope> {
        var result=[for(e in messages)if(e.senderId==id)e];result.reverse();return result;
    }
    public static function valid(e:ChatEnvelope):Bool return e!=null&&e.senderId!=null&&e.senderId!=""&&e.senderId.length<=128
        &&e.senderName!=null&&e.text!=null&&e.text.length<=512&&e.text.indexOf("\x00")<0&&Math.isFinite(e.receivedAt)&&ChannelPolicy.known(e.channel);
}
