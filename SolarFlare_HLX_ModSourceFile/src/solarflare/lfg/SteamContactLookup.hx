package solarflare.lfg;

import haxe.Int64;

class SteamContactMatch {
    public var value:String;
    public var profile:String;
    public var label:String;
    public var copyLabel:String;
    public function new(value:String,profile:String){this.value=value;this.profile=profile;label="Open Steam profile - "+value;copyLabel="Copy Steam code##"+profile;}
}

/** Pure, explicit-action lookup. Never called by message receipt or render loops. */
class SteamContactLookup {
    static var base=Int64.parseString("76561197960265728");
    static var maximum=Int64.parseString("76561202255233023");

    public static function profileFor(value:String):String {
        if(value==null)return "";
        var id="";
        if(~/^[0-9]{1,10}$/.match(value)){
            var account=Std.parseFloat(value);
            if(account<1||account>4294967295.0)return "";
            id=Int64.toStr(base+Int64.parseString(value));
        }else if(~/^[0-9]{17}$/.match(value)){
            var number=Int64.parseString(value);
            if(Int64.compare(number,base)<=0||Int64.compare(number,maximum)>0)return "";
            id=Int64.toStr(number);
        }
        return id==""?"":"https://steamcommunity.com/profiles/"+id;
    }

    static function add(result:Array<SteamContactMatch>,value:String):Void {
        var profile=profileFor(value);if(profile==""||result.length>=8)return;
        for(candidate in result)if(candidate.profile==profile)return;
        result.push(new SteamContactMatch(value,profile));
    }

    public static function find(messages:Array<String>):Array<SteamContactMatch> {
        var result:Array<SteamContactMatch>=[];
        // First pass over this person's messages: our button syntax has priority.
        var i=messages.length;
        while(i>0){
            var text=messages[--i];if(text==null||text.length>512)continue;
            var tag=~/\[(?:steam|steamid|steam id)[:\s]+([0-9]{1,20})\]/ig;
            while(tag.match(text)){add(result,tag.matched(1));text=tag.matchedRight();}
            if(result.length>0)return result;
        }
        // General formats are considered only when the complete first pass failed.
        i=messages.length;
        while(i>0){
            var text=messages[--i];if(text==null||text.length>512)continue;
            var numbers=~/\b([0-9]{17})\b/g;
            var rest=text;
            while(numbers.match(rest)){add(result,numbers.matched(1));rest=numbers.matchedRight();}
            var steam2=~/\bSTEAM_[01]:([01]):([0-9]{1,10})\b/ig;
            rest=text;
            while(steam2.match(rest)){
                var account=Std.parseFloat(steam2.matched(2))*2+Std.parseFloat(steam2.matched(1));
                if(account>=1&&account<=4294967295.0)add(result,Int64.toStr(Int64.fromFloat(account)));
                rest=steam2.matchedRight();
            }
            var steam3=~/\[U:1:([0-9]{1,10})\]/ig;
            rest=text;
            while(steam3.match(rest)){add(result,steam3.matched(1));rest=steam3.matchedRight();}
            var labelled=~/\b(?:steam(?:\s*id)?|friend\s*code)\s*(?:is\s+)?[:#=]?\s*([0-9]{1,20})\b/ig;
            rest=text;
            while(labelled.match(rest)){add(result,labelled.matched(1));rest=labelled.matchedRight();}
            // Short unlabelled numbers embedded in prose are too ambiguous.
            var standalone=~/^\s*([0-9]{5,10})\s*[.!]?\s*$/;
            if(standalone.match(text))add(result,standalone.matched(1));
            if(result.length>0)return result;
        }
        return result;
    }
}
