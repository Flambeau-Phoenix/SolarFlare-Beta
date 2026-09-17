package solarflare.debug;

import solarflare.debug.ResolutionLedger.LedgerAgg;

/**
 * Latched ledger emit site.
 *
 * Held by a hot caller across frames so `ResolutionLedger.bump` can increment the row
 * directly, instead of rebuilding the five-part key and re-running `cleanId` on the name
 * and preview for every single call. `gen` invalidates the handle when the recording
 * session is cleared, so a stale binding can never write into a detached row.
 */
@:keep
class LedgerBinding {
	public var agg:LedgerAgg = null;
	public var gen:Int = -1;
	/** Last preview written, so an unchanged value skips the store entirely. */
	public var preview:String = "";

	public function new() {}
}
