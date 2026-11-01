package solarflare.lfg;

/** Farever codes are distinct from numeric Steam contacts. No engine calls here. */
class FareverContact {
    public static function normalize(value:String):String return value==null?"":~/[\s-]/g.replace(value,"").toUpperCase();
    public static function valid(value:String):Bool return ~/^[A-Z0-9]{12}$/.match(normalize(value));
    public static function format(value:String):String {
        var s=normalize(value);return valid(s)?s.substr(0,4)+"-"+s.substr(4,4)+"-"+s.substr(8,4):"";
    }
    public static function withoutTags(text:String):String return ~/\[Farever:\s*[^\]]*\]/gi.replace(text==null?"":text,"");
    public static function extract(text:String):String {
        var re=~/\[Farever:\s*([A-Z0-9 -]{12,16})\]/i;
        return text!=null&&re.match(text)?format(re.matched(1)):"";
    }
    public static function attach(text:String,code:String,max:Int=240):String {
        var s=format(code);if(s=="")return text;
        var tag="[Farever: "+s+"]";
        return Config.clean(withoutTags(text),Std.int(Math.max(0,max-tag.length-1)))+" "+tag;
    }
}
