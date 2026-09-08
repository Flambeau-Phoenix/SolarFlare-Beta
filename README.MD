
[![SolarFlare v1.1b Update](https://www.youtube.com/watch?v=KIcw0sf8AKA)]

---

# SolarFlare — v1.1 Beta - Current Changelog -

### v1.1b Changelog ###

## Added

* **Searchable Catalogs:** Added searchable catalogs for 516 units, 955 skills, and a complete icon list, with thumbnails displayed where available.
* **Persistent Aura Counters:** Added profile-persistent Aura counters so your counters persist when logging in and out. You can reset them in the aura builder.
* **Always On Option:** Added a radio button to enable "Always On" for auras like unit kill counts.
* **Window Persistence:** Automatic window size and position saving for the F6 menu. You don't have to resize a tiny window each time you login.
* **Aura Window Controls:** Added quick options atop the aura builder for window hide/transparent/always on.
* **Visual Polish:** Added highlighted settings cog icons to the Resource Tracker. Removed the old vector suns everywhere. They were a proof of concept that stuck, same reason sliders were scuffed.

## Changed

* **F6 Menu Layout:** Reorganized menu structure; moved **Show/Hide** and **Lock** options higher up for quicker access.
* **Panel Navigation:** Replaced appearance dropdowns with dedicated button-selected panels.
* **Slider Formatting:** Fraction sliders now display and adjust using percentages.
* **Aura Preview Behavior:** Aura previews now default to a paused state upon opening.
* **UI Clean-up:** Simplified section headings, reduced visual clutter, and improved Resource Tracker spacing with centered previews.
* **Data Isolation:** Saved IDs now operate independently from live units. This means your counters will not lose their configurations because their unit id was lost in the ledger.

## Fixed

* Fixed Geaux texture scaling and size preview rendering. The sliders work now.
* Fixed Aura skill and unit name resolution, including support for unequipped skills.
* Resolved ImGui child-window clipping and preview boundary errors.


---
This mod uses the HLX Modding Framework by https://github.com/laymain found here: https://hlx-framework.github.io/  

SolarFlare is a customizable HUD addon for Farever, built around three main features: **ResourceTracker, Auras, and Geaux**. Keep resources, skill readiness, and visual alerts where you want them on screen.

**Press F6 to show or hide the SolarFlare control panel.** Individual HUD windows have their own visibility settings.

## ResourceTracker

Build your HUD with independently movable resource and combat windows:

| Tracker | What it shows |
|---|---|
| Health | Current and maximum health, plus shield information. |
| Rage | Rage level, with a maximum-resource alert. |
| Mana / Spark | Mana or Spark, according to your active class resource. |
| Prayers | Smite, Life, and Shield prayer readiness. |
| Combo Points | Rogue combo points, from 0 to 6. |
| Attack Combo | Weapon attack-chain progress and final-step feedback. |
| Chaincast | Chaincast stacks, readiness, and remaining time. |
| Conduits | Sparkmaster conduit slots and Power stacks, from 0 to 20. |
| Current Target | Target portrait, name, health, and optional boss/elite badges. |

Each window can be hidden, locked, resized, and made transparent. Appearance options vary by tracker, including bar styles, vertical layouts, and pip shapes. Preview empty, partial, full, and alert states while setting up your layout.

**Start here:** F6 → Resources → Open Resource Tracker Builder. Select a tracker, turn off Hide, and adjust its settings.

## Auras

Create visual alerts for information that matters to your build:

- Health, shield, and class-resource thresholds.
- Skill readiness, cooldowns, and resource affordability.
- Status presence, stack counts, and remaining duration.
- Prayers, Combo Points, Chaincast, Conduits, and attack combos.
- Target conditions, target health, rift state, and specific enemy kills.
- Boss/unit kill counters, skill use counters, etc.

Start from a template or create your own aura. Choose **When It Shows**, then customize **How It Looks**. Use previews and the test tools to check your setup. Import and export auras to share them; advanced users can also use custom expressions.

**Start here:** F6 → Auras → Enable aura system → Open Aura Builder. Enable each aura you want to display, then save.

## Geaux

Build a personal skill-monitoring grid with the icons you want to watch:

- Adjustable rows, columns, spacing, and quick layout presets.
- Searchable skill catalog and drag-and-drop slot arrangement in the builder.
- Cooldown countdowns and radial cooldown indicators.
- Optional keybind labels and group tags.
- Options to dim unavailable skills or hide icons during cooldowns.
- Undo/redo and JSON layout import/export.

**Start here:** F6 → Geaux → Show Geaux grid → Open Geaux Builder. Assign skills from the catalog and arrange your slots.
You can also use Aura to make alerts for single spells if you want.

The gameplay grid is display-only: clicking it does not cast skills. Assignments and slot editing happen in Geaux Builder.

## More features

- **Profiles:** Save, copy, and switch shared HUD setups covering resources, Geaux, Auras, and theme.
- **Themes:** Choose a theme or customize colors.
- **Notebook:** Create, search, copy, and delete in-game notes; pages auto-save.
- **Lightsaber:** Local combat-log DPS meter. Include automatic logging and in-game log viewer.
- **Combat Log:** View skill casts and combat events, with display filters and optional recording.
- **Layout controls:** Save or reset the workspace layout, plus an optional on-screen F6 menu button.
- **Diagnostics:** Optional performance monitor and debugging tools for troubleshooting.

## Install

With HLX installed, copy the release files into your game's `hlx/mods/solarflare/` folder:

```text
hlx/mods/solarflare/
├── solarflare.hl
└── assets/
    ├── cdb/
    │   └── supplied JSON files
    └── icons/
        └── supplied atlases, logos, and icon files
```

Just copy the HLX folder & libhl64.dll to your game folder and you're yet.
Keep the supplied asset folders intact. `atlas.png/json` contains skill and UI artwork; `atlas2.png/json` contains target portraits. Start Farever and press **F6**.

## Move and resize your HUD

Unlock the window in its settings and free your game cursor. Drag the sun icon to move the window; drag its corner to resize. Lock it again when finished. Use each feature's Show or Hide setting to choose which windows remain visible. Sun icon also collapses/hides windows on press.
You can make the window transparent and leave it unlocked to get the best looking setup, then lock the windows. 

## Beta

Some features might be buggy. Some design might not be consistent, like the combat log area. Overall the mod is very usable. Source files are provided if you want to improve this one or make your own.
