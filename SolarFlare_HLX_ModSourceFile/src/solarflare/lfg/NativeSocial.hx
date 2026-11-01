package solarflare.lfg;

import solarflare.lfg.SocialService;

/** Installed-build social calls. Only invoked during Engine observation. */
class NativeSocial implements GameSocialAdapter {
    public var generation:Int=0;
    var pending:Map<String,Float>=[];
    var epoch=-1;
    public var feedback="";
    public function new() {}
    public function socialSnapshot(includePeople:Bool):SocialSnapshot {
        if(epoch!=this.generation){epoch=this.generation;pending=[];feedback="";}
        var result:SocialSnapshot={code:"",people:[],available:false};
        var app=GameApp.get();if(app==null||!solarflare.runtime.NativeTypes.is(app.me,"st.Player")||app.get_isLoading())return result;
        var me=app.me;var friends=me.friendList;
        if(me.accountProgress!=null&&me.accountProgress.social!=null)result.code=Config.clean(me.accountProgress.social.inviteCode,32);
        result.party=partyOf(me);
        if(!solarflare.runtime.NativeTypes.is(friends,"st.FriendList"))return result;result.available=true;
        for(uid=>stamp in pending)if(Sys.time()-stamp>30)pending.remove(uid);
        if(!includePeople)return result;
        var seen:Map<String,SocialPerson>=[];
        var list=friends.friends;
        if(list!=null)for(i in 0...Std.int(Math.min(200,list.length))){
            var raw=list.getDyn(i);if(raw==null)continue;
            var uid:String=HlxRuntime.resolveField(raw,"uid");if(uid==null||uid==me.uid||uid.length>128)continue;uid=Config.clean(uid,128);
            var info=friends.getFriendInfo(uid);if(info==null||info.metadata==null)continue;
            var meta=info.metadata;
            var p:SocialPerson={uid:uid,name:Config.clean(meta.heroName,80),online:meta.connected,friend:friends.isFriend(uid),pending:pending.exists(uid),realm:false,detail:Config.clean(meta.zone,80),level:meta.level};
            if(p.name=="")p.name="Friend";seen.set(uid,p);result.people.push(p);
        }
        for(p in playersOf(me.layer==null?null:me.layer.players,me)){
            var uid=p.uid;if(uid==null||uid==me.uid||uid.length>128)continue;uid=Config.clean(uid,128);
            if(seen.exists(uid)){var known=seen.get(uid);known.realm=true;known.online=true;}
            else {var person:SocialPerson={uid:uid,name:Config.clean(p.getName(),80),online:true,friend:friends.isFriend(uid),pending:pending.exists(uid),realm:true,detail:"Same game realm"};seen.set(uid,person);result.people.push(person);}
        }
        return result;
    }
    /** The generated Array<Dynamic> facade would use local ArrayObj offsets; read the underlying storage through ArrayBase instead. */
    function playersOf(proxy:Dynamic,me:Dynamic):Array<st.Player> {
        var out:Array<st.Player>=[];if(proxy==null)return out;
        var values:hl.types.ArrayBase=null;try values=HlxRuntime.resolveField(proxy,"array") catch(_:Dynamic){}
        if(values==null)return out;
        for(i in 0...Std.int(Math.min(200,values.length))){
            var raw=values.getDyn(i);if(raw==null)continue;
            if(!hl.Type.getDynamic(raw).safeCast(hl.Type.getDynamic(me)))continue;
            out.push(cast raw);
        }
        return out;
    }
    function partyOf(me:st.Player):PartySnapshot {
        var result=SocialService.emptyParty();var group=me.group;if(!solarflare.runtime.NativeTypes.is(group,"st.Group"))return result;
        var leaderUid="";try{var leader=group.get_leader();if(leader!=null)leaderUid=leader.uid;}catch(_:Dynamic){}
        for(p in playersOf(group.players,me)){
            var uid=p.uid;if(uid==null||uid.length>128||result.members.length>=8)continue;uid=Config.clean(uid,128);
            result.members.push({uid:uid,name:Config.clean(p.getName(),80),leader:uid==leaderUid,self:uid==me.uid});
        }
        var together=result.members.length>1;
        result.leader=together&&leaderUid==me.uid;
        try result.canLeave=together&&group.canRequestLeave() catch(_:Dynamic){}
        try {var reason=group.hasInvitePlayerAllowed();result.canInvite=result.members.length<SocialService.PARTY_CAPACITY&&reason!=null&&reason.isOk();}catch(_:Dynamic){}
        return result;
    }
    public function socialAction(kind:String,uid:String,code:String):Null<String> {
        var app=GameApp.get();if(app==null||!solarflare.runtime.NativeTypes.is(app.me,"st.Player")||app.get_isLoading()||app.isInCutscene()||!app.isCursorFree())return "Social actions unavailable in the current game state.";
        var me=app.me;var friends=me.friendList;var requestGeneration=this.generation;
        if(kind=="leaveParty"){
            var group=me.group;if(!solarflare.runtime.NativeTypes.is(group,"st.Group"))return "Party service unavailable.";
            var reason=group.checkRequestLeave();if(reason!=null&&!reason.isOk())return "Cannot leave the party: "+reason.getConstructorName();
            var result=group.requestLeave(function(ok:Bool){if(this.generation!=requestGeneration)return;feedback=ok?"You left the party.":"The game could not complete leaving the party.";});
            if(result!=null&&!result.isOk())return "Cannot leave the party: "+result.getConstructorName();
            return null;
        }
        if(!solarflare.runtime.NativeTypes.is(friends,"st.FriendList"))return "Friend service unavailable.";
        if(kind=="addCode"){
            var normalized=FareverContact.normalize(code);if(!FareverContact.valid(normalized))return "Enter a Farever code with 12 letters or digits.";
            var own=me.accountProgress==null||me.accountProgress.social==null?"":FareverContact.normalize(me.accountProgress.social.inviteCode);
            if(own==normalized)return "That is your own Farever code.";
            var key="code:"+normalized;if(pending.exists(key)&&Sys.time()-pending.get(key)<30)return "A friend request is already pending.";
            pending.set(key,Sys.time());
            friends.inviteFriend(st.FriendCode.unformatCode(normalized),function(error:String){if(this.generation!=requestGeneration)return;pending.remove(key);feedback=error==null||error==""?"Friend request submitted; acceptance is pending.":Config.clean(error,160);});
            return null;
        }
        if(uid==null||uid==""||uid==me.uid||uid.length>128)return "Choose another player.";
        // Only trust an ID obtained from the native roster, never a relay display name.
        var found=false;for(p in socialSnapshot(true).people)if(p.uid==uid)found=true;
        if(!found)return "Player is no longer in your native friends or realm roster.";
        if(kind=="addFriend"){
            if(friends.isFriend(uid))return "This player is already on your friend list.";
            if(pending.exists(uid)&&Sys.time()-pending.get(uid)<30)return "A friend request is already pending.";
            var reason=friends.checkAddFriend(uid);if(reason!=null&&!reason.isOk())return "Cannot add friend: "+reason.getConstructorName();
            pending.set(uid,Sys.time());
            var result=friends.addFriend(uid,function(ok:Bool){if(this.generation!=requestGeneration)return;pending.remove(uid);feedback=ok?"Friend request submitted; acceptance is pending.":"Friend request failed.";});
            if(result!=null&&!result.isOk()){pending.remove(uid);return "Cannot add friend: "+result.getConstructorName();}
        }else if(kind=="removeFriend"){
            if(!friends.isFriend(uid))return "This player is not on your friend list.";
            var reason=friends.checkRemoveFriend(uid);if(reason!=null&&!reason.isOk())return "Cannot remove friend: "+reason.getConstructorName();
            var result=friends.removeFriend(uid,function(ok:Bool){if(this.generation!=requestGeneration)return;feedback=ok?"Friend removed.":"The game could not remove this friend.";});
            if(result!=null&&!result.isOk())return "Cannot remove friend: "+result.getConstructorName();
        }else if(kind=="invite"){
            if(!solarflare.runtime.NativeTypes.is(me.group,"st.Group"))return "Party service unavailable.";
            var leader=me.group.get_leader();if(leader==null||leader.uid!=me.uid)return "Only the party leader can invite players.";
            var reason=me.group.hasInvitePlayerAllowed();if(reason!=null&&!reason.isOk())return "Cannot invite: "+reason.getConstructorName();
            if(!solarflare.runtime.NativeTypes.is(me.whispers,"st.player.Whispers"))return "Invitation service unavailable.";
            me.whispers.sendInviteGroup(uid);
        }else return "Unsupported social action.";
        return null;
    }
    public function takeFeedback():String {var value=feedback;feedback="";return value;}
}
