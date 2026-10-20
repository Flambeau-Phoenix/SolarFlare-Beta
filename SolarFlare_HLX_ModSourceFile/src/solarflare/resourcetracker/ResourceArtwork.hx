package solarflare.resourcetracker;

import imgui.ImGui;
import solarflare.ui.CustomImages;
import solarflare.ui.ConfigPanel;
import solarflare.ui.GameIcons;
import solarflare.ui.SettingsStore;
import solarflare.ui.UiLayout;
import solarflare.HealthCache;
import solarflare.combo.Combo.ComboPointsCache;
import solarflare.chaincast.Chaincast.ChaincastCache;
import solarflare.conduit.Conduit.ConduitCache;

/** Reuses the custom image library and GameIcons' deferred, cache-only draw API. */
class ResourceArtwork {
	public static var active(default,null):ResourceArtwork;
	public static final IDS=["health","rage","mana","prayers","combo","attack","target","castbar","chaincast","conduit","dash","hemorrhage"];
	static final DIRECTIONS=["Left to right","Right to left","Bottom to top","Top to bottom"];
	var skins:Map<String,ResourceSkin>=new Map();
	var folderBuf=new hl.Bytes(1024);
	var importBuf=new hl.Bytes(2048);
	var folderGeneration:Int=-1;
	var message:String="";
	public function new() { for(id in IDS) skins.set(id,new ResourceSkin()); solarflare.ui.ByteUtil.clearBytes(folderBuf,1024); solarflare.ui.ByteUtil.clearBytes(importBuf,2048); active=this; }
	public function get(id:String):ResourceSkin return skins.get(id);
	public static function forWindow(id:String):ResourceSkin {
		if(active==null) return null;
		var key=switch(id) {
			case "SolarFlare HP": "health"; case "SolarFlare Rage": "rage"; case "SolarFlare Mana", "SolarFlare Spark": "mana";
			case "SolarFlare Prayers": "prayers"; case "SolarFlare Combo": "combo"; case "SolarFlare Attack Combo": "attack";
			case "SolarFlare Target": "target"; case "SolarFlare Player Cast": "castbar"; case "SolarFlare Chaincast": "chaincast";
			case "SolarFlare Conduits": "conduit"; case "SolarFlare Dash": "dash"; default: "";
		};
		return active.get(key);
	}
	public function dump():Dynamic { var out:Dynamic={}; for(id in IDS) Reflect.setField(out,id,get(id).dump()); return out; }
	public function apply(d:Dynamic):Void { for(id in IDS) get(id).apply(d==null ? null : Reflect.field(d,id)); }
	function value(id:String,known:Bool,n:Float):Void get(id).progress=known ? ResourceArtGeometry.fraction(n) : 0;
	public function observe(c:ConfigPanel):Void {
		value("health",HealthCache.valid,HealthCache.ratio()); value("rage",HealthCache.rageValid,HealthCache.rageRatio());
		value("mana",HealthCache.resourceValid(),HealthCache.resourceRatio());
		value("prayers",solarflare.PrayerCache.active,solarflare.PrayerCache.chargedCount/3);
		value("combo",ComboPointsCache.valid,ComboPointsCache.max>0 ? ComboPointsCache.current/ComboPointsCache.max : 0);
		value("chaincast",ChaincastCache.valid,ChaincastCache.ready ? 1 : ChaincastCache.max>0 ? ChaincastCache.current/ChaincastCache.max : 0);
		value("conduit",ConduitCache.valid,ConduitCache.slotCount>0 ? ConduitCache.filledCount/ConduitCache.slotCount : 0);
		value("attack",solarflare.attackcombo.AttackComboCache.known,solarflare.attackcombo.AttackComboCache.comboLength>0 ? solarflare.attackcombo.AttackComboCache.step/solarflare.attackcombo.AttackComboCache.comboLength : 0);
		var target=solarflare.combatlog.CombatLogCache.currentTargetSnap(); value("target",target.valid && target.healthValid,target.ratio);
		var castSnap=solarflare.castbar.CastCache.playerSnap(); value("castbar",castSnap.active,castSnap.progress);
		var dash=solarflare.aura.AuraMovementObserver.state; value("dash",dash.known,dash.left>0 ? dash.remaining : dash.charges>0 ? 1 : 0);
		var metrics=solarflare.hemorrhage.HemorrhageService.run.metrics;
		value("hemorrhage",metrics.damage>0,metrics.damage>0 ? metrics.bleed()/metrics.damage : 0);
	}
	public function drawEditor(id:String):Void {
		var s=get(id); if(s==null) return;
		if(!solarflare.ui.UiChrome.groupHeader("Custom artwork##rt_art_"+id)) return;
		if(folderGeneration!=CustomImages.generation) { solarflare.ui.ByteUtil.fillBuf(folderBuf,1024,CustomImages.folder); folderGeneration=CustomImages.generation; }
		UiLayout.propertyGrid("##rt_art_props_"+id,function() {
			UiLayout.propertyRow("Artwork",function() { if(ImGui.checkbox("Use custom images##rt_art_enabled_"+id,s.enabled)) SettingsStore.markDirty(); });
			UiLayout.propertyRow("Background",function() { s.background=pick("##rt_art_bg_"+id,s.background); });
			UiLayout.propertyRow("Resource fill",function() { s.fill=pick("##rt_art_fill_"+id,s.fill); });
			UiLayout.propertyRow("Frame",function() { s.frame=pick("##rt_art_frame_"+id,s.frame); });
			UiLayout.propertyRow("Fill direction",function() {
				if(ImGui.beginCombo("##rt_art_direction_"+id,DIRECTIONS[s.direction.get()])) {
					for(i in 0...DIRECTIONS.length) if(ImGui.selectable(DIRECTIONS[i],s.direction.get()==i)) { s.direction.set(i); SettingsStore.markDirty(); }
					ImGui.endCombo();
				}
			});
			UiLayout.propertyRow("Fill inset",function() { UiLayout.inlinePair("##rt_art_insets_"+id,function(_) { if(ImGui.sliderFloat("X##rt_art_ix_"+id,s.insetX,0,200,"%.0f px")) SettingsStore.markDirty(); },function(_) { if(ImGui.sliderFloat("Y##rt_art_iy_"+id,s.insetY,0,200,"%.0f px")) SettingsStore.markDirty(); }); });
			UiLayout.propertyRow("Opacity",function() { if(ImGui.sliderFloat("##rt_art_opacity_"+id,s.opacity,0,1,"%.2f")) SettingsStore.markDirty(); });
			UiLayout.propertyRow("Built-in display",function() { if(ImGui.checkbox("Keep built-in content##rt_art_content_"+id,s.keepContent)) SettingsStore.markDirty(); });
			UiLayout.propertyRow("Images folder",function() {
				ImGui.setNextItemWidth(Math.max(60,ImGui.getContentRegionAvail().x-90));
				var enter=ImGui.inputTextWithHint("##rt_art_folder_path_"+id,CustomImages.displayDir,folderBuf,1024,imgui.Enums.ImGuiInputTextFlags.EnterReturnsTrue);
				ImGui.sameLine(0,4);
				if(solarflare.ui.UiChrome.ghostButton("Use folder##rt_art_use_folder_"+id,ImGui.vec2(86,28)) || enter) {
					var path=solarflare.ui.ByteUtil.readBytes(folderBuf,1024);
					solarflare.ui.UiActionQueue.custom(function() { try { CustomImages.useFolder(path); SettingsStore.markDirty(); message="Images folder updated."; } catch(e:Dynamic) message=Std.string(e); });
				}
			},"Full folder path. Leave blank to use custom_images. Shared with the Aura image library.");
			UiLayout.propertyRow("Import image",function() {
				ImGui.setNextItemWidth(Math.max(60,ImGui.getContentRegionAvail().x-90));
				var enter=ImGui.inputTextWithHint("##rt_art_import_path_"+id,"Paste an image file path",importBuf,2048,imgui.Enums.ImGuiInputTextFlags.EnterReturnsTrue);
				ImGui.sameLine(0,4);
				if(solarflare.ui.UiChrome.ghostButton("Import##rt_art_import_"+id,ImGui.vec2(86,28)) || enter) {
					var path=solarflare.ui.ByteUtil.readBytes(importBuf,2048);
					solarflare.ui.UiActionQueue.custom(function() { var report=CustomImages.importMany(path); message=report.imported.length+" image(s) imported. "+report.errors.join(" "); });
				}
			});
		});
		if(solarflare.ui.UiChrome.ghostButton("Refresh images##rt_art_refresh_"+id)) CustomImages.requestRefresh();
		ImGui.sameLine(); if(solarflare.ui.UiChrome.ghostButton("Copy folder path##rt_art_folder_"+id)) solarflare.ui.UiActionQueue.copyText(CustomImages.displayDir,"Images folder path copied.");
		ImGui.textWrapped("Use transparent PNGs from custom_images or your selected images folder. Layers stretch to the resource's size; the fill is cropped to its current value. Dash follows the next-charge fuse; Hemorrhage follows bleed share. Missing images keep the built-in display available.");
		ImGui.textDisabled(CustomImages.status);
		if(message.length>0) ImGui.textWrapped(message);
		if(s.enabled.get()) for(k in [s.background,s.fill,s.frame]) if(k.length>0 && GameIcons.get(k)==0) ImGui.textDisabled("Image unavailable: "+k);
	}
	static function pick(id:String,current:String):String {
		var next=current;
		if(ImGui.beginCombo(id,current.length>0 ? current : "None")) {
			if(ImGui.selectable("None##rt_art_none",current.length==0)) next="";
			for(stem in CustomImages.names()) { var key=CustomImages.key(stem); if(ImGui.selectable(stem,current==key)) next=key; }
			ImGui.endCombo();
		}
		if(next!=current) SettingsStore.markDirty(); return next;
	}
}
