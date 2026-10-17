package solarflare.ui;

/** Installed bytecode proof: docs/NativeHide-packet.md and build/native-hide-2026-10-09. */
class NativeHideHooks {
	public static function keep():Void {}

	// Installed C7173926: GameApp.update(GameApp, f64)->void; postfix N+1=3.
	@:hlx.postfix(GameApp.update)
	static function afterGameUpdate(self:Dynamic, dt:Float, result:Void):Void {
		NativeHideCache.afterGameUpdate(self);
	}

	// Native N=1 (self), postfix N+1=2 (self, result). Original always runs.
	@:hlx.postfix(ui.Hud.updateVisibility)
	static function afterUpdateVisibility(self:Dynamic, result:Void):Void {
		NativeHideCache.afterUpdateVisibility(self);
		try
			HideMoveCache.afterUpdateVisibility(self)
		catch (_:Dynamic) {}
	}
}
