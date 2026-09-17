package solarflare.aura;

import solarflare.util.ShareCodec;

/**
 * Combine many single auras into one shareable export key, and map them to
 * Deadly Rift Mods custom alert-pack fields (INI-compatible Dynamic objects).
 * HudMod and DRM are separate .hl modules — this only serializes transfer data.
 */
class AuraPack {
	public static inline var KIND:String = "solarflare.aura_pack";
	public static inline var VER:Int = 1;

	/** DRM cue stems (same ids as deadlyriftmods CuePlayer) — stored for export only. */
	public static var CUE_IDS:Array<String> = [
		"tag_apply", "tag_clear", "tick", "gtfo", "phase", "alarm", "orbs", "clone",
		"spread", "add", "portal_tick", "portal_open", "ui_page", "ui_ack"
	];

	public static var FIGHTS:Array<String> = ["maat", "nightqueen", "shared"];

	public static function encode(fight:String, packId:String, packName:String, auras:Array<AuraDef>):String {
		return ShareCodec.encodeObj(toObj(fight, packId, packName, auras));
	}

	public static function toObj(fight:String, packId:String, packName:String, auras:Array<AuraDef>):Dynamic {
		var list:Array<Dynamic> = [];
		var drm:Array<Dynamic> = [];
		var i = 0;
		while (i < auras.length) {
			var a = auras[i];
			if (a != null) {
				list.push(AuraEngine.toObj(a));
				var d = toDrmAlert(a, fight);
				if (d != null)
					drm.push(d);
			}
			i++;
		}
		var fid = packId != null && packId.length > 0 ? packId : "aura_pack";
		var fname = packName != null && packName.length > 0 ? packName : fid;
		var ffight = fight != null && fight.length > 0 ? fight : "shared";
		return {
			kind: KIND,
			v: VER,
			id: fid,
			name: fname,
			fight: ffight,
			auras: list,
			drm: drm
		};
	}

	/** Map one aura to a DRM custom pack alert row when a skill id exists. */
	public static function toDrmAlert(a:AuraDef, packFight:String):Dynamic {
		if (a == null)
			return null;
		var ids = a.skillId != null ? StringTools.trim(a.skillId) : "";
		if (ids.length < 2)
			return null;
		var fight = a.fight != null && a.fight.length > 0 ? a.fight : packFight;
		if (fight == null || fight.length == 0)
			fight = "shared";
		var announce = a.announce != null && a.announce.length > 0 ? a.announce : a.name;
		if (announce == null || announce.length == 0)
			announce = a.id;
		var plate = a.plate != null && a.plate.length > 0 ? a.plate : "";
		if (plate.length == 0 && a.iconId != null && a.iconId.length > 0)
			plate = a.iconId;
		if (plate.length == 0)
			plate = ids;
		if (StringTools.endsWith(plate, ".png"))
			plate = plate.substr(0, plate.length - 4);
		var hold = a.duration > 0.05 ? a.duration : 3.0;
		return {
			id: a.id,
			fight: fight,
			announce: announce,
			plate: plate,
			cue: a.cue != null ? a.cue : "",
			audio: a.audio.get(),
			visual: a.visual.get(),
			hold: hold,
			trigger_source: drmTriggerSource(a.trigger),
			trigger_ids: ids,
			volume: a.volume.get()
		};
	}

	public static function drmTriggerSource(trigger:String):String {
		if (trigger == "status")
			return "status";
		if (trigger == "combatlog" || trigger == "cooldown")
			return "cast";
		return "cast";
	}

	/** One DRM pack INI (custom alert) from a mapped alert Dynamic. */
	public static function drmIni(d:Dynamic):String {
		if (d == null)
			return "";
		var b = new StringBuf();
		b.add("[alert]\n");
		b.add("id=" + Std.string(d.id) + "\n");
		b.add("fight=" + Std.string(d.fight) + "\n");
		b.add("announce=" + Std.string(d.announce) + "\n");
		b.add("plate=" + Std.string(d.plate) + "\n");
		b.add("cue=" + (d.cue != null ? Std.string(d.cue) : "") + "\n");
		b.add("audio=" + (d.audio == true ? "true" : "false") + "\n");
		b.add("visual=" + (d.visual == false ? "false" : "true") + "\n");
		b.add("hold=" + Std.string(d.hold != null ? d.hold : 3) + "\n");
		b.add("trigger_source=" + Std.string(d.trigger_source != null ? d.trigger_source : "cast") + "\n");
		b.add("trigger_ids=" + Std.string(d.trigger_ids) + "\n");
		return b.toString();
	}

	/** Concatenated INIs for a pack (separated by blank lines) — drop into packs/custom/. */
	public static function drmIniBundle(fight:String, packId:String, packName:String, auras:Array<AuraDef>):String {
		var obj = toObj(fight, packId, packName, auras);
		var drm:Array<Dynamic> = obj.drm;
		if (drm == null || drm.length == 0)
			return "; no DRM-mappable auras (need skillId on each)\n";
		var b = new StringBuf();
		b.add("; Aura pack \"" + Std.string(obj.name) + "\" → DRM custom alerts\n");
		b.add("; Save each [alert] block as packs/custom/<id>.ini (or split manually).\n\n");
		var i = 0;
		while (i < drm.length) {
			b.add(drmIni(drm[i]));
			if (i < drm.length - 1)
				b.add("\n");
			i++;
		}
		return b.toString();
	}

	public static function decode(s:String):Dynamic {
		if (s == null)
			return null;
		var t = StringTools.trim(s);
		if (t.length < 4)
			return null;
		try
			return ShareCodec.parseDyn(t)
		catch (_:Dynamic)
			return null;
	}

	/** Import auras from a pack export (kind solarflare.aura_pack or bare aura array). */
	public static function unpackAuras(d:Dynamic):Array<AuraDef> {
		var out:Array<AuraDef> = [];
		if (d == null)
			return out;
		var list:Array<Dynamic> = null;
		if (Std.isOfType(d, Array))
			list = cast d;
		else if (d.auras != null)
			list = cast d.auras;
		else if (d.id != null) {
			out.push(AuraConfig.fromDyn(d));
			return out;
		}
		if (list == null)
			return out;
		var i = 0;
		while (i < list.length) {
			var item = list[i];
			if (item != null && item.id != null)
				out.push(AuraConfig.fromDyn(item));
			i++;
		}
		return out;
	}
}
