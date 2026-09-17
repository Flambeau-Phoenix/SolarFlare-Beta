# CDB Agent CLI Contract

## Design guarantees

- Source `data.cdb` is read-only.
- No network access is required.
- No GUI dependency.
- Successful machine-readable output is written to stdout.
- Diagnostics are written to stderr.
- JSON is the default output.
- JSONL is available for streaming/list-style commands.
- Exact record retrieval uses `sheet + id`.
- Nested projections support dotted paths.
- Structured filtering supports array paths such as `skills.skill`.
- Freshness is based on an explicit user-assigned stamp plus SHA-256.

## Stable exit codes

| Code | Meaning |
|---:|---|
| 0 | success, current, or no stamp |
| 2 | CLI usage error |
| 3 | requested sheet/record not found |
| 4 | stamped source changed / expected version mismatch |
| 5 | CDB/file/parse failure |
| 6 | invalid query/filter |

## Freshness states

### `current`

The current CDB SHA-256 equals the SHA-256 recorded when the user explicitly stamped that source.

### `changed`

The hash differs, or `--expect-version` does not match the assigned version.

### `unknown`

No trusted stamp exists.

`current` is intentionally not synonymous with "latest upstream Farever release."

## Recommended tool allowlist for agents

Read/discovery:

```text
info
sheets
schema
get
search
filter
refs
status
agent-context
```

Artifact generation:

```text
export
```

Human/version-management action:

```text
stamp
```

Agents should generally not stamp a source unless the workflow explicitly authorizes them to assign the version label.
