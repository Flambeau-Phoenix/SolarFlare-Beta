package solarflare.lfg;
import solarflare.lfg.SocialService;
import solarflare.lfg.Types;

private typedef LocalAction={kind:String,uid:String,name:String,text:String,channel:String,generation:Int};
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
    public var settingsRevision(default,null)=0;
    public var peopleRevision(default,null)=0;
    public var playerId(default,null)="";
    public var hasSettings(default,null)=false;
    public var preview(default,null)="";
    public var cooldown(default,null)=0;
    public var alerts(default,null)=new Alerts();
    public var posting(default,null)=new LocalPosting();
    var social=new NativeSocial();
    var identity="";var cursor=new ChatCursor();var nextChat=0.;var nextPeople=0.;var wasOpen=false;var wasWatch=false;
    var nextObserve=0.;
    var actions:Array<LocalAction>=[];
    var preparedRevision=-1;
    public function new() {}
    public function changed():Void {settingsRevision++;solarflare.ui.SettingsStore.markDirty();}
    public function applySettings(data:Dynamic):Void {
        // Legacy SolarFlare profiles have no nested LFG preferences; do not erase a recovered config.
        if(data==null||!Reflect.isObject(data)||Std.isOfType(data,Array)||Std.isOfType(data,String))return;
        hasSettings=true;feed.configure(Config.decode(data));settingsRevision++;
    }
    public function queue(kind:String,uid:String="",name:String="",text:String="",channel:String=""):Void {
        if(text.length>(kind=="post"?512:240)){status="Message is too long.";return;}
        if(actions.length<8)actions.push({kind:kind,uid:uid,name:name,text:Config.clean(text,kind=="post"?512:240),channel:channel,generation:generation});
    }
    public function observe(app:GameApp,open:Bool,now:Float):Void {
        if(!watch&&!open&&!wasOpen&&!wasWatch&&feed.rows.length==0&&feed.history.count==0&&actions.length==0)return;
        if(now<nextObserve&&actions.length==0&&open==wasOpen&&watch==wasWatch)return;
        nextObserve=now+0.25;
        if(preparedRevision!=settingsRevision){preparedRevision=settingsRevision;feed.prepare();}
        var me=app.me;
        var ready=solarflare.runtime.NativeTypes.is(me,"st.Player")&&!app.get_isLoading()&&solarflare.HealthCache.isHeroObject(app.hero);
        ready=ready&&app.connectionInfo!=null;
        var key=ready?me.uid+"|"+haxe.Int64.toStr(app.connectionInfo.heroID):"";
        if(key!=identity){identity=key;generation++;social.generation=generation;feed.clear();people=[];party=SocialService.emptyParty();code="";actions=[];cursor.reset();nextPeople=0;alerts.reset();posting.reset();peopleRevision++;}
        playerId=ready?solarflare.ui.ByteUtil.materialize(me.uid):"";
        available=ready&&!app.isInCutscene();
        if(!ready){wasOpen=open;wasWatch=watch;status="Waiting for the current character and chat service.";return;}
        if(open&&!wasOpen)nextPeople=0;wasOpen=open;
        if(watch!=wasWatch){cursor.reset();wasWatch=watch;status=watch?"Watching newly received messages from enabled channels.":"Chat watcher paused. Existing entries expire normally.";}
        feed.expire(now);
        preview=Parser.preview(feed.config.draft);posting.update(feed.config,now);cooldown=posting.cooldown(now);
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
                        if(!ChannelPolicy.enabled(feed.config,channel))continue;
                        feed.receive({senderId:Config.clean(solarflare.ui.ByteUtil.materialize(m.sender.uid),128),senderName:Config.clean(solarflare.ui.ByteUtil.materialize(m.sender.name),80),channel:channel,text:solarflare.ui.ByteUtil.materialize(m.text),receivedAt:now});
                    }
                }
                feed.expire(now);
            }catch(_:Dynamic){status="Chat watcher unavailable in the current game state.";}
        }
        if(open&&now>=nextPeople){
            nextPeople=now+1;
            try {var s=social.socialSnapshot(true);people=s.people;party=s.party==null?SocialService.emptyParty():s.party;code=FareverContact.format(s.code);peopleRevision++;}
            catch(_:Dynamic){people=[];party=SocialService.emptyParty();status="Friends and party information is unavailable.";}
        }
        var pending=actions;actions=[];
        for(a in pending){
            if(a.generation!=generation||!open||!available||!app.isCursorFree())continue;
            try {
                if(a.kind=="post"){
                    var error=posting.postError(feed.config,a.text,a.channel,now);if(error!=""){status=error;continue;}
                    if(!solarflare.runtime.NativeTypes.is(me.chatClient,"st.player.ChatClient")){status="Chat client is unavailable.";continue;}
                    var channel:st.Channel;
                    if(a.channel=="Local"){var pos=app.hero.position;if(pos==null){status="Character position is unavailable.";continue;}channel=st.Channel.Local({x:pos.x,y:pos.y,z:pos.z});}else channel=st.Channel.All;
                    var message={args:null,channel:channel,localStamp:null,localTextId:null,notify:null,sender:{uid:me.uid,name:me.getName()},text:a.text};
                    me.chatClient.sendMessage(message);posting.posted(feed.config,now);cooldown=60;status="Post submitted to game chat; delivery is not confirmed.";
                }else if(a.kind=="whisper"){
                    var error=posting.whisperError(a.text,now);if(error!=""){status=error;continue;}
                    if(a.uid==""||a.uid==me.uid||a.text==""||!solarflare.runtime.NativeTypes.is(me.whispers,"st.player.Whispers")){status="Choose a player and enter a message.";continue;}
                    var requestGeneration=generation;
                    var message={args:null,channel:st.Channel.Player(a.uid,a.name),localStamp:null,localTextId:null,notify:null,sender:{uid:me.uid,name:me.getName()},text:a.text};
                    me.whispers.sendMessage(a.uid,st.player.Message.ChatMessage(message),function(ok:Bool){if(generation==requestGeneration)status=ok?"Whisper submitted.":"Whisper failed; the player may be unavailable.";});
                    posting.whispered(now);
                    status="Submitting whisper...";
                }else{
                    var error=social.socialAction(a.kind,a.uid,a.text);
                    status=error==null?"Request submitted through Farever.":error;nextPeople=0;
                }
            }catch(_:Dynamic){status="Farever could not complete the action.";}
        }
        var feedback=social.takeFeedback();if(feedback!="")status=feedback;
        alerts.update(feed,feed.config,playerId,now);
    }
    public function clearPending():Void { actions=[]; }
}
