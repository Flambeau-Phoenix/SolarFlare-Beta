package solarflare.lfg;
import solarflare.lfg.SocialService;
import solarflare.lfg.Types;

private typedef LocalAction={kind:String,uid:String,name:String,text:String,generation:Int};
/** Engine access and user-requested native actions occur only in the observation phase. */
class LfgController {
    public var feed(default,null)=new LocalFeed();
    public var people(default,null):Array<SocialPerson>=[];
    public var party(default,null):PartySnapshot=SocialService.emptyParty();
    public var code(default,null)="";
    public var status="Enable the chat watcher to collect new messages in this session.";
    public var generation(default,null)=0;
    public var available(default,null)=false;
    public var watch=false;
    var social=new NativeSocial();
    var identity="";var cursor=new ChatCursor();var nextChat=0.;var nextPeople=0.;var wasOpen=false;var wasWatch=false;
    var nextObserve=0.;
    var actions:Array<LocalAction>=[];
    public function new() {}
    public function queue(kind:String,uid:String="",name:String="",text:String=""):Void {
        if(actions.length<8)actions.push({kind:kind,uid:uid,name:name,text:Config.clean(text,240),generation:generation});
    }
    public function observe(app:GameApp,open:Bool,now:Float):Void {
        if(!watch&&!open&&!wasOpen&&!wasWatch&&feed.rows.length==0&&actions.length==0)return;
        if(now<nextObserve&&actions.length==0&&open==wasOpen&&watch==wasWatch)return;
        nextObserve=now+0.25;
        var me=app.me;
        var ready=solarflare.runtime.NativeTypes.is(me,"st.Player")&&!app.get_isLoading()&&solarflare.HealthCache.isHeroObject(app.hero);
        ready=ready&&app.connectionInfo!=null;
        var key=ready?me.uid+"|"+haxe.Int64.toStr(app.connectionInfo.heroID):"";
        if(key!=identity){identity=key;generation++;social.generation=generation;feed.clear();people=[];party=SocialService.emptyParty();code="";actions=[];cursor.reset();nextPeople=0;}
        available=ready&&!app.isInCutscene();
        if(!ready){wasOpen=open;wasWatch=watch;return;}
        if(open&&!wasOpen)nextPeople=0;wasOpen=open;
        if(watch!=wasWatch){cursor.reset();wasWatch=watch;}
        feed.expire(now);
        if(watch&&now>=nextChat){
            nextChat=now+0.25;
            try {
                var history=st.player.ChatClient.history;
                if(history!=null){
                    var range=cursor.range(history.length);
                    for(i in range.start...range.end){
                        var raw=history.getDyn(i);if(raw==null)continue;
                        var m:{sender:{uid:String,name:String},text:String,channel:st.Channel}=cast raw;
                        if(m.sender==null||m.sender.uid==null||m.sender.uid.length>128||m.channel==null||m.text==null||m.text.length>512)continue;
                        var channel=m.channel.getConstructorName();
                        if(["All","Local","Group","Player"].indexOf(channel)<0)continue;
                        feed.receive({senderId:Config.clean(m.sender.uid,128),senderName:Config.clean(m.sender.name,80),channel:channel,text:solarflare.ui.ByteUtil.materialize(m.text),receivedAt:now});
                    }
                }
                feed.expire(now);
            }catch(_:Dynamic){status="Chat watcher unavailable in the current game state.";}
        }
        if(open&&now>=nextPeople){
            nextPeople=now+1;
            try {var s=social.socialSnapshot(true);people=s.people;party=s.party==null?SocialService.emptyParty():s.party;code=FareverContact.format(s.code);}
            catch(_:Dynamic){people=[];party=SocialService.emptyParty();status="Friends and party information is unavailable.";}
        }
        var pending=actions;actions=[];
        for(a in pending){
            if(a.generation!=generation||!open||!available||!app.isCursorFree())continue;
            try {
                if(a.kind=="whisper"){
                    if(a.uid==""||a.uid==me.uid||a.text==""||!solarflare.runtime.NativeTypes.is(me.whispers,"st.player.Whispers")){status="Choose a player and enter a message.";continue;}
                    var requestGeneration=generation;
                    var message={args:null,channel:st.Channel.Player(a.uid,a.name),localStamp:null,localTextId:null,notify:null,sender:{uid:me.uid,name:me.getName()},text:a.text};
                    me.whispers.sendMessage(a.uid,st.player.Message.ChatMessage(message),function(ok:Bool){if(generation==requestGeneration)status=ok?"Whisper submitted.":"Whisper failed; the player may be unavailable.";});
                    status="Submitting whisper...";
                }else{
                    var error=social.socialAction(a.kind,a.uid,a.text);
                    status=error==null?"Request submitted through Farever.":error;nextPeople=0;
                }
            }catch(_:Dynamic){status="Farever could not complete the action.";}
        }
        var feedback=social.takeFeedback();if(feedback!="")status=feedback;
    }
    public function clearPending():Void { actions=[]; }
}
