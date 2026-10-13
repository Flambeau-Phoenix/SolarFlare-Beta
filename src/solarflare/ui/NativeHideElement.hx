package solarflare.ui;

import imgui.ref.BoolRef;

/**
 * One show/hide row of the Native UI hub page. Presentation preference only: no live engine pointers.
 * `hidden` is persisted by NativeHideConfig; `state` is written by NativeElementCache during observation.
 */
class NativeHideElement {
	/** Not looked up yet (page closed, nothing hidden, or the HUD is still loading). */
	public static inline var STATE_WAITING:Int = 0;
	/** The live widget was located. */
	public static inline var STATE_FOUND:Int = 1;
	/** The HUD is up but this widget is not on it (for example the pad module while on keyboard). */
	public static inline var STATE_ABSENT:Int = 2;
	/** Another mod owns this widget's visibility; SolarFlare leaves it alone. */
	public static inline var STATE_EXTERNAL:Int = 3;

	public var id:String;
	public var label:String;
	public var group:String;
	public var hint:String;
	public var hidden:BoolRef;
	public var state:Int = STATE_WAITING;

	public function new(id:String, label:String, group:String, hint:String) {
		this.id = id;
		this.label = label;
		this.group = group;
		this.hint = hint;
		hidden = new BoolRef(false);
	}
}
