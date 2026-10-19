package solarflare.aura.ui;

import solarflare.aura.AuraDef;
import solarflare.aura.preview.AdvancedAuraPreview;

/** What the Canvas Editor window needs from the Aura Builder that owns the library and undo history. */
interface CanvasHost {
	function canvasSelectedAura():AuraDef;
	function canvasAuras():Array<AuraDef>;
	/** Undo point for the selected aura's canvas and states only; cheap enough for every edit. */
	function canvasSnapshot(name:String):Void;
	/** Undo point for edits that reach beyond one aura (renaming an image rewrites references everywhere). */
	function canvasSnapshotAll(name:String):Void;
	/** The scoped state to hand back to canvasUndoPush once a drag or typed edit lands. */
	function canvasSnapshotJson():String;
	function canvasUndo():Void;
	function canvasRedo():Void;
	function canvasCanUndo():Bool;
	function canvasCanRedo():Bool;
	function canvasUndoPush(name:String, state:String):Void;
	function canvasPreview():AdvancedAuraPreview;
	/** Snapshot callback handed to typed fields. */
	function canvasPrecise():Void;
	function canvasHostOpen():Bool;
}
