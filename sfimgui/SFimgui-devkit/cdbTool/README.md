# CDB Agent CLI

A deterministic, **stdlib-only** CLI for querying Farever/CastleDB `data.cdb` files from coding agents, shell scripts, MCP tools, CI jobs, and mod-generation workflows.

The goal is simple:

> Ask for exactly the game data a mod needs, return machine-readable data, and prove which CDB build it came from.

This CLI is intentionally separate from any LLM. Agents call it as a trusted data tool.

## Why this is useful

Your GUI is ideal for discovery. Once you know what a mod needs, the CLI is much better for repeatable extraction:

```text
discover in GUI
      ↓
identify exact IDs / fields / relationships
      ↓
agent invokes CLI
      ↓
small deterministic JSON payload
      ↓
mod code / generated lookup table
```

That prevents agents from loading a 5 MB database into context just to answer one question.

## No dependencies

Only Python 3.10+ is required.

```powershell
python cdb_agent.py --cdb ">>>PATHTOCDB<<<<<<" info --pretty
```

## Core commands

```text
info           database fingerprint + stats
sheets         list available categories
schema         inspect one category's CastleDB schema
get            retrieve one exact row by stable ID
search         free-text / regex search
filter         structured field filtering
refs           outgoing and reverse reference lookup
export         write exact curated records to JSON/JSONL
stamp          assign a known game/API version to an exact CDB
status         verify whether the CDB still matches that stamp
agent-context  small database context payload for an agent
```

---

# Examples for Farever modding

## Exact monster/unit lookup

```powershell
python cdb_agent.py --cdb data.cdb get unit DemonSuperElite_Fairy --pretty
```

Only return fields an agent needs:

```powershell
python cdb_agent.py --cdb data.cdb get unit DemonSuperElite_Fairy `
  --field id `
  --field texts.name `
  --field type `
  --field skills `
  --pretty
```

## Exact skill lookup

```powershell
python cdb_agent.py --cdb data.cdb get skill PhysicalBlock `
  --field id `
  --field texts.name `
  --field cooldown `
  --field steps `
  --pretty
```

## Search names or IDs

```powershell
python cdb_agent.py --cdb data.cdb search Nightqueen --sheet unit --pretty
```

Restrict search to a field:

```powershell
python cdb_agent.py --cdb data.cdb search FireWall --sheet skill --field id --pretty
```

Regex:

```powershell
python cdb_agent.py --cdb data.cdb search "^SuperElite.*Fire" --sheet skill --field id --regex --pretty
```

## Find unfinished/test content

```powershell
python cdb_agent.py --cdb data.cdb filter skill `
  --where id regex "(TODO|TEST|UNUSED|WIP|DEBUG)" `
  --logic or `
  --summary `
  --pretty
```

You can repeat clauses:

```powershell
python cdb_agent.py --cdb data.cdb filter item `
  --where id contains test `
  --where texts.name contains TODO `
  --logic or `
  --summary `
  --pretty
```

## Find units that reference a skill

Array paths are supported:

```powershell
python cdb_agent.py --cdb data.cdb filter unit `
  --where skills.skill contains SuperEliteDemon_FireWall `
  --summary `
  --pretty
```

## Resolve outgoing references from a unit

Only check whether string IDs in this unit match known skill IDs:

```powershell
python cdb_agent.py --cdb data.cdb refs `
  --sheet unit `
  --id DemonSuperElite_Fairy `
  --target-sheet skill `
  --pretty
```

## Reverse lookup: who references this skill?

```powershell
python cdb_agent.py --cdb data.cdb refs `
  --to skill:SuperEliteDemon_FireWall `
  --scan-sheet unit `
  --pretty
```

This is particularly valuable for deciding whether a spell/skill is actually unused.

## Export only exact records

```powershell
python cdb_agent.py --cdb data.cdb export `
  --sheet skill `
  --id PhysicalBlock `
  --id SuperEliteDemon_FireWall `
  --output selected_skills.json `
  --pretty-file `
  --pretty
```

Export a field-projected lookup:

```powershell
python cdb_agent.py --cdb data.cdb export `
  --sheet skill `
  --field id `
  --field texts.name `
  --field cooldown `
  --output skill_lookup.json `
  --pretty-file
```

---

# Freshness / "up to date" tracking

The CLI deliberately **does not guess** whether a CDB is the newest Farever build.

Instead, when you know a CDB corresponds to a particular game/API version, stamp it:

```powershell
python cdb_agent.py --cdb data.cdb stamp `
  --version "Farever-2026.09.12" `
  --label "new public API build" `
  --pretty
```

This creates:

```text
data.cdb.agent-stamp.json
```

The stamp records:

- your assigned version
- optional label/notes
- file size
- modification timestamp
- SHA-256
- stamping time

Later:

```powershell
python cdb_agent.py --cdb data.cdb status --pretty
```

Possible states:

```text
current
changed
unknown
```

`current` means the SHA-256 still matches the file you explicitly stamped.

`changed` means the CDB bytes or expected assigned version changed.

`unknown` means no trusted stamp exists.

This is safer for agents than using modification dates as proof of freshness.

### Exit codes

```text
0 = success/current/unknown
2 = CLI usage error
3 = sheet/record not found
4 = stamped CDB changed/stale
5 = I/O or parse failure
6 = invalid query/filter
```

That means an agent or PowerShell script can do:

```powershell
python cdb_agent.py --cdb data.cdb status > status.json
if ($LASTEXITCODE -eq 4) {
    Write-Host "CDB changed - regenerate mod data."
}
```

---

# Agent context

Instead of making an agent inspect the database itself:

```powershell
python cdb_agent.py --cdb data.cdb agent-context --pretty
```

returns a compact description of key sheets plus the fingerprint/freshness state.

You can narrow it:

```powershell
python cdb_agent.py --cdb data.cdb agent-context `
  --sheet unit `
  --sheet skill `
  --sample 3 `
  --pretty
```

---

# Recommended agent policy

Give coding agents a rule similar to:

```text
Farever game data is authoritative only when retrieved through cdb_agent.py.

Before changing code that depends on game IDs, skills, units, items, cooldowns,
or CDB references:

1. Run `cdb_agent.py status`.
2. If state is changed, do not assume old extracted data is current.
3. Use `get`, `filter`, `search`, or `refs` to retrieve only the required records.
4. Prefer exact IDs after discovery.
5. Do not paste or load the complete data.cdb into context.
6. Record any generated mod lookup data with the CDB SHA-256 that produced it.
```

This keeps token/context usage low and makes mod data reproducible.
