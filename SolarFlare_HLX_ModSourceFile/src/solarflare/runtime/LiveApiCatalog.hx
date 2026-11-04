package solarflare.runtime;

/** Pinned identities and skill IDs for the on-demand live text exporter. */
class LiveApiCatalog {
    public var buildHash(default, null):String;
    public var cdbHash(default, null):String;
    public var version(default, null):String;
    public var skillIds(default, null):Array<String>;
    static var cached:LiveApiCatalog;

    function new() {}

    public static function load():LiveApiCatalog {
        if (cached != null) return cached;
        var text = haxe.Resource.getString("live-api-catalog");
        if (text == null) throw "Live API catalog is not packaged.";
        return cached = parse(text);
    }

    public static function parse(text:String):LiveApiCatalog {
        var raw:Dynamic = haxe.Json.parse(text);
        if (raw.schema != 1) throw "Unsupported live API catalog schema.";
        var out = new LiveApiCatalog();
        out.buildHash = raw.hlbootSha256;
        out.cdbHash = raw.cdbSha256;
        out.version = raw.version;
        var hash = ~/^[0-9a-fA-F]{64}$/;
        if (out.buildHash == null || !hash.match(out.buildHash)
            || out.cdbHash == null || !hash.match(out.cdbHash)
            || out.version == null || out.version == "") throw "Invalid live API catalog identity.";
        out.buildHash = out.buildHash.toLowerCase();
        out.cdbHash = out.cdbHash.toLowerCase();
        var ids:Array<Dynamic> = raw.skillIds;
        if (ids == null || ids.length == 0) throw "Live API catalog has no skills.";
        out.skillIds = [];
        var seen = new Map<String, Bool>();
        for (id in ids) {
            if (!Std.isOfType(id, String) || id == "" || seen.exists(id)) throw "Invalid live API skill ID.";
            seen.set(id, true);
            out.skillIds.push(id);
        }
        out.skillIds.sort(Reflect.compare);
        return out;
    }
}
