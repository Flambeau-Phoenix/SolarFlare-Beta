package solarflare.hemorrhage;

import solarflare.HealthCache;
import solarflare.hemorrhage.HemorrhageCache.HemorrhageInput;
import solarflare.runtime.RuntimeMetrics;
import solarflare.runtime.EventRing;
import solarflare.ui.FeatureProfiles;
import solarflare.ui.SettingsStore;

typedef HemorrhageSaved = {
	var id:String;
	var label:String;
	var choiceLabel:String;
	var metadata:String;
	var run:HemorrhageRun;
	var view:HemorrhageView;
}

/** Observe-owned coordinator; stores primitive context only. UI requests go through UiActionQueue. */
class HemorrhageService {
	public static var run(default,null) = new HemorrhageRun();
	public static var archive(default,null):HemorrhageArchive;
	public static var view(default,null) = new HemorrhageView(run);
	public static var saved(default,null):Array<HemorrhageSaved> = [];
	public static var selectedA(default,null):HemorrhageSaved;
	public static var selectedB(default,null):HemorrhageSaved;
	public static var countLabel:String = "0 / 50 saved tests";
	public static var comparison(default,null):Array<{label:String,a:String,b:String,delta:String,percent:String}> = [];
	public static var compareA:String = "";
	public static var compareB:String = "";
	public static var message:String = "Start a test after previous bleeds have expired.";
	public static var hudStatus:String = "Idle";
	public static var hudElapsed:String = "0 s";
	public static var hudCrit:String = "Crit —";
	public static var hudBleed:String = "Bleed DPS —";
	public static var hudShare:String = "Bleed share —";
	public static var contextReady:Bool = false;
	public static var now(default,null):Float = 0;
	static var shownCharacter:String = "";
	static var previousNotice:String = "";
	static var previousChance:Float = Math.NaN;
	static var ownerGen:Int = -1;
	static var ownerProfileGen:Int = -1;
	static var ownerProfile:String = "";
	static var savedId:String = "";
	static var lastView:Float = -1;
	static var refreshSaved:Bool = true;
	static var modBuild:String = HemorrhageBuild.stamp();
	static var gameBuild:String = "";
	public static inline function active():Bool return run.active();
	static function init():Void {
		if(archive!=null) return;
		archive = new HemorrhageArchive(haxe.io.Path.join([SettingsStore.modDir(),"hemorrhage-runs.json"]));
		archive.load();
		// Record the installed artifact's identity without hashing a large game file on a render frame.
		var game = haxe.io.Path.normalize(haxe.io.Path.join([SettingsStore.modDir(),"..","..","..","hlboot.dat"]));
		try { var s=sys.FileSystem.stat(game); gameBuild="hlboot.dat bytes="+s.size+" modified="+s.mtime.toString(); }
		catch(_:Dynamic) gameBuild="Installed hlboot.dat unavailable";
		gameBuild += "; timing reference corpus 5f288029b346";
	}
	public static function start(label:String,notes:String):Void {
		init();
		if(active()) { message="A test is already active."; return; }
		if(!contextReady || HealthCache.localHero==null || HealthCache.characterId=="") { message="Enter the world and wait for character identity before starting."; return; }
		if(archive.count(HealthCache.characterId)>=HemorrhageArchive.LIMIT) { message="50 saved tests reached. Delete a saved result before starting another."; return; }
		var now=haxe.Timer.stamp();
		run=new HemorrhageRun(); run.start(now,HealthCache.characterId,label,notes,Date.now().getTime(),RuntimeMetrics.eventDropped);
		run.modBuild=modBuild; run.gameBuild=gameBuild;
		ownerGen=HealthCache.identityGen; ownerProfileGen=FeatureProfiles.statusOwnerGen; ownerProfile=FeatureProfiles.activeProfile;
		run.stats(HemorrhageCache.criticalChance,HemorrhageCache.criticalRating);
		HemorrhageCache.clear(); savedId=""; previousNotice=""; message="Armed: waiting for your first damage event."; lastView=-1;
	}
	public static function finish():Void {
		run.finish(haxe.Timer.stamp()); message=run.state=="Idle" ? "Empty test discarded." : run.notice; lastView=-1;
	}
	public static function interrupt(reason:String):Void {
		if(!active()) return;
		run.tick(haxe.Timer.stamp(),RuntimeMetrics.eventDropped,false);
		run.interrupt(haxe.Timer.stamp(),reason);
		persistCompleted(); lastView=-1;
	}
	public static function beforeDrain(now:Float):Void {
		init(); contextReady=HealthCache.localHero!=null && HealthCache.characterId!="";
		HemorrhageService.now=now;
		if(shownCharacter!=HealthCache.characterId) { shownCharacter=HealthCache.characterId; refreshSaved=true; }
		if(active() && (!contextReady || ownerGen!=HealthCache.identityGen || run.character!=HealthCache.characterId)) interrupt("Character, world, or local hero changed");
		if(active() && (ownerProfile!=FeatureProfiles.activeProfile || ownerProfileGen!=FeatureProfiles.statusOwnerGen)) interrupt("Configuration profile changed");
	}
	public static function consume(hit:HemorrhageInput):Void {
		if(!active() || hit.identityGen!=ownerGen || HealthCache.identityGen!=ownerGen) return;
		if(run.consume(hit)) HemorrhageCache.consume(hit);
	}
	public static function afterDrain(now:Float, wanted:Bool = true):Void {
		if(archive==null) return;
		run.stats(HemorrhageCache.criticalChance,HemorrhageCache.criticalRating);
		run.tick(now,RuntimeMetrics.eventDropped,EventRing.depth()==0);
		persistCompleted();
		var chance=HemorrhageCache.criticalChance;
		var statsChanged=chance!=previousChance && !(Math.isNaN(chance) && Math.isNaN(previousChance));
		if(lastView<0 || ((active() || (wanted && statsChanged)) && now-lastView>=0.1)) {
			previousChance=chance;
			lastView=now; view=new HemorrhageView(run);
			hudStatus=(run.state:String); hudElapsed=HemorrhageView.decimal(run.elapsed)+" s";
			if(run.state=="Draining") hudStatus+=" ("+HemorrhageView.decimal(Math.max(0,run.deadline-now))+" s left)";
			hudCrit="Crit "+HemorrhageView.percent(HemorrhageCache.criticalChance);
			hudBleed="Bleed DPS "+HemorrhageView.number(run.bleedDps());
			hudShare="Bleed share "+HemorrhageView.percent(run.metrics.damage>0 ? run.metrics.bleed()/run.metrics.damage : Math.NaN);
			if(run.notice!="" && run.notice!=previousNotice) { message=run.notice; previousNotice=run.notice; }
		}
		if(refreshSaved) rebuildSaved();
	}
	static function persistCompleted():Void {
		if(archive==null || savedId==run.id || run.id=="" || (run.state!="Complete" && run.state!="Interrupted")) return;
		if(archive.add(run)) { savedId=run.id; archive.save(); refreshSaved=true; lastView=-1; }
		else message="Result remains in memory: delete a saved test and Retry save.";
	}
	public static function retrySave():Void { init(); persistCompleted(); archive.save(); refreshSaved=true; }
	public static function deleteRun(id:String):Void { if(archive==null) return; archive.remove(id); archive.save(); refreshSaved=true; }
	public static function refreshComparison():Void { refreshSaved=true; }
	static function rebuildSaved():Void {
		refreshSaved=false; saved=[]; comparison=[]; selectedA=selectedB=null;
		var a:HemorrhageView=null; var b:HemorrhageView=null;
		var who=HealthCache.characterId;
		for(r in archive.runs) if(r.character==who) {
			var v=new HemorrhageView(r);
			var date=Date.fromTime(r.wallMs).toString();
			var label=(r.build=="" ? "Unnamed test" : r.build)+" / "+date;
			var item:HemorrhageSaved={id:r.id,label:label,choiceLabel:label+"##hem_saved_"+r.id,metadata:r.modBuild+" | "+r.gameBuild,run:r,view:v};
			saved.unshift(item);
			if(r.id==compareA) selectedA=item; if(r.id==compareB) selectedB=item;
			if(r.id==compareA) a=v; if(r.id==compareB) b=v;
		}
		countLabel=Std.string(saved.length)+" / 50 saved tests";
		if(a!=null && b!=null) for(i in 0...a.rows.length) {
			var left=a.rows[i]; var right=b.rows[i];
			var difference=HemorrhageView.delta(left.raw,right.raw);
			if(left.ratio) {
				difference=HemorrhageView.delta(left.raw*100,right.raw*100);
				if(difference!="—") difference+=" pp";
			}
			comparison.push({label:left.label,a:left.value,b:right.value,delta:difference,percent:HemorrhageView.delta(left.raw,right.raw,true)});
		}
	}
	public static function exportSelected():Void {
		if(archive==null) return;
		var selected=[];
		for(r in archive.runs) if(r.character==HealthCache.characterId && (r.id==compareA || r.id==compareB)) selected.push(r);
		if(selected.length==0) { message="Select saved test A or B before exporting."; return; }
		try {
			var path=haxe.io.Path.join([SettingsStore.modDir(),"hemorrhage-export-"+Std.string(Date.now().getTime())+".csv"]);
			sys.io.File.saveContent(path,HemorrhageArchive.csv(selected)); message="Exported to "+path;
		} catch(e:Dynamic) message="CSV export failed: "+Std.string(e)+". Retry Export CSV; saved results are retained.";
	}
}
