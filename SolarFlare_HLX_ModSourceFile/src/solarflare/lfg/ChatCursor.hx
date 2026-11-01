package solarflare.lfg;

/** Tracks offsets only. First observation seeds the tail; each pass admits at most 32 new messages. */
class ChatCursor {
    var position=-1;
    public function new() {}
    public function reset():Void {position=-1;}
    public function range(length:Int):{start:Int,end:Int} {
        if(position<0){position=length;return {start:length,end:length};}
        if(position>length)position=0;
        var start=position;position=Std.int(Math.min(length,start+32));return {start:start,end:position};
    }
}
