package solarflare.lfg;

typedef ChatEnvelope = {
    var senderId:String;
    var senderName:String;
    var channel:String;
    var text:String;
    var receivedAt:Float;
}

typedef IgnoreRule = { var id:String; var name:String; var until:Float; }
typedef TargetAlias = { var targetId:String; var name:String; var phrase:String; }
typedef Activity = { var id:String; var name:String; var aliases:Array<String>; }

class Draft {
    public var kind:String = "LFM";
    public var bonusRuns:Bool = false;
    public var activity:String = "";
    public var difficulty:String = "Normal";
    public var playerClass:String = "";
    public var note:String = "";
    public var channel:String = "All";
    public var members:Int = 0;
    public var capacity:Int = 4;
    public function new() {}
    public function copy():Draft {
        var d = new Draft();
        d.kind=kind; d.bonusRuns=bonusRuns; d.activity=activity; d.difficulty=difficulty;
        d.note=note; d.channel=channel; d.members=members; d.capacity=capacity;d.playerClass=playerClass;
        return d;
    }
}

class Listing {
    public var playerClass:String = "";
    public var key:String;
    public var uiId:String;
    public var senderId:String;
    public var senderName:String;
    public var kind:String;
    public var activityId:String;
    public var activity:String;
    public var target:String;
    public var composition:String;
    public var contextDetected:Bool=false;
    public var matchedTargetIds:Array<String>=[];
    public var channel:String;
    public var text:String;
    public var seen:Float;
    public var hidden:Bool = false;
    public var rowLabel:String = "";
    public var steamId:String = "";
    public var fareverCode:String = "";
    public function new() {}
}

typedef Session = { var id:String; var playerId:String; @:optional var playerName:String; var cursorFree:Bool; var available:Bool; }
typedef UiAction = {
    var kind:String;
    var sessionId:String;
    var text:String;
    var channel:String;
    var targetId:String;
    var targetName:String;
    var listingKey:String;
}

interface GameChatAdapter {
    public function session():Session;
    /** Null means submitted through the normal game API; it is not server delivery confirmation. */
    public function send(text:String, channel:String, targetId:String, targetName:String):Null<String>;
}
