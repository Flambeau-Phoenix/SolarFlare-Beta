package solarflare.simulator;

/** File hashing runs on a worker containing strings/bytes only; it never receives game objects. */
class BuildIdentity {
    public var hash(default,null):String="";
    public var message(default,null):String="";
    public var done(default,null):Bool=false;
    var started=false;
    var mailbox=new sys.thread.Deque<String>();
    var paths:Array<String>;
    public function new(paths:Array<String>=null) this.paths=paths;
    public function advance():Bool {
        if (done) return true;
        if (!started) {
            started=true;
            var candidates=paths!=null?paths.copy():[haxe.io.Path.join([Sys.getCwd(),"hlboot.dat"]),haxe.io.Path.join([haxe.io.Path.directory(Sys.programPath()),"hlboot.dat"])];
            var queue=mailbox;
            sys.thread.Thread.create(function() {
                try {
                    for (path in candidates) if (sys.FileSystem.exists(path) && !sys.FileSystem.isDirectory(path)) {
                        queue.add("sha256:"+haxe.crypto.Sha256.make(sys.io.File.getBytes(path)).toHex().toLowerCase()); return;
                    }
                    queue.add("error:Could not locate the running game's hlboot.dat.");
                } catch (e:Dynamic) { queue.add("error:Build verification failed: "+Std.string(e)); }
            });
        }
        var value=mailbox.pop(false);
        if (value==null) return false;
        done=true;
        if (StringTools.startsWith(value,"sha256:")) hash=value.substr(7); else message=value.substr(6);
        return true;
    }
}
