![Aura instant cast proc](ghub.gif)

# SolarFlare — v2.3b (Beta)
> **The complete customizable HUD, Aura alert, and combat tracking suite for Farever.**

![Bee + Imp DPS](TrinketBee_Imp.png)

---

### Quick Controls

* **F6** — Show or hide the SolarFlare Control Hub & Builders.
* **Hide All Keybind** — Instantly toggle all SolarFlare HUD overlays on or off (Numpad by default, or Middle Mouse via Resource Tracker settings). The F6 hub remains accessible.
* **Move & Resize** — Unlock any window in its settings. Drag the **sun icon** to reposition; drag the bottom-right corner to resize; click the sun icon to collapse or hide. Re-lock when finished.

---

## Overview

**SolarFlare** is a fully customizable interface and combat awareness mod for **Farever**, built on the [HLX Modding Framework](https://hlx-framework.github.io/) by [laymain](https://github.com/laymain). It gives you complete control over your HUD with four flagship systems:

* **ResourceTracker** — Independent, movable widgets for Health, Shields, Rage, Mana/Spark, Prayers, Combo Points, Conduits, and Target Vitals.
* **Auras** — Dynamic visual alerts, procedural glow rings, countdown timers, and kill/use counters for buffs, procs, cooldowns, and boss mechanics.
* **Geaux Grid** — A dedicated, customizable skill-monitoring display featuring radial cooldown sweeps, charge indicators, and keybind labels.
* **Combat Intelligence** — In-game **Lightsaber** DPS meter (featuring full pet/minion attribution), live **Combat Log**, and the **GetRifty** timer.

---

## Six-Hook Runtime Release

SolarFlare's default runtime has been reduced from **44 hooks to only 6 event hooks**—an 86% reduction in installed hook targets. Continuous values such as health, shields, resources, cooldowns, statuses, stacks, durations, Combo Points, Chaincast, and Conduit state are now read through bounded sampling instead of competing hook paths.

The six remaining hooks are reserved for events that cannot be reconstructed reliably from current state:

1. Skill cast started
2. Skill cast stopped
3. Local skill use for prayer classification
4. Local incoming damage
5. Outgoing damage
6. SolarFlare UI drag start

This release was tested live with **Priest, Mage, Warrior, and Rogue**. Five combat captures recorded 1,834 ordered events with no hook installation failures, event-ring drops, SolarFlare exceptions, crashes, or missing behavior observed. Gameplay was noticeably smoother throughout the four-class test.

Diagnostic hooks are excluded from the normal `solarflare.hl` release and remain available only in the separate telemetry build.

---

## Installation (HLB v2–v6 Compatible)

> [!IMPORTANT]
> SolarFlare bundles its tested local HLX runtime build with support for HashLink bytecode versions **2, 3, 4, 5, and 6**. This includes Farever 0.2.4 / HLB v6 while retaining compatibility with older community mods. The bundled DLL exposes the HLX 0.0.10 API surface but is not claimed to be the byte-identical upstream release artifact.

1. Download **`SolarFlare_Live_v1.4b.zip`**.
2. Extract the contents directly into your **`Farever`** game root directory:

```text
Farever/
├── libhl64.dll                       <- Updated v6 + MinHook native loader
└── hlx/
    ├── config/
    │   └── loader.conf
    ├── loader/
    │   └── hlx-loader.hl             <- Synchronized loader bytecode (PBBDB_i ABI)
    ├── plugins/
    │   └── imgui/
    │       ├── sfimgui.hdll          <- Isolated SolarFlare ImGui plugin
    │       └── fonts/                <- Bundled UI fonts
    └── mods/
        └── solarflare/
            ├── solarflare.hl         <- Mod bytecode
            └── assets/               <- Supplied CDB tables, icons, and atlases
```

3. Launch **Farever** and press **F6**.

> [!NOTE]
> **Plugin Independence:** SolarFlare uses its own `sfimgui.hdll` rather than relying on a shared `imgui64.hdll`. If other installed mods require `imgui64.hdll`, you can leave it in place—both plugins coexist safely without load-order conflicts.

---

## Flagship Features

### 1. ResourceTracker
Build your ideal layout with independently movable, stylable resource and combat displays:

| Tracker | What it displays |
|---|---|
| **Health** | Current and max health, temporary shields, and dynamic alert thresholds. |
| **Rage** | Current rage levels with an optional maximum-resource pulse. |
| **Mana / Spark** | Automatically tracks Mana or Spark according to your active hero class. |
| **Prayers** | Readiness monitors for Smite, Life, and Shield prayers. |
| **Combo Points** | Rogue combo point tracking (0 to 6) with customized pip shapes. |
| **Attack Combo** | Real-time weapon attack-chain tracking with final-hit feedback. |
| **Chaincast** | Chaincast stack accumulation, readiness triggers, and remaining window timers. |
| **Conduits** | Sparkmaster conduit slot monitors and Power stacks (0 to 20). |
| **Current Target** | Target portrait, nameplate, health pool, and boss/elite difficulty badges. |

* **Customization:** Customize bar orientations (horizontal/vertical), borders, transparency, and pip shapes. Test empty, partial, full, and alert states in real time using the built-in previewers.
* **Getting Started:** Press **F6** → **Resources** → **Open Resource Tracker Builder**.

### 2. Auras
Create bespoke visual alerts for any gameplay condition:

* **Trigger Sources:** Health/shield/resource thresholds, skill cooldown readiness, resource affordability, status effects (buffs/debuffs on you or targets), prayers, combo stacks, rift states, and enemy casts.
* **Counters:** Persistent boss, enemy, and skill use counters that survive logout sessions.
* **Visual FX:** Procedural glow rings, custom icon styling, active timers (countdowns/countups), and sound/visual pulses.
* **Quick Start Catalog:** Searchable CastleDB database covering skills, statuses, and 14 bosses with pre-configured ability triggers.
* **Getting Started:** Press **F6** → **Auras** → Enable aura system → **Open Aura Builder**.

### 3. Geaux Skill Grid
A personal skill-monitoring grid designed to keep critical abilities in your field of view:

* **Layouts:** Configurable rows, columns, padding, and slot spacing presets.
* **Visual States:** Radial cooldown sweeps, text countdowns, charge count digits, ready-flashes, and dimmed unavailable states.
* **Ready Glow:** Border sparks and core pulses that highlight when priority abilities come off cooldown.
* **Getting Started:** Press **F6** → **Geaux** → Show Geaux grid → **Open Geaux Builder**. Assign abilities via the searchable skill catalog. *(Note: Geaux is an observation HUD; clicking slots does not cast skills).*

### 4. Combat Tracking & Utilities
* **Lightsaber DPS Meter:** Local combat log parser providing real-time damage-per-second tracking, breakdown tables, and minion damage attribution.
* **Pet & Minion Attribution:** Damage from summons (e.g. *Eternal Flower Heart* bees, *Pocket Hive*, and *Silhouette of Almar* imps) is credited to the parent hero.
* **GetRifty:** Integrated in-game rift clock and timer.
* **Notebook:** In-game scratchpad with full search, page duplication, and automatic persistence.
* **Profiles & Themes:** Save, duplicate, and switch whole-HUD profiles across characters; choose curated color schemes or define your own.

---

## SolarFlare v2.3b

### HUD Window Anchoring, Resizing & Geometry Stability
* **Permanent Window Anchoring Across Relogs:** Solved the issue where repositioned HUD windows moved or drifted to random coordinates upon logging out and back in. Window dragging now sets the dirty state immediately, and positions are saved both upon mouse button release and through a continuous debounced background tick (Layer 1 observe loop).
* **Early Viewport Clamping Guard:** Fixed `clampToViewport` corrupting window positions during game launch or resolution switches before the graphics viewport is fully initialized.
* **Window Sizing & Clipping Resolution:** Fixed graphics clipping (e.g. Geaux action bar partially hidden) when locking windows or switching characters. Locked windows now strictly enforce their calculated content and chrome dimensions every frame via `ImGuiCond.Always`. Switching character profiles reasserts geometry dynamically.
* **Native Resize Grip Elimination:** Eliminated unwanted ImGui edge resize bars on locked windows by strictly assigning `NoMove | NoResize` when locked, while preserving button clicks and right-click context menu access.

### Aura Builder Dropdown Usability & Icon Improvements
* **Expanded Search Catalog Height:** Enlarged the condition subject dropdown from a cramped ~180px to a comfortable 420px height (`480x420`), making searching and browsing catalog entries fast and readable.
* **Single Scrollbar Elimination:** Fixed double scrollbar behavior (nested popup scrollbar + inner child scrollbar) by expanding the child list to fill all available popup space (`vec2(0, 0)`).
* **Status Icon Resolution Fallback Chain:** Implemented a multi-tier fallback lookup (`direct key → CastleDB stem → suffix-strip (_Status, _Proc, etc.) → granted status mapping`), restoring visible icons for character statuses such as `ItemStatus`, `Whetstone_Status`, and procs.
* **Styled Letter Fallback Badges:** Any status without texture art now displays a clean, rounded letter badge tile matching Aura Builder styling rather than an empty invisible gap.


---

# SolarFlare — v2.1b Patch Notes

### What's New

* **Trackable Status Stacks:** Auras can now display and react to live stack counts for buffs, debuffs, and other player statuses.
* **Dedicated Stacks Display:** The Aura Builder now features a spot dedicated entirely to stacks display.
* **Inner Demon Tracking:** Added dedicated tracking for Inner Demon stacks in Auras.
* **Minion DPS Attribution:** Minions are now identified individually, with their damage credited to the owning player in the DPS meter.
* **Enemy Cast Bars:** Enemy unit frames can now display active casts.
* **Custom Cast Bars:** Create and configure personalized cast bars for tracked abilities.
* **Character Profiles:** Profiles can now be assigned to individual characters for automatic switching.

# SolarFlare — v2.2b Patch Notes

### Codebase Optimization & Dead Code Pruning

* **2,923 Lines of Dead Weight Trimmed:** Executed a comprehensive dead-code and duplicate-boilerplate purge across the entire codebase, reducing total source lines from 45,187 to 42,264 while passing `-dce full` build checks.
* **14 Unreferenced Files Deleted:** Completely excised obsolete/dormant files with zero active call sites:
  * UI components: `SortableTable.hx`, `ScriptGuide.hx`, `ProgressHelpers.hx`, `DrawListExt.hx`, `EnhancedBorders.hx`.
  * Builders & Harnesses: `VisualConditionBuilder.hx`, `AuraTestHarness.hx`, `LegacyTriggerConverter.hx`, `LegacyTriggerRuleFactory.hx`.
  * Trackers & Models: `AttackComboTracker.hx`, `DamageObservation.hx`.
  * Empty hook modules: `MageHooks.hx`, `PriestHooks.hx`, `RogueHooks.hx`.
* **Obsolete Hooks & Trampolines Excised:** Stripped 17 uncalled forwarding inline hooks and dead MinHook trampoline handlers from `HealthHooks.hx` (`onSetHealth`, `onSetRage`, `onSetSpark`, `onSetComboPoint`, `onPropagateChainCast`, `onTalentChainCast`, `onPowerConduitStart`, etc.), consolidating strictly around present-loop state sampling.
* **Vanilla HUD DOM Scraper Purged:** Removed legacy fallback reflection code (`applyHudCooldowns`, `walkHudNode`, `ingestHudSlot`, `ingestTypedButton`, `putHudCd`) from `GeauxCache.hx`, establishing direct skill-object inspection as the exclusive authority.
* **Aura Builder & Config Pruned:** Removed unreferenced starter templates, dead builder views, deprecated single-aura export/import routines, and abandoned pack-combiner UI from `AuraBuilder.hx`, `AuraConfig.hx`, and `AuraTemplates.hx`.
* **Centralized CastleDB Resolution:** Replaced duplicate 25-line path resolution loops across `CdbNames`, `CdbUnitNames`, `CdbSummonUnits`, `GeauxCdTable`, and `GeauxTalentTable` with a single unified `ModPaths.findCdbFile()` helper.

---

## SolarFlare v2b

### Six-Hook Runtime Optimization
* **44 → 6 Hooks:** Removed 38 redundant release hooks while retaining all required cast, prayer, damage, and UI-drag events.
* **Single Value Authority:** Health, resources, cooldowns, statuses, class state, and other continuous values are now sample-owned instead of being maintained by duplicate hooks and polling.
* **Lower Runtime Pressure:** Greatly reduced hook dispatch during normal play, producing a noticeable improvement in responsiveness during four-class live testing.
* **Release Hook Guard:** The build verifier now freezes the six allowed release targets, rejects duplicates, and prevents continuous-state hooks from returning accidentally.
* **Replay Verification:** Recorded primitive samples and events are replayed through SolarFlare's caches and ordered event ring as the standard behavioral regression gate.
* **Performance Telemetry:** Runtime export now includes median, p95, and p99 frame time alongside hook, event, queue-depth, and drop counts.

### What's New in SolarFlare
* **Hide All Hotkey:** Toggle all SolarFlare HUD overlays on and off with a single bind (Numpad by default, or Middle Mouse via Resource Tracker settings). The F6 hub and builder windows remain unaffected.
* **Aura Builder Redesign:** Reorganized interface featuring quick-reference condition cards that launch directly into a new aura build.
* **Aura Procedural Glows:** Auras now support optional custom-colored outer glow effects.
* **Aura Countdowns & Countups:** Full timer display with quick-reference auto-configuration buttons populated from CastleDB suggestions.
* **Isolated Input Handling:** Keystrokes typed into SolarFlare text fields (aura names, search bars, ID entry) no longer leak into the game or trigger character abilities.
* **Alt Key Isolation:** Pressing Alt while typing in SolarFlare panels no longer triggers look-lock or closes open windows.
* **Geaux Ready Glow Mode:** Added an animated "Ready glow" option to the Geaux grid featuring a bright core and border sparks tinted to your selected color.
* **Interactive CastleDB Spans:** The CastleDB span recommendation (*"Listed: Xs"*) is now an interactive button that converts the aura to a fixed span and applies the duration immediately.
* **Resource Tracker Refresh:** Modernized navigation sidebar, consolidated settings, and removed redundant per-row Lock/Transparent toggles.

### Bug Fixes
* **Window Bounds:** HUD windows no longer walk off-screen if Farever reclaims cursor capture mid-drag.
* **Held Keys:** Prevented held keyboard keys from sticking when an input text field acquires focus mid-stroke.
* **HudChrome Scaling:** Window frames and borders now scale cleanly without clipping or visual distortion at non-standard resolutions.
* **Performance Optimization:** Reduced per-frame HUD overhead by caching keycode resolutions and removing redundant toast sizing queries.
* **Plugin Independence:** Bundled `sfimgui.hdll` eliminates plugin collisions and DLL load-order issues with other mods.

---

## HLX Core & Runtime Update (v0.0.10-Compatible API)

SolarFlare v1.4b includes its locally built and tested HLX loader stack. It supports HLB bytecode versions **2 through 6**, including **Farever 0.2.4**, and exposes the same 350 exports and 27 `hlp_hlx_*` exports as the official HLX 0.0.10 runtime:

* **Farever 0.2.4 Ready (`HLB v6`):** Full HashLink 2.0 bytecode support (`max_version = 6` with 3rd debug-assignment index). Fixes `Found version 6 while HL supports up to 5`.
* **MinHook 1.3.4 Engine:** Replaced the legacy hand-rolled assembly whitelist in `patching.c` with MinHook. Relocates `CALL`, `JMP`, `Jcc`, and RIP-relative memory offsets cleanly, eliminating `no safe cut found` / `install_patch failed` crashes on tight JIT function prologues (`Player.update`, combat hooks).
* **Legacy Mod Compatibility:** Restored native `std@hlx_construct_enum` export (`PBBD_D`). Fixes the fatal error when loading older mods like **Better Mod Settings** (`module.c:651`).
* **Cross-Mod Message Bus & Registry:** Full native implementation of `hlx_bus_*` and `hlx_kv_*` for inter-mod communication (enables **Minimap**).
* **Synchronized Loader ABI:** Recompiled `hlx-loader.hl` to match `libhl64.dll`'s `PBBDB_i` labeled patch signature, preventing signature mismatch fatal errors.

---

<details>
<summary><b>Previous Version Changelogs (v1.1b – v1.3b)</b></summary>

<br>

### SolarFlare - v1.3b
* **Aura Timers:** Added countdowns and elapsed timers to aura windows.
* **GetRifty:** Integrated Rift clock and event tracker.
* **Icon Glows:** Added icon glow shaders for aura alerts.
* **Create New Aura Hub:** Prominent, theme-aware panel to start auras by type, condition template, or freemode.
* **Searchable Catalogs:** Live CastleDB catalogs for skills, statuses, and 14 boss encounters.
* **Builder Overhaul:** Streamlined separation between templates, options, and live preview rendering.

---

### SolarFlare - v1.2b
* **Minion Attribution System:** Summon damage now credits the parent hero via `ent.Foe.summonOwner` / `summonSourceSkill` (covering *Eternal Flower Heart* bees, *Pocket Hive*, and *Silhouette of Almar* imps).
* **Combat Log Minion Column:** Added sortable **Minion** column in the overlay and exposed minion identities in JSON exports.
* **Damage Deduplication:** Added `noteInflict` to deduplicate outgoing hits against receive-side events, and `DamageObservation` to suppress duplicate events.
* **Enemy Cast Tracking:** Integrated `noteCast` tracking for engaged foes, routing `BaseSkill.doStop` into `EnemyCastCache`.
* **Shared Renderers:** Unified `ChaincastRenderer` and `ConduitOverlay` draw paths to guarantee previews match live HUD rendering.
* **Geaux Charges:** Added skill charge indicators displaying remaining charge counts during cooldown regeneration.
* **Hygiene & Formatting:** Automated skill ID coercion (`coerceSkillId`) across load/save routines, preventing corrupted rotation saves.

---

### SolarFlare - v1.1b
* **Searchable Database Catalogs:** Added catalogs covering 516 units, 955 skills, and all icon sets.
* **Persistent Aura Counters:** Profile-persistent counters that retain values across login/logout cycles.
* **Window Persistence:** Automatic window size and coordinate persistence for the F6 menu hub.
* **Visual Polish:** Highlighted settings cogs in Resource Tracker; cleaned up legacy vector icons and standardized sliders to percentages.
* **Data Isolation:** Saved IDs operate independently from live units, ensuring counters don't reset when unit IDs drift in memory.

</details>

---

## Developer & Build Reference

### Build from Source
```powershell
haxe compile.hxml
```
* Generates `solarflare.hl`.

### Deployment
```powershell
.\deploy.ps1 -FareverRoot "C:\Path\To\Farever"
```

### Runtime Data Paths
| Kind | Path |
|---|---|
| Settings | `hlx/mods/SolarFlare/solarflare.json` |
| ImGui State | `hlx/mods/SolarFlare/imgui.ini` |
| In-game Notebook | `hlx/mods/SolarFlare/notebook.json` |
| Auras | `hlx/mods/SolarFlare/auras/` |
| CastleDB Assets | `hlx/mods/solarflare/assets/cdb/` |
| Icons & Atlases | `hlx/mods/solarflare/assets/icons/` |
| Lightsaber DPS Logs | `hlx/mods/SolarFlare/logs/saber/` |

---

## Feedback & Community

SolarFlare is in active Beta. While the core HUD, Auras, and Geaux systems are thoroughly tested, please report any unexpected behavior or layout quirks. Full source files and compile scripts are provided in this repository for modders and contributors.
