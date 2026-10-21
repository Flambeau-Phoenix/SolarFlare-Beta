# Contributing

Thanks for your interest in SolarFlare. By taking part you agree to the
[code of conduct](CODE_OF_CONDUCT.md).

## Ways to help

- **Report bugs and layout quirks.** The most useful reports say what you did, what you
  expected and what happened, and include your Farever version, SolarFlare version, class
  and weapon. A screenshot helps for UI issues.
- **Suggest improvements.** Describe the situation you are trying to handle (for example "I
  want an aura when X") rather than only the feature.
- **Share aura designs and ideas** in issues or on the Nexus page.

## Code contributions

SolarFlare is source-available for modders, but it is **not currently published under an
open-source license** (see the README's "Rights and credits"). Please open an issue and
discuss a change before writing a large pull request, so we can agree on it and its terms.

If you do send code:

- The Haxe source is in `src/solarflare/`, one folder per system. Build instructions and the
  required libraries are in the README's "For developers" section.
- `SolarFlare_Mod_Install/` and the loose copies at the repository root (`assets/`,
  `sfimgui/`, `sfcursor/`, `solarflare.hl`) are byte-identical; keep them in sync, and
  mirror `src/` into `SolarFlare_HLX_ModSourceFile/src/`.
- Keep the default runtime lean: avoid adding event hooks when bounded sampling can read the
  value instead (see "Eight-hook runtime" in the README).
- Do not commit game files, credentials or personal paths.
- Say what you tested in game and which parts you could not.

Security problems go through [SECURITY.md](SECURITY.md), not public issues.
