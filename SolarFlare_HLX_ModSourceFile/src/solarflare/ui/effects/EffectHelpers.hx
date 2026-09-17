package solarflare.ui.effects;

import solarflare.ui.effects.VectorEffectSystem;

typedef EffectFactory = EffectType->Float->Float->EffectParams->VectorEffect;

/**
 * Convenient effect spawners for gameplay triggers, cooldown completions, and aura events.
 */
class EffectHelpers {
	/**
	 * Spawns radial pulse and golden particle burst when an aura triggers or is hit.
	 */
	public static function auraHit(x:Float, y:Float, factory:EffectFactory = null):Void {
		spawn(Pulse, x, y, {
			duration: 0.5,
			startRadius: 10,
			endRadius: 55,
			startColor: 0xCCFFFFFF,
			endColor: 0x00FFFFFF,
			thickness: 2.5,
			segments: 24
		}, factory);

		spawn(Particles, x, y, {
			duration: 0.7,
			startColor: 0x88FFCC44,
			endColor: 0x00FFCC44,
			particleCount: 16,
			gravityY: 60
		}, factory);
	}

	/**
	 * Spawns crimson spark burst on aura expiration.
	 */
	public static function auraExpire(x:Float, y:Float, factory:EffectFactory = null):Void {
		spawn(Spark, x, y, {
			duration: 0.4,
			startRadius: 25,
			endRadius: 55,
			startColor: 0xCCFF4444,
			endColor: 0x00FF4444,
			thickness: 2,
			segments: 8
		}, factory);
	}

	/**
	 * Spawns green beam / bloom when an ability cooldown completes.
	 */
	public static function skillReady(x:Float, y:Float, factory:EffectFactory = null):Void {
		spawn(Pulse, x, y, {
			duration: 0.35,
			startRadius: 12,
			endRadius: 36,
			startColor: 0x8844FF88,
			endColor: 0x0044FF88,
			thickness: 2.0,
			segments: 18
		}, factory);
	}

	static function spawn(type:EffectType, x:Float, y:Float, params:EffectParams,
			factory:EffectFactory):VectorEffect {
		return factory != null ? factory(type, x, y, params) : VectorEffectSystem.create(type, x, y, params);
	}
}
