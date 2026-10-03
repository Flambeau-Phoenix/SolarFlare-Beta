![Aura instant cast proc](ghub.gif)

# SolarFlare — v2.4b (Beta)
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
├── libhl64.dll                        <- Updated v6 + MinHook native loader
└── hlx/
    ├── config/
    │   └── loader.conf
    ├── loader/
    │   └── hlx-loader.hl              <- Synchronized loader bytecode (PBBDB_i ABI)
    ├── plugins/
    │   ├── sfimgui/
    │   │   ├── sfimgui.hdll           <- Isolated SolarFlare ImGui plugin
    │   │   └── fonts/                 <- Bundled UI fonts
    │   └── sfcursor/
    │       └── sfcursor.hdll          <- Lightweight Win32 cursor confinement plugin
    └── mods/
        └── solarflare/
            ├── solarflare.hl          <- Mod bytecode
            └── assets/                <- Supplied CDB tables, icons, and atlases
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
# Solar Flare v2.5b - Aura Improvements

## [GitHub Release](https://github.com/Flambeau-Phoenix/SolarFlare-Beta/releases/tag/v2.5b)  || [Nexus Mods Release](https://www.nexusmods.com/farever/mods/12)

---

- Single-page builder restored: Conditions, appearance, and preview are together again in the organized WHEN / THEN layout.

- Condition timers: Start a fixed countdown or countup when conditions become true or stop being true. Supports setups such as Summon Demon cast + Inner Demon active → start a 20-second timer.

- Automatic timer visibility: Auras remain visible while their display conditions match or their timer is running. Timer expiry no longer hides an aura whose buff is still active.

- Precise duration entry: Enter timer values directly, including decimals.

- Cleaner timer controls: Timer settings sit beneath the display checkboxes, with nearby Stacks badge position and size controls.

- Static text boxes: Add multiline messages with adjustable font size, wrapping, resizable windows, optional backgrounds, and always-visible or conditional display.
 

- Expanded glow options: Proc sparks, soft bloom, and pulsing bloom, with adjustable strength and inward/outward spread.

- Improved aura panels: Drawing space accounts for icons, countdown labels, stack badges, and glow to prevent clipping.

- Cleaner previews: Removed forced decorations so previews reflect the effects users configure.

- Window interaction preserved: Locked transparent panels stay inert to the hidden cursor, while right-click menus allow unlocking and repositioning with the cursor visible.

- Early preview of Hemorrhage Tool, which tracks all hemorrhage hits and damage so you can test different builds against crit chance for wars gearing decisions.




<details>
<summary>📦 Previous patches</summary>
#  Solar Flare v2.4b Patch Notes 

* **Updated CDB, robust cursor control via sfcursor.hdll, UI polish, and intermittent frame drop fixes.
* **Added sfcursor.hdll Native Plugin: Introduced a lightweight Win32 native wrapper to enforce robust cursor confinement and window focus synchronization via ClipCursor and MapWindowPoints.
* **Multi-Monitor Drift Fix: Resolved issues with the mouse escaping the game window or clicking outside client bounds during active ImGui overlay menus in borderless windowed mode.
* **CDB & Atlas Updates: Updated atlas files and data.cdb references across the mod to match the new game patch.
* **UI Polish: Fixed a bug in the Lightsaber and Combat Log UI where a rogue scrollbar appeared, blocking the close window title bar button and the window resize corner piece.
* **Performance & Cursor Overhaul: Fixed intermittent frame drops by removing experimental telemetry features, correcting unclosed sfimgui panels (missing end() calls), and fully migrating cursor control away from split game/sfimgui logic over to sfcursor.hdll.

## v1.1.0
- what changed

</details>


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
