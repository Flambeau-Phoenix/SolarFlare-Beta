package solarflare.aura;

/** A new event episode can rise while its time-window predicate stays true. */
class AuraEffectEdges {
	public static inline function rise(known:Bool,hit:Bool,was:Bool,eventRestart:Bool):Bool
		return known && hit && (!was || eventRestart);
	public static inline function fall(known:Bool,hit:Bool,was:Bool):Bool
		return known && !hit && was;
}
