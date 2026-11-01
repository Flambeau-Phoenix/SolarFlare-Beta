package solarflare.lfg;

import solarflare.lfg.Types;
import solarflare.lfg.RecognitionIndex.RecognitionWord;

class Parser {
    public var activities(default,null):Array<Activity>;
    var cached:Config=null;var aliases:Array<TargetAlias>=[];
    var aliasRef:Array<TargetAlias>=null;
    var matchedTargets:Array<TargetAlias>=[];
    var aliasWords:Array<RecognitionWord>=[];
    var bareTargets:Map<String,Bool>=[];
    var soloIndex:RecognitionIndex;var moreIndex:RecognitionIndex;var contextIndex:RecognitionIndex;var excludeIndex:RecognitionIndex;
    var soloRef:Array<String>;var moreRef:Array<String>;var contextRef:Array<String>;var excludeRef:Array<String>;
    var question=~/^\s*(what|how|where|why|does|do i|can someone explain|anyone know|is there|are there)\b/i;
    var discussion=~/\b(guide|strategy|mechanics|tips|lore|yesterday|already killed|finished|completed|was running|were running|is hard|is easy|was hard|was easy|drops|dropped|damage|has|killed|beat|love|hate)\b/i;
    var composition=~/\b([0-9]{1,2})\s*\/\s*([0-9]{1,2})\b/;
    var bracket=~/\[([^\]]{1,80})\]/g;
    var defaults=new Config();
    public function new(activities:Array<Activity>,?defaultConfig:Config){this.activities=activities;if(defaultConfig!=null)defaults=defaultConfig;}
    public function prepare(c:Config):Void {
        cached=c;aliasRef=c.targetAliases;aliases=c.targetAliases.copy();
        // Synthetic/third-party catalogues remain usable without adding production aliases.
        var known=TargetDefaults.activities();
        for(a in activities){var builtin=false;for(k in known)if(k.id==a.id)builtin=true;if(!builtin)for(p in a.aliases)aliases.push({targetId:a.id,name:a.name,phrase:p});}
        aliasWords=[for(a in aliases)new RecognitionWord(a.phrase)];
        bareTargets=[];for(a in aliases)bareTargets.set(normalized(a.phrase),true);
        soloRef=c.lfgWords;moreRef=c.lfmWords;contextRef=c.contextWords;excludeRef=c.excludedWords;
        soloIndex=new RecognitionIndex(soloRef);moreIndex=new RecognitionIndex(moreRef);contextIndex=new RecognitionIndex(contextRef);excludeIndex=new RecognitionIndex(excludeRef);
    }
    public static function normalized(s:String):String {s=Config.clean(s,512).toLowerCase();return StringTools.trim(~/[^a-z0-9]+/g.replace(s," "));}
    function targetFor(text:String):TargetAlias {
        var length=0;matchedTargets=[];
        for(i in 0...aliases.length)if(aliasWords[i].matches(text)){
            var a=aliases[i];var size=a.phrase.length;
            if(size>length){matchedTargets=[];length=size;}
            if(size==length){var exists=false;for(v in matchedTargets)if(v.targetId==a.targetId)exists=true;if(!exists)matchedTargets.push(a);}
        }
        matchedTargets.sort((a,b)->Reflect.compare(a.targetId,b.targetId));
        return matchedTargets.length==0?null:matchedTargets[0];
    }
    function customTarget(text:String,c:Config):String {
        var rest=text;
        while(bracket.match(rest)){var b=Config.clean(bracket.matched(1),80);if(!~/^(lfg|lfm|lf[0-9]+m)$/i.match(b))return b;rest=bracket.matchedRight();}
        rest=text;
        // Longest configured prefix wins; removal affects recognition as well as extraction.
        var prefix="";for(word in c.lfgWords.concat(c.lfmWords))if(StringTools.startsWith(rest.toLowerCase(),word.toLowerCase()+" ")&&word.length>prefix.length)prefix=word;
        if(prefix!="")rest=rest.substr(prefix.length+1);else rest=~/^\s*lf[1-9][0-9]?m\b[\s:!\-]*/i.replace(rest,"");
        rest=~/\b(need|needs|seeking|with|looking for)\b.*$/i.replace(rest,"");
        rest=~/\b([0-9]+\s*\/\s*[0-9]+)\b/g.replace(rest,"");
        rest=StringTools.trim(~/[\s,;!\-]+/g.replace(rest," "));return rest==""?"Unspecified":Config.clean(rest,80);
    }
    public function parse(e:ChatEnvelope,?config:Config):Listing {
        if(e==null||e.senderId==null||e.senderId==""||e.senderName==null||e.text==null||e.text.length>512||e.text.indexOf("\x00")>=0||!Math.isFinite(e.receivedAt))return null;
        var c=config==null?defaults:config;if(c!=cached||aliasRef!=c.targetAliases||soloRef!=c.lfgWords||moreRef!=c.lfmWords||contextRef!=c.contextWords||excludeRef!=c.excludedWords)prepare(c);
        var text=Config.clean(e.text,512);var recruitingText=StringTools.trim(FareverContact.withoutTags(SteamContact.withoutTags(text)));var folded=RecognitionWord.fold(recruitingText);if(excludeIndex.matches(folded))return null;
        var target=targetFor(folded);var solo=soloIndex.matches(folded);var more=false;var explicitMore=false;
        for(word in moreIndex.words)if(word.matches(folded)){
            if(!word.general){more=true;explicitMore=true;}else if(target!=null)more=true;
        }
        if(solo&&explicitMore)return null;
        var contextual=!question.match(text)&&((solo||more)&&(!discussion.match(text)||solo||explicitMore)
            ||target!=null&&!bareTargets.exists(normalized(recruitingText))&&contextIndex.matches(folded)&&!discussion.match(text)&&text.indexOf("?")<0);
        if(!contextual&&(target==null||c.requireRecruitingContext))return null;
        var l=new Listing();l.senderId=e.senderId;l.senderName=Config.clean(e.senderName,80);
        l.contextDetected=contextual;l.kind=contextual?(solo?"LFG":"LFM"):"Mention";
        l.matchedTargetIds=[for(a in matchedTargets)a.targetId];
        l.activityId=matchedTargets.length>1?"ambiguous":(target==null?"other":target.targetId);
        l.target=matchedTargets.length>1?[for(a in matchedTargets)a.name].join(" / "):(target==null?customTarget(recruitingText,c):target.name);
        l.activity=target==null?"Other/Custom":l.target;
        var key=~/[^\x00-\x7f]/.match(l.target)?Config.clean(l.target,80).toLowerCase():normalized(l.target);
        l.key=e.senderId+"\x1f"+l.kind+"\x1f"+key;l.uiId=haxe.crypto.Sha256.encode(l.key).substr(0,24);
        l.composition="Size unspecified";if(composition.match(text)){var n=Std.parseInt(composition.matched(1));var cap=Std.parseInt(composition.matched(2));if(cap>0&&cap<=40&&n<=cap)l.composition=n+"/"+cap;}
        l.steamId=SteamContact.extract(text);
        l.fareverCode=FareverContact.extract(text);
        l.channel=e.channel;l.text=text;l.seen=e.receivedAt;return l;
    }
    public static function matchesExact(words:Array<String>,word:String):Bool {for(w in words)if(w.toLowerCase()==word.toLowerCase())return true;return false;}
    public static function matchesWords(text:String,words:Array<String>):Bool {
        var hay=text.toLowerCase();for(word in words){
            if(word.toLowerCase()=="lf#m"){if(~/\blf[1-9][0-9]?m\b/i.match(text))return true;continue;}
            var n=word.toLowerCase();if(n=="")continue;var start=0;
            while(start<=hay.length-n.length){var at=hay.indexOf(n,start);if(at<0)break;var end=at+n.length;if((at==0||!wordChar(hay.charCodeAt(at-1)))&&(end==hay.length||!wordChar(hay.charCodeAt(end))))return true;start=at+1;}
        }return false;
    }
    static function wordChar(c:Int):Bool return c>=128||c==95||(c>=48&&c<=57)||(c>=97&&c<=122);
    public static function preview(d:Draft):String {
        var target=Config.clean(d.activity,80);if(target=="")return "Choose or enter an activity.";target=~/[\[\]]/g.replace(target,"");
        var s="["+d.kind+"] ["+target+"] - "+Config.difficulty(d.difficulty);if(d.bonusRuns)s+=" - Bonus Runs";
        if(d.kind=="LFM"&&d.capacity>0)s+=" ("+d.members+"/"+d.capacity+")";
        if(Config.playerClass(d.playerClass)!="")s+=" - Class: "+d.playerClass;
        if(d.note!="")s+=" - "+Config.clean(d.note,160);return s;
    }
}
