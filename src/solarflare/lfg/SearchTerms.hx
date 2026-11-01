package solarflare.lfg;

/** All query terms may match different fields, regardless of word order. */
class SearchTerms {
    public static function parse(query:String):Array<String> {
        return [for(term in Parser.normalized(query).split(" ")) if(term.length>0) term];
    }
    public static function matches(values:Array<String>,terms:Array<String>):Bool {
        if(terms.length==0)return true;
        // Normalize separately: Parser.normalized bounds each input to 512 chars.
        // Joining first could discard class/name metadata or later aliases.
        var fields=[for(value in values) Parser.normalized(value)];
        for(term in terms){
            var found=false;
            for(field in fields)if(field.indexOf(term)>=0){found=true;break;}
            if(!found)return false;
        }
        return true;
    }
}
