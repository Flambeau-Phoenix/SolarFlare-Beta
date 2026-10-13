package solarflare.ui;

import hlx.runtime.ResolvedMember;
import solarflare.FieldWalk;

/**
 * One native widget the Native UI page can hide. The live node is observation-only and scrubbed with the
 * session; nothing here is read from configuration or drawing.
 */
private class ElementTarget {
	public var id:String;
	public var kind:Int;
	/** Hud field name (FROM_HUD) or the hl type path of the child to find (FROM_HERO_BAR / FROM_HERO_PAD). */
	public var name:String;
	public var element:NativeHideElement;
	public var childType:hl.Type;
	public var node:Dynamic;
	public var parent:Dynamic;
	/** True while this target holds a hide it applied; `native` is the value to hand back. */
	public var owned:Bool = false;
	public var native:Bool = true;
	public var nextScan:Int = 0;
	/** Another mod owns this widget's visibility. */
	public var external:Bool = false;

	public function new(id:String, kind:Int, name:String) {
		this.id = id;
		this.kind = kind;
		this.name = name;
	}
}

/**
 * Observe-side hide/show for individual native HUD widgets (the Native UI hub page). Same contract as
 * NativeHideCache, which calls it from its own pass with the HUD it already resolved:
 *
 * - the live widget is reached from `ui.Hud` (a field, or a typed child of HeroBar / HeroBarPad), never cached
 *   in configuration;
 * - the native visibility is captured before the first write and handed back when the user shows it again;
 * - only `ui.UIElement.set_visible` is called (the same member the bottom bar uses), and only on objects that
 *   are verified `ui.UIElement` instances;
 * - no hook: `Hud.updateVisibility` only re-shows HeroBar/HeroBarPad, so a hidden child or Hud field is held
 *   by re-asserting each pass. Nothing runs while no row is hidden and the page is closed.
 *
 * Consumables: `ui.hud.ConsumableWheel` (keyboard) and `ui.hud.ConsumableWheelPad` (gamepad) are direct children
 * of HeroBar / HeroBarPad, built from the four equipment slots 2056..2059, which is the 2x2 module.
 */
class NativeElementCache {
	static inline var FROM_HUD:Int = 0;
	static inline var FROM_HERO_BAR:Int = 1;
	static inline var FROM_HERO_PAD:Int = 2;
	/** Passes between child scans while the widget is not found (about half a second). */
	static inline var SCAN_INTERVAL:Int = 30;

	static var initialized = false;
	static var available = false;
	static var failed = false;
	static var setVisible:ResolvedMember;
	static var uiType:hl.Type;
	static var targets:Array<ElementTarget> = [];
	static var boundCfg:NativeHideConfig;
	static var lastHud:Dynamic;
	static var tick:Int = 0;
	static var visibleArgs:Array<Dynamic> = [null, false];

	static function init():Void {
		if (initialized)
			return;
		initialized = true;
		targets = [
			// One row can have several targets: the keyboard module or the pad one exists, never both.
			new ElementTarget("consumables", FROM_HERO_BAR, "ui.hud.ConsumableWheel"),
			new ElementTarget("consumables", FROM_HERO_PAD, "ui.hud.ConsumableWheelPad"),
			new ElementTarget("menuBar", FROM_HUD, "menuBar"),
			new ElementTarget("chat", FROM_HUD, "chat"),
			new ElementTarget("compass", FROM_HUD, "compass"),
			new ElementTarget("groupBar", FROM_HUD, "groupBar"),
			new ElementTarget("bossesInfo", FROM_HUD, "bossesInfo"),
			new ElementTarget("oxygen", FROM_HUD, "oxygen"),
			new ElementTarget("combatMeter", FROM_HUD, "combatMeter"),
			new ElementTarget("feed", FROM_HUD, "feed")
		];
		try {
			var elementType = HlxRuntime.resolveType("ui.UIElement");
			if (elementType == null)
				return;
			uiType = cast elementType;
			setVisible = HlxRuntime.resolveMember(elementType, "set_visible");
			available = uiType != null && setVisible != null;
			if (!available)
				return;
			for (t in targets) {
				if (t.kind == FROM_HUD)
					continue;
				try {
					var childType = HlxRuntime.resolveType(t.name);
					if (childType != null)
						t.childType = cast childType;
				} catch (_:Dynamic) {}
			}
		} catch (_:Dynamic) { available = false; }
	}

	static function bind(cfg:NativeHideConfig):Void {
		if (boundCfg == cfg)
			return;
		boundCfg = cfg;
		for (t in targets) {
			t.element = null;
			for (e in cfg.elements) {
				if (e.id == t.id) {
					t.element = e;
					break;
				}
			}
		}
	}

	static inline function field(value:Dynamic, name:String):Dynamic {
		return value == null ? null : HlxRuntime.resolveField(value, name);
	}

	static function isElement(node:Dynamic):Bool {
		try {
			return hl.Type.getDynamic(node).safeCast(uiType);
		} catch (_:Dynamic) {}
		return false;
	}

	static function modOwnsChat():Bool {
		try {
			return hlx.runtime.Registry.get("mods", "enhanced-chat") != null;
		} catch (_:Dynamic) {}
		return false;
	}

	/** Direct children only: the consumable modules are created straight under their bar. */
	static function childOfType(parent:Dynamic, type:hl.Type):Dynamic {
		if (type == null)
			return null;
		// Game arrays cross a module boundary: never typed as ArrayBase (that cast fails at runtime).
		var kids:Dynamic = HlxRuntime.resolveField(parent, "children");
		var total = FieldWalk.arrayLen(kids, 0);
		for (i in 0...total) {
			var child:Dynamic = FieldWalk.arrayAt(kids, i);
			if (child != null && hl.Type.getDynamic(child).safeCast(type))
				return child;
		}
		return null;
	}

	static function write(node:Dynamic, value:Bool):Void {
		visibleArgs[0] = node;
		visibleArgs[1] = value;
		try
			HlxRuntime.callResolved(setVisible, visibleArgs)
		catch (_:Dynamic) {}
		visibleArgs[0] = null;
	}

	/** Forget every captured widget without touching it: the HUD that owned them is gone. */
	static function forget():Void {
		for (t in targets) {
			t.node = null;
			t.parent = null;
			t.owned = false;
			t.nextScan = 0;
			t.external = t.id == "chat" && modOwnsChat();
		}
	}

	/**
	 * Called from NativeHideCache.apply with the Hud, HeroBar and HeroBarPad it resolved this pass
	 * (any may be null while the HUD loads). Safe to call every pass.
	 */
	public static function apply(hud:Dynamic, heroBar:Dynamic, heroBarPad:Dynamic, cfg:NativeHideConfig):Void {
		if (cfg == null)
			return;
		var probe = cfg.probe;
		cfg.probe = false;
		init();
		if (!available || failed) {
			cfg.elementsStatus = failed
				? "Stopped after a runtime error; native visibility restored."
				: "Unavailable: native HUD members did not resolve.";
			return;
		}
		cfg.elementsStatus = "";
		bind(cfg);
		try {
			if (hud != lastHud) {
				// Rebuilt HUD: its widgets carry native values again. Nothing old is written to.
				forget();
				lastHud = hud;
			}
			var active = probe;
			if (!active) {
				for (t in targets) {
					if (t.owned || (t.element != null && t.element.hidden.get())) {
						active = true;
						break;
					}
				}
			}
			if (!active)
				return;
			tick++;
			for (e in cfg.elements)
				e.state = hud == null ? NativeHideElement.STATE_WAITING : NativeHideElement.STATE_ABSENT;
			if (hud == null)
				return;
			for (t in targets)
				pass(t, hud, heroBar, heroBarPad);
			for (t in targets) {
				var e = t.element;
				if (e == null)
					continue;
				if (t.external)
					e.state = NativeHideElement.STATE_EXTERNAL;
				else if (t.node != null)
					e.state = NativeHideElement.STATE_FOUND;
			}
		} catch (_:Dynamic) {
			failed = true;
			cfg.elementsStatus = "Stopped after a runtime error; native visibility restored.";
			releaseAll(true, false);
		}
	}

	static function pass(t:ElementTarget, hud:Dynamic, heroBar:Dynamic, heroBarPad:Dynamic):Void {
		var e = t.element;
		if (e == null || t.external)
			return;
		var node:Dynamic = null;
		if (t.kind == FROM_HUD) {
			node = field(hud, t.name);
		} else {
			var parent = t.kind == FROM_HERO_BAR ? heroBar : heroBarPad;
			if (parent != t.parent) {
				// New bar: the module under it was rebuilt too.
				t.parent = parent;
				t.node = null;
				t.owned = false;
				t.nextScan = 0;
			}
			if (parent != null) {
				if (t.node != null && field(t.node, "parent") == parent) {
					node = t.node;
				} else if (tick >= t.nextScan) {
					t.nextScan = tick + SCAN_INTERVAL;
					node = childOfType(parent, t.childType);
				}
			}
		}
		if (node != t.node) {
			// A different object (or none): the capture belonged to the old one.
			t.node = node != null && isElement(node) ? node : null;
			t.owned = false;
		}
		node = t.node;
		if (node == null)
			return;
		if (e.hidden.get()) {
			var current = field(node, "visible");
			if (!t.owned) {
				t.native = current != false;
				t.owned = true;
			}
			if (current != false)
				write(node, false);
		} else if (t.owned) {
			t.owned = false;
			write(node, t.native);
		}
	}

	/**
	 * Hand every held widget back and drop all references. `attached` is false when the HUD is gone, so a
	 * detached widget is never called.
	 */
	public static function releaseAll(attached:Bool, resetFailure:Bool = true):Void {
		if (initialized && available) {
			for (t in targets) {
				if (attached && t.owned && t.node != null) {
					try
						write(t.node, t.native)
					catch (_:Dynamic) {}
				}
				t.node = null;
				t.parent = null;
				t.owned = false;
				t.nextScan = 0;
			}
		}
		lastHud = null;
		boundCfg = null;
		visibleArgs[0] = null;
		visibleArgs[1] = false;
		if (resetFailure)
			failed = false;
	}
}
