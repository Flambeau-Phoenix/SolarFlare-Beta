package solarflare.lfg;

/** Pre-folded literal tokens; built when settings change, not per incoming message. */
class RecognitionWord {
    public var word:String;public var general:Bool;
    static var numbered=~/\blf[1-9][0-9]?m\b/i;
    public function new(s:String){word=fold(s);general=["need","needs","seeking","looking for","forming","anyone for","anyone up for","join us","pst","pm","dm","whisper","inv","invite"].indexOf(word)>=0;}
    public static function fold(s:String):String return StringTools.replace(s.toLowerCase(),"’","'");
    public function matches(hay:String):Bool {
        if(word=="lf#m")return numbered.match(hay);if(word=="")return false;var start=0;
        while(start<=hay.length-word.length){var at=hay.indexOf(word,start);if(at<0)break;var end=at+word.length;if((at==0||!wordChar(hay.charCodeAt(at-1)))&&(end==hay.length||!wordChar(hay.charCodeAt(end))))return true;start=at+1;}return false;
    }
    static function wordChar(c:Int):Bool return c>=128||c==95||(c>=48&&c<=57)||(c>=97&&c<=122);
}
class RecognitionIndex {
    public var words(default,null):Array<RecognitionWord>=[];
    public function new(values:Array<String>){for(v in values)words.push(new RecognitionWord(v));}
    public function matches(hay:String):Bool {for(w in words)if(w.matches(hay))return true;return false;}
}
