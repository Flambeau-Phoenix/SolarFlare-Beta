package solarflare.lfg;

/** Manual post policy. Reminder flags never enqueue or send messages. */
class LocalPosting {
    var nextPost=0.;var nextWhisper=0.;var reminderDue=0.;
    public var reminderReady(default,null)=false;
    public function new(){}
    public function reset():Void {nextPost=nextWhisper=reminderDue=0;reminderReady=false;}
    public function cooldown(now:Float):Int return Std.int(Math.ceil(Math.max(0,nextPost-now)));
    public function update(c:Config,now:Float):Void {if(!c.reminder){reminderDue=0;reminderReady=false;}if(reminderDue>0&&now>=reminderDue){reminderDue=0;reminderReady=true;}}
    public function postError(c:Config,text:String,channel:String,now:Float):String {
        if(cooldown(now)>0)return "Please wait before posting again.";
        if(channel!="All"&&channel!="Local")return "Choose All or Local game chat.";
        if(c.draft.activity=="")return "Enter an activity before posting.";
        if(text!=Parser.preview(c.draft)||channel!=c.draft.channel)return "The draft changed. Review the updated preview before posting.";
        if(text.length>512||text=="")return "Post is empty or too long.";return "";
    }
    public function posted(c:Config,now:Float):Void {nextPost=now+60;reminderReady=false;reminderDue=c.reminder?nextPost:0;}
    public function whisperError(text:String,now:Float):String return now<nextWhisper?"Please wait before sending another whisper.":text==""||text.length>240?"Enter a whisper of 1-240 characters.":"";
    public function whispered(now:Float):Void nextWhisper=now+2;
}
