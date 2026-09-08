package solarflare.ui;

import haxe.Json;
import imgui.ImGui;
import solarflare.ui.ToastManager;
import solarflare.ui.ByteUtil;

/**
 * Universal Profile Architecture for Solar Flare 2.
 * Captures, manages, and switches the entire HUD loadout (Geaux Bar + Resource Trackers + Auras + Theme)
 * in a single, atomic operation with 100% clean string persistence.
 */
class FeatureProfiles {
	public static inline var DEFAULT_KEY:String = "Default";

	public static var activeProfile:String = DEFAULT_KEY;
	public static var profiles:Map<String, Dynamic> = new Map();
	public static var order:Array<String> = [DEFAULT_KEY];

	static var nameBuf:hl.Bytes;
	static var statusMsg:String = "";
	static var statusTimer:Float = 0;

	public static function init(cfg:ConfigPanel):Void {
		ensureBuffer();
		if (!profiles.exists(DEFAULT_KEY)) {
			profiles.set(DEFAULT_KEY, clone(captureAll(cfg)));
			if (order.indexOf(DEFAULT_KEY) < 0)
				order.unshift(DEFAULT_KEY);
		}
		if (!profiles.exists(activeProfile))
			activeProfile = DEFAULT_KEY;
	}

	public static var activeKey(get, never):String;
	static function get_activeKey():String return activeProfile;

	public static function activeName(domain:String = ""):String return activeProfile;

	public static function load(cfg:ConfigPanel, data:Dynamic):Void {
		profiles = new Map();
		order = [];

		if (data != null) {
			// 1. Check for modern universal profiles
			var universal = Reflect.field(data, "universalProfiles");
			if (universal != null) {
				var proms = Reflect.field(universal, "profiles");
				if (proms != null) {
					for (k in Reflect.fields(proms)) {
						var name = normalizeName(k);
						if (name.length > 0 && !profiles.exists(name)) {
							order.push(name);
							profiles.set(name, clone(Reflect.field(proms, k)));
						}
					}
				}
				var act = normalizeName(Reflect.field(universal, "active"));
				if (act.length > 0)
					activeProfile = act;
			}

			// 2. Backward compatibility & Migration: check legacy domain banks
			var legacy = Reflect.field(data, "featureProfiles");
			if (legacy != null) {
				// Migrate and back up any legacy geaux/auras/resources profiles
				var geauxBank = Reflect.field(legacy, "geaux");
				if (geauxBank != null) {
					var gProfs = Reflect.field(geauxBank, "profiles");
					if (gProfs != null) {
						for (k in Reflect.fields(gProfs)) {
							var name = normalizeName(k);
							if (name.length > 0 && !profiles.exists(name)) {
								order.push(name);
								var migratedSnap = {
									geaux: {layout: Reflect.field(Reflect.field(gProfs, k), "layout")},
									auras: cfg != null ? {config: SettingsStore.aurasDump(cfg.auras)} : {},
									resources: cfg != null ? captureResources(cfg) : {}
								};
								profiles.set(name, migratedSnap);
							}
						}
					}
				}
			}
		}

		init(cfg);
		applyUniversal(cfg, activeProfile);
	}

	public static function storeCurrent(cfg:ConfigPanel, domain:String = ""):Void {
		if (cfg == null) return;
		profiles.set(activeProfile, clone(captureAll(cfg)));
	}

	public static function storeAll(cfg:ConfigPanel):Void {
		storeCurrent(cfg);
	}

	public static function dump():Dynamic {
		var profsObj:Dynamic = {};
		for (key in order) {
			if (profiles.exists(key))
				Reflect.setField(profsObj, key, profiles.get(key));
		}
		return {
			active: activeProfile,
			profiles: profsObj
		};
	}

	public static function drawToolbar(cfg:ConfigPanel, domain:String = "", id:String = "main"):Void {
		if (cfg == null) return;
		ensureBuffer();

		ImGui.alignTextToFramePadding();
		ImGui.text("Profile");
		ImGui.sameLine();

		ImGui.setNextItemWidth(140);
		if (ImGui.beginCombo("##fp_select_" + id, activeProfile)) {
			for (key in order) {
				if (ImGui.selectable(key + "##fp_opt_" + id + "_" + key, key == activeProfile)) {
					switchTo(cfg, key);
				}
			}
			ImGui.endCombo();
		}

		ImGui.sameLine();
		if (ImGui.button("Save##fp_save_" + id)) {
			save(cfg);
		}

		ImGui.sameLine();
		if (ImGui.button("New##fp_new_" + id)) {
			ByteUtil.clearBytes(nameBuf, 49);
			ImGui.openPopup("New Universal Profile##fp_new_popup");
		}

		ImGui.sameLine();
		if (ImGui.button("Copy##fp_copy_" + id)) {
			duplicateCurrent(cfg);
		}

		if (activeProfile != DEFAULT_KEY) {
			ImGui.sameLine();
			if (ImGui.button("Delete##fp_del_" + id)) {
				delete(cfg, activeProfile);
			}
		}

		if (statusMsg.length > 0) {
			ImGui.sameLine();
			ImGui.textColored(ImGui.vec4(0.4, 0.85, 0.4, 1.0), statusMsg);
		}

		if (ImGui.beginPopupModal("New Universal Profile##fp_new_popup", null, imgui.Enums.ImGuiWindowFlags.AlwaysAutoResize)) {
			ImGui.text("Enter profile name:");
			ImGui.inputText("##fp_name", nameBuf, 49);
			if (ImGui.button("Create##fp_create")) {
				var requested = ByteUtil.readBytes(nameBuf, 49);
				if (create(cfg, requested))
					ImGui.closeCurrentPopup();
			}
			ImGui.sameLine();
			if (ImGui.button("Cancel##fp_cancel"))
				ImGui.closeCurrentPopup();
			ImGui.endPopup();
		}
	}

	public static function save(cfg:ConfigPanel):Void {
		storeCurrent(cfg);
		setStatus('Profile "$activeProfile" saved.');
		SettingsStore.markDirty();
		SettingsStore.saveNow();
		ToastManager.success('Universal Profile "$activeProfile" saved!');
	}

	public static function switchTo(cfg:ConfigPanel, key:String):Void {
		if (cfg == null || key == null || !profiles.exists(key)) return;
		storeCurrent(cfg);
		activeProfile = key;
		applyUniversal(cfg, key);
		setStatus('Loaded profile "$key".');
		SettingsStore.markDirty();
		SettingsStore.saveNow();
		ToastManager.info('Switched to profile "$key"');
	}

	public static function create(cfg:ConfigPanel, requested:String):Bool {
		var name = normalizeName(requested);
		if (name.length == 0) {
			setStatus("Name required.");
			ToastManager.warn("Profile name required.");
			return false;
		}
		if (profiles.exists(name)) {
			setStatus("Profile already exists.");
			ToastManager.warn('Profile "$name" already exists.');
			return false;
		}
		storeCurrent(cfg);
		profiles.set(name, clone(captureAll(cfg)));
		order.push(name);
		activeProfile = name;
		setStatus('Created "$name".');
		SettingsStore.markDirty();
		SettingsStore.saveNow();
		ToastManager.success('Created Universal Profile "$name"!');
		return true;
	}

	public static function duplicateCurrent(cfg:ConfigPanel):Void {
		if (cfg == null) return;
		var base = activeProfile + " (Copy)";
		var name = base;
		var counter = 2;
		while (profiles.exists(name)) {
			name = base + " " + counter;
			counter++;
		}
		create(cfg, name);
	}

	public static function delete(cfg:ConfigPanel, key:String):Void {
		if (key == DEFAULT_KEY) {
			setStatus("Default profile cannot be deleted.");
			ToastManager.warn("Default profile cannot be deleted.");
			return;
		}
		profiles.remove(key);
		order.remove(key);
		activeProfile = DEFAULT_KEY;
		applyUniversal(cfg, DEFAULT_KEY);
		setStatus('Deleted "$key".');
		SettingsStore.markDirty();
		SettingsStore.saveNow();
		ToastManager.info('Deleted profile "$key".');
	}

	static function captureAll(cfg:ConfigPanel):Dynamic {
		if (cfg == null) return {};
		return {
			geaux: {layout: SettingsStore.geauxDump(cfg.geaux)},
			auras: {config: SettingsStore.aurasDump(cfg.auras)},
			resources: captureResources(cfg),
			theme: SettingsStore.currentTheme()
		};
	}

	static function captureResources(cfg:ConfigPanel):Dynamic {
		return {
			vitals: SettingsStore.vitalsDump(cfg.vitals),
			combo: SettingsStore.comboDump(cfg.combo),
			attackCombo: SettingsStore.attackComboDump(cfg.attackCombo),
			target: SettingsStore.targetDump(cfg.target),
			chaincast: SettingsStore.chaincastDump(cfg.chaincast),
			conduit: SettingsStore.conduitDump(cfg.conduit)
		};
	}

	static function applyUniversal(cfg:ConfigPanel, key:String):Void {
		if (cfg == null) return;
		var snap = profiles.get(key);
		if (snap == null) return;

		// 1. Geaux Layout
		var geauxSnap = Reflect.field(snap, "geaux");
		if (geauxSnap != null) {
			SettingsStore.applyGeauxProfile(cfg.geaux, Reflect.field(geauxSnap, "layout"));
		}

		// 2. Auras
		var aurasSnap = Reflect.field(snap, "auras");
		if (aurasSnap != null) {
			SettingsStore.applyAurasProfile(cfg.auras, Reflect.field(aurasSnap, "config"));
		}

		// 3. Resources
		var resSnap = Reflect.field(snap, "resources");
		if (resSnap != null) {
			SettingsStore.applyVitals(cfg.vitals, Reflect.field(resSnap, "vitals"));
			SettingsStore.applyCombo(cfg.combo, Reflect.field(resSnap, "combo"));
			SettingsStore.applyAttackCombo(cfg.attackCombo, Reflect.field(resSnap, "attackCombo"));
			SettingsStore.applyTarget(cfg.target, Reflect.field(resSnap, "target"));
			SettingsStore.applyChaincast(cfg.chaincast, Reflect.field(resSnap, "chaincast"));
			SettingsStore.applyConduit(cfg.conduit, Reflect.field(resSnap, "conduit"));
		}

		// 4. Theme
		var themeSnap = Reflect.field(snap, "theme");
		if (themeSnap != null && Std.isOfType(themeSnap, String)) {
			SettingsStore.setActiveTheme(cast themeSnap);
		}
	}

	static function setStatus(msg:String):Void {
		statusMsg = msg;
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

	static function clone(v:Dynamic):Dynamic {
		if (v == null) return {};
		try return Json.parse(Json.stringify(v)) catch (_:Dynamic) return {};
	}
}
