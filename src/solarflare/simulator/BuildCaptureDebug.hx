package solarflare.simulator;
import solarflare.simulator.BuildTypes;

/** Temporary, request-only capture evidence. No native references or idle polling. */
class BuildCaptureDebug {
    public static function write(b:BuildSnapshot):Void {
        var payload={build:b.buildHash,model:b.modelVersion,capturedAt:b.capturedAt,
            gear:[for(g in b.gear){id:g.id,name:g.name,slot:g.slot,itemLevel:g.itemLevel,affixFactor:g.affixFactor,primaryStats:g.primaryStats.copy(),skillIds:g.skillIds.copy(),
                contributions:[for(c in g.contributions){affix:c.affix,stat:c.stat,value:c.value,rawValue:c.rawValue,source:c.source,operation:c.operation,known:c.known}],notes:g.notes.copy()}],
            skills:[for(s in b.skills){id:s.id,rank:s.rank,slot:s.weaponSlot}],issues:b.issues.copy()};
        var path=solarflare.ui.ModPaths.child("logs/simulator");var name=Std.string(Date.now().getTime())+".json";
        sys.thread.Thread.create(function(){try{sys.FileSystem.createDirectory(path);sys.io.File.saveContent(path+"/capture-"+name,haxe.Json.stringify(payload,null,"  "));}catch(_:Dynamic){}});
    }
}
