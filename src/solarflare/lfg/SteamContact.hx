package solarflare.lfg;

/** Contact metadata is never treated as a recruiting target or executable URI. */
class SteamContact {
    static var digits=~/^[0-9]{1,20}$/;
    static var tag=~/\[(?:steam|steamid|steam id)[:\s]+([0-9]{1,20})\]/ig;
    static var plain=~/\b(?:steam|steamid|friend code)[:\s]+([0-9]{1,20})\b/i;
    public static function valid(value:String):Bool return value!=null&&digits.match(value);
    public static function extract(text:String):String return text==null?"":(tag.match(text)?tag.matched(1):(plain.match(text)?plain.matched(1):""));
    public static function hasTag(text:String):Bool return text!=null&&tag.match(text);
    public static function withoutTags(text:String):String return tag.replace(text,"");
    public static function detach(text:String):String return text==null?"":StringTools.trim(~/\s+/g.replace(withoutTags(text)," "));
    public static function attach(text:String,id:String,max:Int):String {
        if(!valid(id))return text;
        if(extract(text)==id)return text;
        var next=text+(text==""?"":" ")+"[Steam: "+id+"]";
        return next.length<=max?next:text;
    }
}
