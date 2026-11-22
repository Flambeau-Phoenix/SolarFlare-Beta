# SolarFlare Hook Authority

This is the current release contract. `solarflare.hl` has event-only MinHooks; continuous values have one bounded-sampling authority. `solarflare-telemetry.hl` may add diagnostic hooks, but those are not release dependencies.

| Release hook | Sole responsibility |
|---|---|
| `st.skill.BaseSkill.doStart` postfix | Cast start, attack-combo finisher/base touch, enemy-cast primitive |
| `st.skill.BaseSkill.doStop` postfix | Cast stop primitive event |
| `ent.Hero.onSkillUse` postfix | Local prayer classification |
| `ent.Unit.rpcDisplayDamage__impl` postfix | Client DamageInfo receive event; freeze amount, crit, IDs and attribution into the combat queue |
| `ui.Hud.updateVisibility` postfix | NativeHide KeepWorld re-assert |
| `GameApp.update` postfix | Reassert only an already acquired native chat visibility lease before rendering; no discovery or telemetry |
| `ent.Hero.set_attackComboCount` postfix | Attack-combo **step** authority (ordinary chain); poll is late-join seed only |
| `client.UnitController.startSkillAim` postfix | Instant ground cast (option, default off): confirms an aim that just started; no state is read or retained |

Health, shield, rage, spark, cooldowns, status presence/stacks/duration, chaincast, conduit, and Rogue combo points are sampled. Attack-combo step is owned by `set_attackComboCount`, not dual continuous sampling. Identity is owned by `TelemetryKernel.observeLocalPlayer()`.

## PTR damage ingress — 2026-11-22

Build `e9fff3f57f7775329da731c360b6e62e29b4a17f24c12b7a9a4793119d5d4827` uses
`ent.Unit.rpcDisplayDamage__impl` (5070, `fun(ent.Unit, st.skill.DamageInfo)->void`).
The postfix has exactly three slots, including trailing `result:Void`. V3 standalone
capture observed 1,157 packets with zero errors/drops before the production adapter
was connected. `Unit.applyDamage`, `receiveDamage`, `damageShield`, `sendDamage` and
`onReceiveDamage` are client throw-stubs; the Hero apply wrapper calls the Unit stub.
The old Hero receive/Unit inflict adapters are retired from the release hook list.

DamageInfo is not DamageResult. The adapter reads its own typed fields and resolves
source UID through the recipient's network host's normalized UID map. It stages a
primitive/string CombatLogLine in EventRing. No display or disk work occurs in the
callback. Main-log runtime acceptance still requires the rebuilt release to load.
Packet-provided amount, critical, attack, affinity and blocker are preserved. JSON
kill, block amount, blocked flag, hit count, shield amount and physical/magic flags
remain null where the packet does not supply those facts. Never invoke DamageResult
getters on this payload or infer missing kills from asynchronous health samples.
Empty skill IDs remain empty. Source/target UID strings preserve attribution even
when the source object has already left the client registry.

The historical attack-combo setter in the table is independently missing on this PTR;
that compatibility issue is not repaired by this damage-ingress change.

**Target frame / Aura `target.*`:** poll `ent.Hero.getTarget` via `CombatLogCache` (soft auto OK). Hard lock is optional chrome — never a release hook and never a bar validity gate. See `docs/NEVER_HOOK_ARITY.md`.

**Encounter / rift:** poll `GetRiftyCache` only. Never hook `set_inBossFight` (inline) or gate/wave drivers. Live rift convict only at `:00`. Combat proof anytime via `probes/FareverProof`.

**P0 cooldown remaining:** observe-loop slot poll of `Skill.getCooldownLeft` (farever-hlx §2.4). CD mutator postfixes are edges / late-join hybrid seed only — not remaining authority.

**MinHook catalog:** Part 2 “New” rows in `MINHOOK_RULES_AND_TELEMETRY.md` that conflict with this file or `NEVER_HOOK_ARITY.md` are superseded. Do not expand release toward a 42-hook pack without a deliberate contract change.

Verification is deliberately orthogonal:

1. `tools/verify_runtime_architecture.py` enforces the release allowlist, rejects duplicate targets, and blocks continuous-state hooks.
2. `bin/hook-authority-replay-test.hxml` replays primitive samples/events through the cache model and `EventRing` and compares the frozen result.
3. `tools/hlx_patch/hlx_contract_audit.py` is run only when hook targets/signatures or the HLB change.
4. One controlled in-game comparison supplies median/p95/p99 frame time and confirms zero event drops.

The telemetry chat hook is compile-gated by `solarflare_telemetry` and must remain absent from `solarflare.hl`.

## Native chat presentation contract — 2026-10-16

The release allowlist is now nine postfixes. The user reports that the chat row says Hidden and blocks typing while its panel stays drawn. Enhanced Chat's supplied source reasserts `ChatBox.set_visible(false)` after `GameApp.update`; the existing ImGui presentation pass is too late for the native render. Add that narrowly scoped presentation pass using a lease acquired by observation, warmed exact-arity setter, current GUI/HUD identity and attachment checks. It does nothing without owned chat hiding and retains no new game state. Current installed C7173926F28C2419DC71662012E8C8C30ACF32B9E7B4DFA351482D9041D57CD4 verifies `GameApp.update(GameApp, f64) -> void` at evidence-only index 12917, hence three postfix slots. The older remote corpus corroborates arity only. Production-path fixtures verify native re-show, replacement and release; actual game visual acceptance remains pending.

## Release acceptance — 2026-09-20

Accepted 2026-09-20 after a live four-class run: HLX installed the then-six combat/UI patches successfully; five combat captures (1,834 ordered events) and resolution ledger PASS. **2026-10-09 contract:** allowlist is **eight** postfixes — prior six plus `ui.Hud.updateVisibility` (NativeHide) and `ent.Hero.set_attackComboCount` (attack-combo step). Continuous values remain sample-owned. **2026-10-11 contract:** allowlist is **seven** postfixes — `ui.BaseUI.startDrag` (`GeauxHooks`) removed: its captured drag element had no consumer after Geaux assignment moved fully into the mod's builder (`GeauxConfig.assignCell`), and it pinned a native UI element. Source backed up under `backups/review-fixes-2026-10-11/`. **2026-10-12 contract:** allowlist is **eight** postfixes — `client.UnitController.startSkillAim` added at the owner's request (`solarflare.aimcast.AimInstantHooks`, event-only, N+1 arity 5, body does nothing unless the "Instant cast" option is on). Evidence: lowered `startSkillAim` (45 ops), `startTargetMode` aim job, `Input` confirm path (`docs/engine-ref/` planner entry `skill.ground_aim`). Source backup `backups/aim-instant-2026-10-12/`. Do not add or remove release hooks without new behavioral evidence and a deliberate contract change.
