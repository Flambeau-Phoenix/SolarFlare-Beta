package solarflare.lfg;

typedef SocialPerson={var uid:String;var name:String;var online:Bool;var friend:Bool;var pending:Bool;var realm:Bool;var detail:String;@:optional var level:Int;}
typedef PartyMember={var uid:String;var name:String;var leader:Bool;var self:Bool;}
/** Primitive copy of the native group: members, whether you lead it, and the game's own permission answers. */
typedef PartySnapshot={var members:Array<PartyMember>;var leader:Bool;var canLeave:Bool;var canInvite:Bool;var capacity:Int;}
typedef SocialSnapshot={var code:String;var people:Array<SocialPerson>;var available:Bool;@:optional var party:PartySnapshot;}
interface GameSocialAdapter {
    public function socialSnapshot(includePeople:Bool):SocialSnapshot;
    public function socialAction(kind:String,uid:String,code:String):Null<String>;
}

class SocialService {
    public static inline var PARTY_CAPACITY=4;
    public static function emptyParty():PartySnapshot return {members:[],leader:false,canLeave:false,canInvite:false,capacity:PARTY_CAPACITY};
}
