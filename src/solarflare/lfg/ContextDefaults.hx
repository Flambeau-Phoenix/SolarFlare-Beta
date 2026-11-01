package solarflare.lfg;

/** User-requested recognition context. These words never exclude a message. */
class ContextDefaults {
    public static function additions():Array<String> return [
        "heroic","herc","hc","bonus","farm","speed","chill","exp","carry",
        "quest","daily","weekly","alt","mains","fresh","cleared","skip",
        "silent","voice","chillrun","group","quick","loot","boss","more",
        "crabgantua's","gorge","lady","bee's","palace","ratsar's","lair",
        "trunk","hivetree","mine","estrone","lost","city","mayda",
        "honeyzabeth's","hivetrunk","cheese","station","ruins","gorgon's",
        "hollow","abyss","new","atlaan","chakram's","chapel","crimson",
        "barracks","golcano","munster","chuck","nepsilon","nightking",
        "maat","demon","nightqueen","shaarlize","te'ror","robin","hoof",
        "sponge","blob"
    ];

    public static function merge(values:Array<String>):Array<String> {
        var result=values.copy();
        for(word in additions()){
            var found=false;
            for(existing in result)if(RecognitionIndex.RecognitionWord.fold(existing)==word){found=true;break;}
            if(!found&&result.length<256)result.push(word);
        }
        return result;
    }
}
