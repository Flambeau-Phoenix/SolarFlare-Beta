# Security policy

SolarFlare is a game mod. It loads native code (`libhl64.dll`, `sfimgui.hdll`,
`sfcursor.hdll`) and HashLink bytecode (`solarflare.hl`) into the Farever process through the
HLX framework. That is normal for this kind of mod, but it means you should be careful about
where you get it.

## Get it from official sources only

The only official downloads are:

- this repository's [Releases page](https://github.com/Flambeau-Phoenix/SolarFlare-Beta/releases)
- the [Nexus Mods page](https://www.nexusmods.com/farever/mods/12?tab=files)

Do not use copies from other sites, file-sharing links or messages, even if they claim to be
a newer or "cracked" version. If a build did not come from the sources above, treat it as
untrusted. Each release's zip is attached to its GitHub release.

## What SolarFlare does and does not do

- It reads game state to draw your HUD and writes its own settings under
  `hlx/mods/SolarFlare/` in your game folder (see the README's runtime data paths).
- It is a local mod: it does not need an account, and this repository does not contain any
  server component.
- The full source of the mod is in this repository, so you can review or rebuild it. The
  compiled plugins (`.hdll`) and the bundled runtime DLL are binaries; the plugin and
  runtime sources are not all included here.

## Reporting a problem

- **A vulnerability in SolarFlare, or a suspicious or tampered copy of it:** please report it
  **privately** via GitHub's
  [private vulnerability reporting](https://github.com/Flambeau-Phoenix/SolarFlare-Beta/security/advisories/new).
  Do not post details publicly first.
- **A crash or ordinary bug:** use a normal [issue](https://github.com/Flambeau-Phoenix/SolarFlare-Beta/issues/new/choose).

Please do not include account details, tokens or personal information in reports.

## Out of scope

Vulnerabilities in Farever itself, the HLX framework
([hlx-framework/hlx-core](https://github.com/hlx-framework/hlx-core)) or HashLink should be
reported to their own maintainers.
