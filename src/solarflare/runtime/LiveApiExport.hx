package solarflare.runtime;

import solarflare.ui.ModPaths;

/** On-demand native text collection. Only owned primitive records cross the writer thread boundary. */
class LiveApiExport {
    public static var status(default,null)="Gather rendered skill text and session cast-time evidence for the API tools.";
    public static var output(default,null)="";
    public static var busy(default,null)=false;
    static var requested=false;static var epoch=-1;static var cursor=0;static var count=0;static var errors=0;
    static var identity=new GameBuildIdentity();
    static var catalog:LiveApiCatalog;
    static var ids:Array<String>=[];
    static var rendered:Dynamic;
    static var mailbox:sys.thread.Deque<String>;
    static var pendingPath="";static var finalPath="";static var capturedAt="";
    static var character="";
    public static function request():Void { if(!busy){requested=true;status="Gather queued...";} }
    public static function observe(generation:Int,app:GameApp):Void {
        if(!requested&&!busy)return;
        try {
            var current=app.me!=null&&app.connectionInfo!=null&&!app.get_isLoading()?app.me.uid+"|"+haxe.Int64.toStr(app.connectionInfo.heroID):"";
            if(requested){
                if(current==""){requested=false;status="Enter the world with a character before gathering.";return;}
                requested=false;busy=true;epoch=generation;cursor=count=errors=0;ids=[];rendered={};mailbox=null;output="";
                character=current;
                if(catalog==null)catalog=LiveApiCatalog.load();
                ids=catalog.skillIds.copy();
                capturedAt=Date.now().toString();status="Checking the running build...";
            }
            if(epoch!=generation||character!=current){busy=false;rendered=null;ids=[];status="Gather cancelled because the character changed.";return;}
            if(mailbox!=null){
                var message=mailbox.pop(false);if(message==null)return;
                busy=false;mailbox=null;
                if(message!="ok"){status="Export failed: "+message;return;}
                sys.FileSystem.rename(pendingPath,finalPath);output=finalPath;
                status="Saved live API files locally. Copy the skilltext folder into API_Files; numbers reflect this hero.";return;
            }
            if(!identity.advance())return;
            if(identity.hash!=catalog.buildHash){busy=false;status="Build mismatch: refresh SolarFlare's API assets before gathering.";return;}
            var raw=solarflare.HealthCache.localHero;
            if(!solarflare.HealthCache.isHeroObject(raw)||(cast app.hero:Dynamic)!=raw){busy=false;status="Enter the world with a character before gathering.";return;}
            var hero:ent.Hero=raw;
            var start=haxe.Timer.stamp();var worked=0;
            while(cursor<ids.length&&worked++<4&&haxe.Timer.stamp()-start<0.002){
                var id=ids[cursor++];
                try {
                    // Use the actual CDB record, not HSkill.getSkillRef (which is only the inheritance map).
                    if(!NativeTypes.is(Data.skill,"cdb.IndexId"))throw "Skill index is unavailable";
                    var inf:Dynamic=Data.skill.byId.get(id);
                    if(inf==null)throw "Missing current skill record";
                    var data={heroic:false,inf:inf,masteries:null,maxRank:null,rank:1};
                    var name=HText.skill(cast data,ETextKind.Name,hero,null,null,null);
                    var markup=HText.skill(cast data,ETextKind.Desc,hero,null,null,null);
                    name=owned(name);markup=owned(markup);
                    var description=plain(markup);if(description!="")count++;
                    Reflect.setField(rendered,id,{name:name,description:description,description_markup:markup,localized:name!=""&&name.indexOf("[")<0,rendered_with_unit:true});
                }catch(_:Dynamic){errors++;Reflect.setField(rendered,id,{name:null,description:"",description_markup:"",localized:false,rendered_with_unit:false,error:"Native text renderer could not evaluate this skill."});}
            }
            status="Gathering skill text: "+cursor+" / "+ids.length;
            if(cursor<ids.length)return;
            var meta={schema:"farever.skill_text.v1",built_for:identity.hash.substr(0,12),hlboot_sha256:identity.hash,cdb_sha256:catalog.cdbHash,
                rows:ids.length,with_description:count,errors:errors,session:capturedAt,mod_build:catalog.version,rel_build:"live_export",
                viewer:"the local hero during collection: rank-1 damage/heal/shield numbers use that hero's current effective stats",captured_at:capturedAt,capture_finished_at:Date.now().toString(),rank:1};
            var records=rendered;rendered=null;
            var casts=solarflare.castbar.LearnedCastTimes.exportJson();
            var root=ModPaths.child("exports/api-live");if(!sys.FileSystem.exists(root))sys.FileSystem.createDirectory(root);
            var stamp=Std.string(Date.now().getTime())+"-"+epoch;
            finalPath=haxe.io.Path.join([root,stamp]);pendingPath=finalPath+".pending";
            var path=pendingPath;var queue=new sys.thread.Deque<String>();mailbox=queue;
            sys.thread.Thread.create(function(){
                try {
                    sys.FileSystem.createDirectory(path+"/skilltext");
                    sys.io.File.saveContent(path+"/skilltext/meta.json",haxe.Json.stringify(meta,null,"  ")+"\n");
                    sys.io.File.saveContent(path+"/skilltext/rendered.json",haxe.Json.stringify(records,null,"  ")+"\n");
                    sys.io.File.saveContent(path+"/skill-cast-times.json",casts);
                    queue.add("ok");
                }catch(e:Dynamic){queue.add(Std.string(e));}
            });status="Writing live API bundle...";
        }catch(e:Dynamic){busy=false;status="Gather failed: "+Std.string(e);}
    }
    static function owned(value:String):String return value==null?"":solarflare.ui.ByteUtil.materialize(value);
    public static function plain(value:String):String {
        var s=~/<[^>]*>/g.replace(value==null?"":value,"");
        for(pair in [["&lt;","<"],["&gt;",">"],["&quot;","\""],["&#39;","'"],["&amp;","&"]])s=StringTools.replace(s,pair[0],pair[1]);
        return s;
    }
}
