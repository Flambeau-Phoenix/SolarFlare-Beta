package solarflare.aura.signal;

/** Shared observe-thread ordering for cast and combat timer activation tokens. */
class AuraEventSequence {
	static var sequence:Int = 0;
	public static function next():Int return ++sequence;
}
