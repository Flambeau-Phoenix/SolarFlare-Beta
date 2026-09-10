package solarflare.ui.effects;

import solarflare.ui.effects.VectorEffectSystem;

/**
 * Convenient effect spawners for gameplay triggers, cooldown completions, and aura events.
 */
class EffectHelpers {
	/**
	 * Spawns radial pulse and golden particle burst when an aura triggers or is hit.
	 */
	public static function auraHit(x:Float, y:Float):Void {
		VectorEffectSystem.create(Pulse, x, y, {
			duration: 0.5,
			startRadius: 10,
			endRadius: 55,
			startColor: 0xCCFFFFFF,
			endColor: 0x00FFFFFF,
			thickness: 2.5,
			segments: 24
		});

		VectorEffectSystem.create(Particles, x, y, {
			duration: 0.7,
			startColor: 0x88FFCC44,
			endColor: 0x00FFCC44,
			particleCount: 16,
			gravityY: 60
		});
	}

	/**
	 * Spawns crimson spark burst on aura expiration.
	 */
	public static function auraExpire(x:Float, y:Float):Void {
		VectorEffectSystem.create(Spark, x, y, {
			duration: 0.4,
			startRadius: 25,
			endRadius: 55,
			startColor: 0xCCFF4444,
			endColor: 0x00FF4444,
			thickness: 2,
			segments: 8
		});
	}

	/**
	 * Spawns green beam / bloom when an ability cooldown completes.
	 */
	public static function skillReady(x:Float, y:Float):Void {
		VectorEffectSystem.create(Pulse, x, y, {
			duration: 0.35,
			startRadius: 12,
			endRadius: 36,
			startColor: 0x8844FF88,
			endColor: 0x0044FF88,
			thickness: 2.0,
			segments: 18
		});
	}
}
