package solarflare.preview;

/**
 * Preset preview scenarios (Segment 1.2).
 *
 * Each factory on `PreviewState` builds a deterministic frozen snapshot,
 * independent of live game state. The three non-empty scenarios are a
 * progression of the same class profile so the shared renderer can prove
 * layout, labels, fills, and alert end states without entering combat.
 */
enum PreviewScenario {
	/** Valid frames at zero: nothing charged, filled, or in progress. */
	Empty;
	/** Mid-fill: every ResourceTracker element and Attack Combo partially built. */
	Partial;
	/** Everything capped: full bars, all charges, final combo step without flash. */
	Full;
	/** Alert end states: combo flash, chaincast ready/pulse, conduit power, prayer burst. */
	FinalAlert;
}