# Third-party notices

SolarFlare is built on, and bundles, work by others. This file lists the components that are
identified in this repository, with their license and where to find them.

| Component | Used for | License | Source |
| --- | --- | --- | --- |
| HLX framework (hlx-core) | Mod loader and runtime SolarFlare runs on | MIT | https://github.com/hlx-framework/hlx-core |
| HashLink | Virtual machine and runtime for the compiled mod (`libhl64.dll`, `.hl` bytecode) | MIT | https://github.com/HaxeFoundation/hashlink |
| MinHook | Native hooking in the bundled loader | BSD 2-Clause | https://github.com/TsudaKageyu/minhook |
| Noto Sans and Noto Sans CJK SC | UI fonts (`NotoSans-Regular.ttf`, `NotoSansCJKsc-Regular.otf`) | SIL Open Font License 1.1 | https://github.com/notofonts and https://openfontlicense.org |

The README states that SolarFlare bundles a locally built HLX runtime that exposes the HLX
0.0.10 API surface; it is not claimed to be the byte-identical upstream release artifact.

Haxe libraries used to build the mod (`hlx-runtime`, `hl-imgui`, `format`, `hscript`,
`json2object`, `farever-gamelib`) are separate projects under their own licenses.

Additional UI fonts are bundled in `sfimgui/fonts/` and are used under the terms of their
own licenses.

Game names, assets and trademarks belong to their owners. SolarFlare is an unofficial
fan-made mod and is not affiliated with or endorsed by the developers or publisher of Farever.
