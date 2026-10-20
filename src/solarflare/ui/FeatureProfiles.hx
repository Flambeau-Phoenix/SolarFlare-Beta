package solarflare.ui;

import imgui.ImGui;
import solarflare.HealthCache;
import solarflare.ui.ByteUtil;

/**
 * Observation-owned coordinator for a complete HUD profile and its geometry-only layout bank.
 * Native identity discovery stays in HealthHooks; the persistence policy is pure ProfileBank.
 */
class FeatureProfiles {
	public static inline var DEFAULT_KEY:String = "Default";

	public static var activeProfile:String="";
 public static var statusOwnerGen(get,never):Int;
 static function get_statusOwnerGen():Int return transition.generation;
 public static var transition(default,null)=new ProfileTransition();
 public static var bank:ProfileBank;
 public static var ready(get,never):Bool;
 static function get_ready():Bool return transition.ready;
 static var factory:Dynamic;
 static var owner:String="";
 static var nameBuf:hl.Bytes;
 public static var activeKey(get,never):String;
 static function get_activeKey():String return activeProfile;
 public static function activeName(domain:String=""):String return label(activeProfile);
 static function label(id:String):String {
  var p=bank==null || id==null ? null : bank.profiles.get(id); return p==null ? "Character unavailable" : p.name;
 }
 public static function captureFactory(cfg:ConfigPanel):Void {
  if(factory==null) factory=ProfileBank.copy(captureAll(cfg));
 }
 public static function init(cfg:ConfigPanel):Void {
  ensureBuffer(); captureFactory(cfg); if(bank==null) bank=new ProfileBank(factory);
 }
 public static function load(cfg:ConfigPanel,data:Dynamic):Void {
  init(cfg); bank=new ProfileBank(factory); owner=""; transition=new ProfileTransition(transition.generation+1);
  var universal=Reflect.field(data,"universalProfiles");
  // Retain domain banks without mixing them with the outgoing/live configuration.
  if(universal==null) {
   var legacy=Reflect.field(data,"featureProfiles");
   if(legacy!=null && legacy.profiles!=null) universal=legacy;
   else if(legacy!=null && legacy.geaux!=null && legacy.geaux.profiles!=null) {
    var snapshots:Dynamic={};
    for(name in Reflect.fields(legacy.geaux.profiles)) Reflect.setField(snapshots,name,{geaux:ProfileBank.copy(Reflect.field(legacy.geaux.profiles,name))});
    universal={active:legacy.geaux.active,profiles:snapshots};
   }
  }
  var saved=captureAll(cfg);
  // Pure migration shares the same policy used by the preservation replay tests.
  bank.load(universal,saved,Reflect.field(data,"extraBarsCharacters"),data,HudChrome.viewportWidth,HudChrome.viewportHeight);
  activeProfile=bank.active;
 }
 public static function summary():String {
  if(bank==null) return "no bank";
  var d=[for(h in bank.defaults.keys()) h+"="+bank.defaults.get(h)];
  return "profiles="+bank.order.length+" owner="+owner+" active="+activeProfile+" ready="+ready+" gen="+statusOwnerGen+" defaults{"+d.join(",")+"}";
 }
 public static function storeCurrent(cfg:ConfigPanel,domain:String=""):Void {
  if(cfg!=null && ready && owner==currentCharacterUid()) bank.store(owner,captureAll(cfg));
 }
 public static function storeAll(cfg:ConfigPanel):Void storeCurrent(cfg);
 public static function dump():Dynamic return bank.dump();
 public static function migrateCastBarVisible(cfg:ConfigPanel):Void {
  if(cfg!=null) cfg.castBar.hidden.set(false);
 }

	/**
	 * Profile Strip shared by the hub and every builder: selector, Save, and a More menu holding
	 * New / Copy / Delete and character assignment. A one-line status chip replaces the old
	 * Character Default table and its full-width action.
	 */
	public static function drawToolbar(cfg:ConfigPanel, domain:String = "", id:String = "main"):Void {
		drawStrip(cfg, id, false);
	}

	/** Same strip for builder title rows; fixed-width selector, no chip line. */
	public static function drawInlineBar(cfg:ConfigPanel, id:String = "ab"):Void {
		drawStrip(cfg, id, true);
	}

	/** Set from the More menu, consumed outside the popup scope so the modal's ID stack matches. */
	static var openNewFor:String = "";
 static var modalGeneration:Int=-1;

	static function drawStrip(cfg:ConfigPanel, id:String, compact:Bool):Void {
		if (cfg == null) return;
		ensureBuffer();
		var rowH:Single = 26;
		var gap:Single = 6;
		var saveW:Single = 56;
		var moreW:Single = 60;
		var uid = currentCharacterUid();
		var assigned = uid.length > 0 ? bank.defaults.get(uid) : null;
		var follows = assigned != null && assigned == activeProfile;
		var stripWidth = ImGui.getContentRegionAvail().x;
		var paired = stripWidth >= 640;

		ImGui.textDisabled("Profile");
		ImGui.sameLine(0, 8);
		var comboW:Single = paired ? (stripWidth - 410) / 2 : stripWidth - 190;
		if (comboW > 210) comboW = 210;
		if (comboW < 80) comboW = 80;
		ImGui.setNextItemWidth(comboW);
		if (ImGui.beginCombo("##fp_select_" + id, label(activeProfile))) {
			for (key in bank.order) {
				var p=bank.profiles.get(key);
				var label = p.name + (p.ownerHeroId=="" ? "  (retained setup; copy)" : p.ownerHeroId!=uid ? "  (copy from hero "+p.ownerHeroId+")" : key == assigned ? "  (character default)" : "");
				if (ImGui.selectable(label + "##fp_opt_" + id + "_" + key, key == activeProfile)) {
					if (key != activeProfile)
						{ var chosen=key; UiActionQueue.custom(function() switchTo(cfg,chosen)); }
				}
			}
			ImGui.endCombo();
		}
		ImGui.sameLine(0, gap);
		if (UiChrome.ghostButton("Save##fp_save_" + id, ImGui.vec2(saveW, rowH)))
			UiActionQueue.custom(function() save(cfg));
		ImGui.sameLine(0, gap);
		if (UiChrome.ghostButton("More##fp_more_" + id, ImGui.vec2(moreW, rowH)))
			ImGui.openPopup("##fp_more_pop_" + id);
		drawMoreMenu(cfg, id, uid, follows);
		if (paired) ImGui.sameLine(0, 18);
		cfg.uiLayouts.drawToolbar(cfg, id, comboW);
		if (!compact) {
   ImGui.textDisabled(ready ? currentCharacterLabel()+" | Active: "+label(activeProfile)+" | Default: "+label(assigned)+" | Layout: "+cfg.uiLayouts.bank.active : HealthCache.identityReason+". Character HUD and saving suspended.");

		}
		if (openNewFor == id) {
			openNewFor = "";
			ByteUtil.clearBytes(nameBuf, 49);
   modalGeneration=statusOwnerGen;
			ImGui.openPopup("New Universal Profile##fp_new_popup_" + id);
		}
		drawNewProfileModal(cfg, id);
	}

	static function drawMoreMenu(cfg:ConfigPanel, id:String, uid:String, follows:Bool):Void {
		if (!ImGui.beginPopup("##fp_more_pop_" + id))
			return;
		try {
			if (ImGui.menuItem("New profile...##fp_new_" + id)) {
				openNewFor = id;
				ImGui.closeCurrentPopup();
			}
			if (ImGui.menuItem("Copy this profile##fp_copy_" + id))
				UiActionQueue.custom(function() duplicateCurrent(cfg));
			ImGui.beginDisabled(!ready || bank.profiles.get(activeProfile)==null || bank.profiles.get(activeProfile).ownerHeroId!=uid);
			var deleteClicked = ImGui.menuItem("Delete this profile##fp_del_" + id);
			ImGui.endDisabled();
			if (deleteClicked)
				{ var chosen=activeProfile; UiActionQueue.custom(function() delete(cfg,chosen)); }
			ImGui.separator();
			if (uid.length == 0) {
				ImGui.textDisabled("Character unavailable");
			} else {
				if (!follows && ImGui.menuItem("Set as character default##fp_assign_" + id))
					UiActionQueue.custom(function() assignCurrentCharacter(cfg));
    if(ImGui.menuItem("Reset character default##fp_unassign_"+id)) UiActionQueue.custom(function() unassignCurrentCharacter(cfg));
			}
		} catch (e:Dynamic) {
			ImGui.endPopup();
			throw e;
		}
		ImGui.endPopup();
	}

	static function drawNewProfileModal(cfg:ConfigPanel, id:String):Void {
		if (!ImGui.beginPopupModal("New Universal Profile##fp_new_popup_" + id, null, imgui.Enums.ImGuiWindowFlags.AlwaysAutoResize))
			return;
  if(!ready || modalGeneration!=statusOwnerGen) { ImGui.closeCurrentPopup(); ImGui.endPopup(); return; }
		try {
			UiChrome.heading("New Profile", 1.15);
			ImGui.spacing();
			ImGui.text("Enter profile name:");
			ImGui.inputText("##fp_name_" + id, nameBuf, 49);
			ImGui.spacing();
			UiLayout.inlinePair("##fp_modal_btns_" + id, function(w:Single) {
				if (UiChrome.accentButton("Create##fp_create_" + id, ImGui.vec2(w, 28))) {
					var requested = ByteUtil.readBytes(nameBuf, 49);
					if(normalizeName(requested).length>0 && ready) { UiActionQueue.custom(function() create(cfg,requested)); ImGui.closeCurrentPopup(); }
				}
			}, function(w:Single) {
				if (UiChrome.ghostButton("Cancel##fp_cancel_" + id, ImGui.vec2(w, 28)))
					ImGui.closeCurrentPopup();
			}, 8);
		} catch (e:Dynamic) {
			ImGui.endPopup();
			throw e;
		}
		ImGui.endPopup();
	}

 public static function save(cfg:ConfigPanel):Void {
  if(!ready) return; storeCurrent(cfg); SettingsStore.markDirty(); SettingsStore.saveNow();
 }
 public static function switchTo(cfg:ConfigPanel,key:String,automatic:Bool=false):Void {
  if(!ready || cfg==null) return;
  storeCurrent(cfg); ProfileTrace.note("profile","SELECT requested="+describe(key)+" hero="+owner); activeProfile=bank.select(owner,key); applyUniversal(cfg,activeProfile); SettingsStore.markDirty();
 }
 /** Identity is sampled before any configuration queue or module observer can run. */
 public static function observeCharacter(cfg:ConfigPanel):Void {
  var id=currentCharacterUid();
  var confirmed=id!="" && HealthCache.localHero!=null && HealthCache.identityConfirmed;
  if(!transition.begin(id,confirmed,HealthCache.statusOwnerGen,function(outgoing) bank.store(outgoing,captureAll(cfg)),function() { cfg.clearTransientState(); ImageDrop.disarm(); })) return;
  owner=id; activeProfile=bank.login(id);
  ProfileTrace.note("profile","LOGIN hero="+id+" -> "+describe(activeProfile)+" (default="+describe(bank.defaults.get(id))+")");
  applyUniversal(cfg,activeProfile); SettingsStore.markDirty();
 }
 public static function assignCurrentCharacter(cfg:ConfigPanel):Void {
  if(!ready) return; bank.setDefault(owner); ProfileTrace.note("profile","SET DEFAULT hero="+owner+" -> "+describe(bank.active)); SettingsStore.markDirty();
 }
 public static function unassignCurrentCharacter(cfg:ConfigPanel):Void {
  if(!ready) return; var reset=bank.resetDefault(owner); ProfileTrace.note("profile","RESET DEFAULT hero="+owner+" -> "+describe(reset)); SettingsStore.markDirty();
 }
 public static function create(cfg:ConfigPanel,requested:String):Bool {
  if(!ready || normalizeName(requested)=="") return false;
  storeCurrent(cfg); activeProfile=bank.create(owner,normalizeName(requested)); bank.active=activeProfile;
  applyUniversal(cfg,activeProfile); SettingsStore.markDirty(); return true;
 }
 public static function duplicateCurrent(cfg:ConfigPanel):Void {
  if(!ready) return; storeCurrent(cfg);
  activeProfile=bank.create(owner,label(activeProfile)+" (Copy)",bank.profiles.get(activeProfile).snapshot); bank.active=activeProfile;
  applyUniversal(cfg,activeProfile); SettingsStore.markDirty();
 }
 public static function delete(cfg:ConfigPanel,key:String):Void {
  if(!ready) return; activeProfile=bank.remove(owner,key); applyUniversal(cfg,activeProfile); SettingsStore.markDirty();
 }

	static function captureAll(cfg:ConfigPanel):Dynamic {
		if (cfg == null) return {};
		return {
			geaux: {layout: SettingsStore.geauxDump(cfg.geaux)},
			barter: cfg.barter != null ? cfg.barter.dump() : {},
			statusBoard: cfg.statusBoard != null ? cfg.statusBoard.dump() : {},
			stacks: cfg.stacks != null ? cfg.stacks.dump() : {},
			auras: {config: SettingsStore.aurasDump(cfg.auras)},
			resources: captureResources(cfg),
			uiLayouts: cfg.uiLayouts.dumpCurrent(cfg),
			theme: SettingsStore.currentTheme(),
   extraBars:cfg.extraBarsPrototype.model.dump(),extraBarsPlacement:cfg.extraBarsPrototype.dumpPlacement(),
   auxiliary:SettingsStore.captureProfileAuxiliary(cfg)
		};
	}

	static function captureResources(cfg:ConfigPanel):Dynamic {
		return {
			vitals: SettingsStore.vitalsDump(cfg.vitals),
			resourceTracker:SettingsStore.resourceTrackerDump(cfg),
			combo: SettingsStore.comboDump(cfg.combo),
			attackCombo: SettingsStore.attackComboDump(cfg.attackCombo),
			target: SettingsStore.targetDump(cfg.target),
			castBar: SettingsStore.castBarDump(cfg.castBar),
			chaincast: SettingsStore.chaincastDump(cfg.chaincast),
			conduit: SettingsStore.conduitDump(cfg.conduit),
			hemorrhage: SettingsStore.hemorrhageDump(cfg.hemorrhage)
		};
	}

	static function describe(id:String):String {
  var p=bank==null || id==null ? null : bank.profiles.get(id);
  return p==null ? "none" : id+"\""+p.name+"\" owner="+p.ownerHeroId+(p.sourceId!="" ? " copyOf="+p.sourceId : "");
 }

	static function applyUniversal(cfg:ConfigPanel, key:String):Void {
		ProfileTrace.note("profile","APPLY "+describe(key)+" snapshotKeys="+(bank.profiles.get(key)==null ? "MISSING" : Reflect.fields(bank.profiles.get(key).snapshot).join(",")));
		solarflare.hemorrhage.HemorrhageService.interrupt("Configuration profile changed");
		transition.restoring();
		if (cfg == null) return;
  cfg.clearTransientState(); cfg.extraBarsPrototype.clearTransientState();
  openNewFor=""; modalGeneration=-1; ImageDrop.disarm();
  if(cfg.geauxBuilder!=null) cfg.geauxBuilder.resetProfileState();
  if(cfg.auraBuilder!=null) cfg.auraBuilder.resetProfileState();
		var snap = bank.normalized(key);
		if (snap == null) return;
  // Reset schema defaults first, including fields omitted inside collection entries.
  applySnapshot(cfg,ProfileBank.copy(factory));
  applySnapshot(cfg,snap);
  transition.complete();
 }
 static function applySnapshot(cfg:ConfigPanel,snap:Dynamic):Void {
		if (cfg.barter != null) { cfg.barter.clearTransientState(); cfg.barter.builder.history.clear(); }

		// 1. Geaux Layout
		var geauxSnap = Reflect.field(snap, "geaux");
		if (geauxSnap != null) {
			SettingsStore.applyGeauxProfile(cfg.geaux, Reflect.field(geauxSnap, "layout"));
		}

		// 1b. BarTer (bars + chrome positions â€” per profile)
		var barterSnap = Reflect.field(snap, "barter");
		if (barterSnap != null && cfg.barter != null)
			cfg.barter.apply(barterSnap);

		if (cfg.stacks != null) cfg.stacks.apply(Reflect.field(snap,"stacks"));
		var statusBoardSnap = Reflect.field(snap, "statusBoard");
        if (statusBoardSnap != null && cfg.statusBoard != null) cfg.statusBoard.apply(statusBoardSnap);

        // 2. Auras
		var aurasSnap = Reflect.field(snap, "auras");
		if (aurasSnap != null) {
			SettingsStore.applyAurasProfile(cfg.auras, Reflect.field(aurasSnap, "config"));
		}

		// 3. Resources
		var resSnap = Reflect.field(snap, "resources");
		if (resSnap != null) {
			var tracker=Reflect.field(resSnap,"resourceTracker");
			cfg.dash.apply(tracker==null ? null : Reflect.field(tracker,"dash"));
			cfg.resourceArtwork.apply(tracker==null ? null : Reflect.field(tracker,"artwork"));
			SettingsStore.applyVitals(cfg.vitals, Reflect.field(resSnap, "vitals"));
			SettingsStore.applyCombo(cfg.combo, Reflect.field(resSnap, "combo"));
			SettingsStore.applyAttackCombo(cfg.attackCombo, Reflect.field(resSnap, "attackCombo"));
			SettingsStore.applyTarget(cfg.target, Reflect.field(resSnap, "target"));
			SettingsStore.applyCastBar(cfg.castBar, Reflect.field(resSnap, "castBar"));
			SettingsStore.applyChaincast(cfg.chaincast, Reflect.field(resSnap, "chaincast"));
			SettingsStore.applyConduit(cfg.conduit, Reflect.field(resSnap, "conduit"));
			SettingsStore.applyHemorrhage(cfg.hemorrhage, Reflect.field(resSnap, "hemorrhage"));
		}

  cfg.extraBarsPrototype.applyProfile(snap.extraBars,snap.extraBarsPlacement);
  SettingsStore.applyProfileAuxiliary(cfg,snap.auxiliary);
  HUDWidgetWindow.invalidateGeometry();
		cfg.uiLayouts.load(cfg,Reflect.field(snap,"uiLayouts"),HudLayoutModel.legacy(snap,HudChrome.viewportWidth,HudChrome.viewportHeight));

		solarflare.ObserveDemand.markStatusDemandDirty();
		// 4. Theme
		var themeSnap = Reflect.field(snap, "theme");
		if (themeSnap != null && Std.isOfType(themeSnap, String)) {
			SettingsStore.setActiveTheme(cast themeSnap);
		}
	}

	static function ensureBuffer():Void {
		if (nameBuf == null) {
			nameBuf = new hl.Bytes(49);
			ByteUtil.clearBytes(nameBuf, 49);
		}
	}

	public static function normalizeName(v:Dynamic):String {
		if (v == null) return "";
		var s = StringTools.trim(Std.string(v));
		s = StringTools.replace(s, "\n", " ");
		s = StringTools.replace(s, "\r", "");
		if (s.length > 48) s = s.substr(0, 48);
		return s;
	}

 static function currentCharacterUid():String return ProfileBank.heroId(HealthCache.characterId);

	static function currentCharacterLabel():String {
		var name = HealthCache.heroName != null ? StringTools.trim(HealthCache.heroName) : "";
		return (name.length > 0 ? name : "Current character")+" ["+currentCharacterUid()+"]";
	}

}
