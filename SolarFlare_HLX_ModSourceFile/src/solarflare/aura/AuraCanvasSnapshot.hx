package solarflare.aura;

import haxe.Json;

/** A restored aura canvas: elements and states rebuilt from a scoped undo entry. */
typedef AuraCanvasState = {id:String, elements:Array<AuraCanvasElement>, states:Array<AuraStateDef>, w:Float, h:Float};

/**
 * Scoped undo entries hold one aura's canvas elements and states, not the whole library. Entries carry a
 * "cv:" prefix so they can share a history with whole-library snapshots (which start with "{").
 */
class AuraCanvasSnapshot {
	public static inline var PREFIX:String = "cv:";

	public static inline function isScoped(state:String):Bool return state != null && StringTools.startsWith(state, PREFIX);

	public static function dump(auraId:String, elements:Array<AuraCanvasElement>, states:Array<AuraStateDef>, w:Float = 0, h:Float = 0):String {
		return PREFIX + Json.stringify({
			w: w, h: h,
			id: auraId,
			elements: [for (el in (elements != null ? elements : [])) if (el != null) el.toObj()],
			states: [for (st in (states != null ? states : [])) if (st != null) st.toObj()]
		});
	}

	/** Aura id an entry belongs to, or null for whole-library or unreadable entries. */
	public static function auraId(state:String):String {
		if (!isScoped(state)) return null;
		try {
			var id:Dynamic = Json.parse(state.substr(PREFIX.length)).id;
			return Std.isOfType(id, String) ? id : null;
		} catch (_:Dynamic) return null;
	}

	/** Null when the entry cannot be read. */
	public static function parse(state:String):AuraCanvasState {
		if (!isScoped(state)) return null;
		try {
			var data:Dynamic = Json.parse(state.substr(PREFIX.length));
			if (!Std.isOfType(data.id, String)) return null;
			var rawEls:Array<Dynamic> = Std.isOfType(data.elements, Array) ? cast data.elements : [];
			var rawStates:Array<Dynamic> = Std.isOfType(data.states, Array) ? cast data.states : [];
			var states:Array<AuraStateDef> = [];
			for (raw in rawStates) {
				var st = AuraStateDef.fromDyn(raw);
				if (st != null && AuraStateDef.find(states, st.id) == null && states.length < AuraStateDef.MAX_STATES) states.push(st);
			}
			var w:Float = Std.isOfType(data.w, Float) || Std.isOfType(data.w, Int) ? data.w : 0;
			var h:Float = Std.isOfType(data.h, Float) || Std.isOfType(data.h, Int) ? data.h : 0;
			return {id: data.id, elements: [for (raw in rawEls) if (raw != null) AuraCanvasElement.fromDyn(raw)], states: states,
				w: Math.isFinite(w) && w >= 1 ? Math.min(w, 4000) : 0, h: Math.isFinite(h) && h >= 1 ? Math.min(h, 4000) : 0};
		} catch (_:Dynamic) return null;
	}
}
