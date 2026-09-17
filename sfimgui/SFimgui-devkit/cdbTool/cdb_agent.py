#!/usr/bin/env python3
"""
CDB Agent CLI
A deterministic, stdlib-only CastleDB/Farever data query tool designed for agents.

Stdout is reserved for command results.
Diagnostics/errors go to stderr.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable, Iterator

TOOL_VERSION = "1.0.0"

EXIT_OK = 0
EXIT_USAGE = 2
EXIT_NOT_FOUND = 3
EXIT_CHANGED = 4
EXIT_IO = 5
EXIT_QUERY = 6

DEFAULT_STAMP_SUFFIX = ".agent-stamp.json"


def eprint(*args: Any) -> None:
    print(*args, file=sys.stderr)


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def compact(value: Any, limit: int = 240) -> str:
    if value is None:
        return ""
    if isinstance(value, (str, int, float, bool)):
        text = str(value)
    else:
        text = json.dumps(value, ensure_ascii=False, separators=(",", ":"))
    text = text.replace("\n", "\\n")
    if len(text) > limit:
        return text[: limit - 1] + "…"
    return text


def row_id(row: dict[str, Any]) -> str:
    for key in ("id", "ID", "Id", "key"):
        value = row.get(key)
        if value is not None:
            return str(value)
    return ""


def display_name(row: dict[str, Any]) -> str:
    for key in ("name", "title", "label"):
        value = row.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    texts = row.get("texts")
    if isinstance(texts, dict):
        for key in ("name", "title", "label"):
            value = texts.get(key)
            if isinstance(value, str) and value.strip():
                return value.strip()
    return ""


def iter_paths(value: Any, prefix: str = "") -> Iterator[tuple[str, Any]]:
    if isinstance(value, dict):
        if not value:
            yield prefix, value
        for key, child in value.items():
            path = f"{prefix}.{key}" if prefix else str(key)
            yield from iter_paths(child, path)
    elif isinstance(value, list):
        if not value:
            yield prefix, value
        for i, child in enumerate(value):
            path = f"{prefix}[{i}]" if prefix else f"[{i}]"
            yield from iter_paths(child, path)
    else:
        yield prefix, value


_PART_RE = re.compile(r"([^.[]+)|\[(\d+)\]")


def get_path(value: Any, path: str) -> Any:
    """Exact dotted/indexed lookup: texts.name, skills[0].skill."""
    cur = value
    for match in _PART_RE.finditer(path):
        key, index = match.groups()
        if key is not None:
            if not isinstance(cur, dict) or key not in cur:
                return None
            cur = cur[key]
        else:
            if not isinstance(cur, list):
                return None
            idx = int(index)
            if idx >= len(cur):
                return None
            cur = cur[idx]
    return cur


def values_for_path(value: Any, path: str) -> list[Any]:
    """
    Array-aware path lookup:
      skills.skill -> every skill value inside the skills array
      texts.name   -> one value
    """
    parts = path.split(".") if path else []
    current = [value]
    for part in parts:
        next_values: list[Any] = []
        array_index = None
        m = re.fullmatch(r"([^\[]+)(?:\[(\d+)\])?", part)
        if not m:
            return []
        key, idx_text = m.groups()
        if idx_text is not None:
            array_index = int(idx_text)

        for item in current:
            candidates = item if isinstance(item, list) else [item]
            for candidate in candidates:
                if not isinstance(candidate, dict) or key not in candidate:
                    continue
                child = candidate[key]
                if array_index is not None:
                    if isinstance(child, list) and array_index < len(child):
                        next_values.append(child[array_index])
                elif isinstance(child, list):
                    next_values.extend(child)
                else:
                    next_values.append(child)
        current = next_values
    return current


@dataclass(slots=True)
class Sheet:
    name: str
    raw: dict[str, Any]

    @property
    def rows(self) -> list[dict[str, Any]]:
        lines = self.raw.get("lines") or []
        return [x for x in lines if isinstance(x, dict)]

    @property
    def columns(self) -> list[dict[str, Any]]:
        cols = self.raw.get("columns") or []
        return [x for x in cols if isinstance(x, dict)]


class CDB:
    def __init__(self, path: str | Path):
        self.path = Path(path).resolve()
        with self.path.open("r", encoding="utf-8-sig") as f:
            self.data = json.load(f)
        if not isinstance(self.data, dict) or not isinstance(self.data.get("sheets"), list):
            raise ValueError("File is not a CastleDB JSON database (missing top-level 'sheets').")
        self.sheets: dict[str, Sheet] = {}
        for raw in self.data["sheets"]:
            if isinstance(raw, dict) and raw.get("name"):
                name = str(raw["name"])
                self.sheets[name] = Sheet(name, raw)

    def sheet(self, name: str) -> Sheet:
        if name not in self.sheets:
            raise KeyError(name)
        return self.sheets[name]

    def find_row(self, sheet_name: str, record_id: str) -> tuple[int, dict[str, Any]] | None:
        sheet = self.sheet(sheet_name)
        for idx, row in enumerate(sheet.rows):
            if row_id(row) == record_id:
                return idx, row
        return None

    def populated_sheets(self) -> list[Sheet]:
        return [s for s in self.sheets.values() if s.rows]


def hash_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def fingerprint(path: Path, include_hash: bool = True) -> dict[str, Any]:
    st = path.stat()
    out = {
        "path": str(path.resolve()),
        "size": st.st_size,
        "mtime_ns": st.st_mtime_ns,
        "mtime_utc": datetime.fromtimestamp(st.st_mtime, tz=timezone.utc).isoformat(),
    }
    if include_hash:
        out["sha256"] = hash_file(path)
    return out


def stamp_path_for(cdb_path: Path) -> Path:
    return cdb_path.with_name(cdb_path.name + DEFAULT_STAMP_SUFFIX)


def emit(value: Any, args: argparse.Namespace) -> None:
    fmt = getattr(args, "format", "json")
    pretty = getattr(args, "pretty", False)

    if fmt == "jsonl":
        if isinstance(value, list):
            for item in value:
                print(json.dumps(item, ensure_ascii=False, separators=(",", ":")))
        else:
            print(json.dumps(value, ensure_ascii=False, separators=(",", ":")))
        return

    if fmt == "text":
        if isinstance(value, list):
            for item in value:
                if isinstance(item, dict):
                    print("\t".join(str(v) for v in item.values()))
                else:
                    print(item)
        elif isinstance(value, dict):
            for k, v in value.items():
                print(f"{k}\t{compact(v, 10000)}")
        else:
            print(value)
        return

    print(json.dumps(value, ensure_ascii=False, indent=2 if pretty else None))


def project_row(row: dict[str, Any], fields: list[str] | None) -> dict[str, Any]:
    if not fields:
        return row
    out: dict[str, Any] = {}
    for field in fields:
        vals = values_for_path(row, field)
        if not vals:
            out[field] = None
        elif len(vals) == 1:
            out[field] = vals[0]
        else:
            out[field] = vals
    return out


def summary_record(sheet: str, index: int, row: dict[str, Any]) -> dict[str, Any]:
    return {
        "sheet": sheet,
        "row_index": index,
        "id": row_id(row),
        "name": display_name(row),
    }


def searchable_pairs(row: dict[str, Any]) -> list[tuple[str, str]]:
    return [(path, compact(value, 100000)) for path, value in iter_paths(row)]


def value_match(actual: Any, op: str, expected: str, case_sensitive: bool = False) -> bool:
    if op in ("exists", "missing"):
        exists = actual is not None and actual != "" and actual != []
        return exists if op == "exists" else not exists

    text = compact(actual, 100000)
    left = text if case_sensitive else text.casefold()
    right = expected if case_sensitive else expected.casefold()

    if op == "contains":
        return right in left
    if op == "not-contains":
        return right not in left
    if op == "equals":
        return left == right
    if op == "not-equals":
        return left != right
    if op == "starts":
        return left.startswith(right)
    if op == "ends":
        return left.endswith(right)
    if op == "regex":
        try:
            return re.search(expected, text, 0 if case_sensitive else re.IGNORECASE) is not None
        except re.error as exc:
            raise ValueError(f"invalid regex: {exc}") from exc
    if op == "not-regex":
        try:
            return re.search(expected, text, 0 if case_sensitive else re.IGNORECASE) is None
        except re.error as exc:
            raise ValueError(f"invalid regex: {exc}") from exc

    if op in ("gt", "ge", "lt", "le"):
        try:
            a = float(actual)
            b = float(expected)
        except (TypeError, ValueError):
            return False
        return {
            "gt": a > b,
            "ge": a >= b,
            "lt": a < b,
            "le": a <= b,
        }[op]

    raise ValueError(f"unsupported operator: {op}")


def row_where_match(
    row: dict[str, Any],
    clauses: list[list[str]],
    logic: str,
    case_sensitive: bool,
) -> bool:
    if not clauses:
        return True

    results: list[bool] = []
    for field, op, expected in clauses:
        vals = values_for_path(row, field)

        if op == "missing":
            matched = not vals
        elif op == "exists":
            matched = bool(vals)
        elif not vals:
            matched = False
        elif op in ("not-contains", "not-equals", "not-regex"):
            matched = all(value_match(v, op, expected, case_sensitive) for v in vals)
        else:
            matched = any(value_match(v, op, expected, case_sensitive) for v in vals)
        results.append(matched)

    return all(results) if logic == "and" else any(results)


def command_info(db: CDB, args: argparse.Namespace) -> int:
    fp = fingerprint(db.path, include_hash=not args.no_hash)
    result = {
        "tool_version": TOOL_VERSION,
        "source": fp,
        "sheet_count": len(db.sheets),
        "populated_sheet_count": len(db.populated_sheets()),
        "total_rows": sum(len(s.rows) for s in db.sheets.values()),
        "custom_type_count": len(db.data.get("customTypes") or []),
    }
    emit(result, args)
    return EXIT_OK


def command_sheets(db: CDB, args: argparse.Namespace) -> int:
    result = []
    needle = (args.match or "").casefold()
    for sheet in db.sheets.values():
        if args.populated and not sheet.rows:
            continue
        if needle and needle not in sheet.name.casefold():
            continue
        result.append({
            "name": sheet.name,
            "rows": len(sheet.rows),
            "columns": len(sheet.columns),
            "child_sheet": "@" in sheet.name,
        })
    result.sort(key=lambda x: x["name"].casefold())
    emit(result, args)
    return EXIT_OK


def command_schema(db: CDB, args: argparse.Namespace) -> int:
    try:
        sheet = db.sheet(args.sheet)
    except KeyError:
        return fail_not_found(f"sheet not found: {args.sheet}", args)
    result = {
        "name": sheet.name,
        "rows": len(sheet.rows),
        "columns": sheet.columns,
        "props": sheet.raw.get("props") or {},
        "separators": sheet.raw.get("separators") or [],
    }
    emit(result, args)
    return EXIT_OK


def command_get(db: CDB, args: argparse.Namespace) -> int:
    try:
        found = db.find_row(args.sheet, args.id)
    except KeyError:
        return fail_not_found(f"sheet not found: {args.sheet}", args)

    if found is None:
        return fail_not_found(f"record not found: {args.sheet}:{args.id}", args)

    index, row = found
    record = {
        **summary_record(args.sheet, index, row),
        "data": project_row(row, args.field),
    }
    emit(record, args)
    return EXIT_OK


def free_search_match(
    row: dict[str, Any],
    query: str,
    field: str | None,
    regex: bool,
    case_sensitive: bool,
) -> tuple[bool, str, str]:
    pairs = searchable_pairs(row)
    if field:
        wanted = field.casefold()
        pairs = [
            (p, text)
            for p, text in pairs
            if p.casefold() == wanted
            or p.casefold().endswith("." + wanted)
            or re.sub(r"\[\d+\]", "", p.casefold()).endswith("." + wanted)
        ]

    for path, text in pairs:
        if regex:
            try:
                if re.search(query, text, 0 if case_sensitive else re.IGNORECASE):
                    return True, path, text
            except re.error as exc:
                raise ValueError(f"invalid regex: {exc}") from exc
        else:
            a = text if case_sensitive else text.casefold()
            b = query if case_sensitive else query.casefold()
            if b in a:
                return True, path, text
    return False, "", ""


def command_search(db: CDB, args: argparse.Namespace) -> int:
    if args.sheet:
        missing = [name for name in args.sheet if name not in db.sheets]
        if missing:
            return fail_not_found(f"sheet not found: {missing[0]}", args)
        sheets = [db.sheets[name] for name in args.sheet]
    else:
        sheets = db.populated_sheets()

    out = []
    for sheet in sheets:
        for index, row in enumerate(sheet.rows):
            matched, path, preview = free_search_match(
                row, args.query, args.field, args.regex, args.case_sensitive
            )
            if not matched:
                continue
            item = {
                **summary_record(sheet.name, index, row),
                "match_field": path,
                "preview": preview[: args.preview],
            }
            if args.include_data:
                item["data"] = project_row(row, args.project)
            out.append(item)
            if args.limit and len(out) >= args.limit:
                emit(out, args)
                return EXIT_OK

    emit(out, args)
    return EXIT_OK


def command_filter(db: CDB, args: argparse.Namespace) -> int:
    try:
        sheet = db.sheet(args.sheet)
    except KeyError:
        return fail_not_found(f"sheet not found: {args.sheet}", args)

    clauses = args.where or []
    out = []
    for index, row in enumerate(sheet.rows):
        try:
            matched = row_where_match(row, clauses, args.logic, args.case_sensitive)
        except ValueError as exc:
            return fail_query(str(exc), args)
        if not matched:
            continue
        if args.summary:
            item = summary_record(sheet.name, index, row)
        else:
            item = {
                **summary_record(sheet.name, index, row),
                "data": project_row(row, args.field),
            }
        out.append(item)
        if args.limit and len(out) >= args.limit:
            break

    emit(out, args)
    return EXIT_OK


def extract_strings(value: Any, prefix: str = "") -> Iterator[tuple[str, str]]:
    for path, v in iter_paths(value, prefix):
        if isinstance(v, str) and v:
            yield path, v


def command_refs(db: CDB, args: argparse.Namespace) -> int:
    # Outgoing references from one exact record.
    if args.sheet and args.id:
        if args.sheet not in db.sheets:
            return fail_not_found(f"sheet not found: {args.sheet}", args)
        found = db.find_row(args.sheet, args.id)
        if found is None:
            return fail_not_found(f"record not found: {args.sheet}:{args.id}", args)
        _, row = found

        target_names = args.target_sheet or [name for name, s in db.sheets.items() if s.rows]
        target_ids: dict[str, set[str]] = {
            name: {row_id(r) for r in db.sheets[name].rows if row_id(r)}
            for name in target_names
            if name in db.sheets
        }
        out = []
        for path, text in extract_strings(row):
            for target_sheet, ids in target_ids.items():
                if text in ids:
                    out.append({
                        "direction": "outgoing",
                        "source_sheet": args.sheet,
                        "source_id": args.id,
                        "path": path,
                        "target_sheet": target_sheet,
                        "target_id": text,
                    })
        emit(out, args)
        return EXIT_OK

    # Reverse references to target "sheet:id".
    if args.to:
        if ":" not in args.to:
            return fail_query("--to must be SHEET:ID", args)
        target_sheet, target_id = args.to.split(":", 1)
        if target_sheet not in db.sheets:
            return fail_not_found(f"sheet not found: {target_sheet}", args)
        if db.find_row(target_sheet, target_id) is None:
            return fail_not_found(f"record not found: {target_sheet}:{target_id}", args)

        scan_names = args.scan_sheet or [name for name, s in db.sheets.items() if s.rows]
        out = []
        for source_name in scan_names:
            if source_name not in db.sheets:
                continue
            for index, row in enumerate(db.sheets[source_name].rows):
                for path, text in extract_strings(row):
                    if text == target_id:
                        out.append({
                            "direction": "incoming",
                            "source_sheet": source_name,
                            "source_row_index": index,
                            "source_id": row_id(row),
                            "source_name": display_name(row),
                            "path": path,
                            "target_sheet": target_sheet,
                            "target_id": target_id,
                        })
                        if args.limit and len(out) >= args.limit:
                            emit(out, args)
                            return EXIT_OK
        emit(out, args)
        return EXIT_OK

    return fail_query("refs requires either --sheet SHEET --id ID or --to SHEET:ID", args)


def command_export(db: CDB, args: argparse.Namespace) -> int:
    missing = [s for s in args.sheet if s not in db.sheets]
    if missing:
        return fail_not_found(f"sheet not found: {missing[0]}", args)

    categories: dict[str, Any] = {}
    for sheet_name in args.sheet:
        rows = db.sheets[sheet_name].rows
        if args.id:
            wanted = set(args.id)
            rows = [r for r in rows if row_id(r) in wanted]
        if args.where:
            rows = [
                r for r in rows
                if row_where_match(r, args.where, args.logic, args.case_sensitive)
            ]
        if args.field:
            rows = [project_row(r, args.field) for r in rows]
        categories[sheet_name] = rows

    payload = {
        "source": fingerprint(db.path, include_hash=True),
        "tool_version": TOOL_VERSION,
        "categories": categories,
    }

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)

    if args.output_format == "jsonl":
        with output.open("w", encoding="utf-8") as f:
            for sheet_name, rows in categories.items():
                for row in rows:
                    f.write(json.dumps({
                        "sheet": sheet_name,
                        "data": row,
                    }, ensure_ascii=False) + "\n")
    else:
        with output.open("w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2 if args.pretty_file else None)

    emit({
        "ok": True,
        "output": str(output.resolve()),
        "categories": {k: len(v) for k, v in categories.items()},
    }, args)
    return EXIT_OK


def command_stamp(db: CDB, args: argparse.Namespace) -> int:
    stamp_file = Path(args.stamp_file).resolve() if args.stamp_file else stamp_path_for(db.path)
    data = {
        "schema": "farever.cdb-agent-stamp.v1",
        "created_utc": now_iso(),
        "tool_version": TOOL_VERSION,
        "version": args.version,
        "label": args.label or "",
        "notes": args.notes or "",
        "source": fingerprint(db.path, include_hash=True),
    }
    stamp_file.parent.mkdir(parents=True, exist_ok=True)
    with stamp_file.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    emit({
        "state": "stamped",
        "stamp_file": str(stamp_file),
        **data,
    }, args)
    return EXIT_OK


def command_status(db: CDB, args: argparse.Namespace) -> int:
    stamp_file = Path(args.stamp_file).resolve() if args.stamp_file else stamp_path_for(db.path)
    current = fingerprint(db.path, include_hash=True)

    if not stamp_file.exists():
        result = {
            "state": "unknown",
            "reason": "no_stamp",
            "source": current,
            "stamp_file": str(stamp_file),
        }
        emit(result, args)
        return EXIT_OK

    try:
        stamp = json.loads(stamp_file.read_text(encoding="utf-8"))
    except Exception as exc:
        return fail_io(f"could not read stamp: {exc}", args)

    stamped_source = stamp.get("source") or {}
    same_hash = bool(stamped_source.get("sha256")) and stamped_source.get("sha256") == current["sha256"]
    version_ok = args.expect_version is None or str(stamp.get("version")) == str(args.expect_version)

    if same_hash and version_ok:
        state = "current"
        reason = "sha256_match"
        code = EXIT_OK
    elif not same_hash:
        state = "changed"
        reason = "sha256_mismatch"
        code = EXIT_CHANGED
    else:
        state = "changed"
        reason = "version_mismatch"
        code = EXIT_CHANGED

    result = {
        "state": state,
        "reason": reason,
        "stamp_file": str(stamp_file),
        "assigned_version": stamp.get("version"),
        "assigned_label": stamp.get("label", ""),
        "current_source": current,
        "stamped_source": stamped_source,
    }
    if args.expect_version is not None:
        result["expected_version"] = args.expect_version

    emit(result, args)
    return code


def command_agent_context(db: CDB, args: argparse.Namespace) -> int:
    """Compact deterministic context payload for an LLM/agent."""
    result: dict[str, Any] = {
        "source": fingerprint(db.path, include_hash=not args.no_hash),
        "tool": {"name": "cdb-agent", "version": TOOL_VERSION},
        "sheets": [],
    }

    selected = args.sheet or ["unit", "skill", "item"]
    for sheet_name in selected:
        if sheet_name not in db.sheets:
            continue
        sheet = db.sheets[sheet_name]
        item = {
            "name": sheet_name,
            "rows": len(sheet.rows),
            "columns": [c.get("name") for c in sheet.columns if c.get("name")],
        }
        if args.sample > 0:
            item["samples"] = [
                {
                    "id": row_id(r),
                    "name": display_name(r),
                    "type": r.get("type"),
                }
                for r in sheet.rows[: args.sample]
            ]
        result["sheets"].append(item)

    stamp_file = Path(args.stamp_file).resolve() if args.stamp_file else stamp_path_for(db.path)
    if stamp_file.exists():
        try:
            stamp = json.loads(stamp_file.read_text(encoding="utf-8"))
            result["assigned_version"] = stamp.get("version")
            result["assigned_label"] = stamp.get("label")
            result["stamp_sha256"] = (stamp.get("source") or {}).get("sha256")
            result["freshness"] = (
                "current"
                if result["stamp_sha256"] == result["source"].get("sha256")
                else "changed"
            )
        except Exception:
            result["freshness"] = "unknown"
    else:
        result["freshness"] = "unknown"

    emit(result, args)
    return EXIT_OK


def fail_not_found(message: str, args: argparse.Namespace) -> int:
    eprint(message)
    if getattr(args, "errors_as_json", False):
        print(json.dumps({"ok": False, "error": "not_found", "message": message}))
    return EXIT_NOT_FOUND


def fail_query(message: str, args: argparse.Namespace) -> int:
    eprint(message)
    if getattr(args, "errors_as_json", False):
        print(json.dumps({"ok": False, "error": "query_error", "message": message}))
    return EXIT_QUERY


def fail_io(message: str, args: argparse.Namespace) -> int:
    eprint(message)
    if getattr(args, "errors_as_json", False):
        print(json.dumps({"ok": False, "error": "io_error", "message": message}))
    return EXIT_IO


def add_output_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--format", choices=("json", "jsonl", "text"), default="json")
    parser.add_argument("--pretty", action="store_true", help="Pretty-print JSON output")
    parser.add_argument("--errors-as-json", action="store_true", help="Emit structured errors to stdout")


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="cdb-agent",
        description="Agent-friendly CastleDB/Farever data query CLI",
    )
    p.add_argument("--cdb", required=True, help="Path to data.cdb")
    p.add_argument("--version", action="version", version=f"%(prog)s {TOOL_VERSION}")

    sub = p.add_subparsers(dest="command", required=True)

    info = sub.add_parser("info", help="Database fingerprint and high-level stats")
    info.add_argument("--no-hash", action="store_true")
    add_output_args(info)

    sheets = sub.add_parser("sheets", help="List categories/sheets")
    sheets.add_argument("--populated", action="store_true")
    sheets.add_argument("--match", help="Name substring")
    add_output_args(sheets)

    schema = sub.add_parser("schema", help="Inspect one sheet schema")
    schema.add_argument("sheet")
    add_output_args(schema)

    get = sub.add_parser("get", help="Get one exact record by stable ID")
    get.add_argument("sheet")
    get.add_argument("id")
    get.add_argument("--field", action="append", help="Project dotted field; repeatable")
    add_output_args(get)

    search = sub.add_parser("search", help="Free search across one or more sheets")
    search.add_argument("query")
    search.add_argument("--sheet", action="append", help="Restrict sheet; repeatable")
    search.add_argument("--field", help="Restrict matching to a field/leaf name")
    search.add_argument("--regex", action="store_true")
    search.add_argument("--case-sensitive", action="store_true")
    search.add_argument("--limit", type=int, default=100)
    search.add_argument("--preview", type=int, default=240)
    search.add_argument("--include-data", action="store_true")
    search.add_argument("--project", action="append", help="Projected field when --include-data is set")
    add_output_args(search)

    filt = sub.add_parser("filter", help="Structured filtering within one sheet")
    filt.add_argument("sheet")
    filt.add_argument(
        "--where",
        nargs=3,
        action="append",
        metavar=("FIELD", "OP", "VALUE"),
        help="Repeatable. Ops: contains, not-contains, equals, not-equals, starts, ends, regex, not-regex, exists, missing, gt, ge, lt, le",
    )
    filt.add_argument("--logic", choices=("and", "or"), default="and")
    filt.add_argument("--case-sensitive", action="store_true")
    filt.add_argument("--field", action="append", help="Project dotted field; repeatable")
    filt.add_argument("--summary", action="store_true", help="Return only sheet/index/id/name")
    filt.add_argument("--limit", type=int, default=0)
    add_output_args(filt)

    refs = sub.add_parser("refs", help="Resolve outgoing or incoming ID references")
    refs.add_argument("--sheet")
    refs.add_argument("--id")
    refs.add_argument("--target-sheet", action="append", help="Outgoing: target sheet to resolve; repeatable")
    refs.add_argument("--to", help="Reverse lookup target, e.g. skill:PhysicalBlock")
    refs.add_argument("--scan-sheet", action="append", help="Reverse lookup source sheet; repeatable")
    refs.add_argument("--limit", type=int, default=500)
    add_output_args(refs)

    export = sub.add_parser("export", help="Write exact curated records/categories to disk")
    export.add_argument("--sheet", action="append", required=True)
    export.add_argument("--id", action="append", help="Keep exact IDs; repeatable")
    export.add_argument(
        "--where",
        nargs=3,
        action="append",
        metavar=("FIELD", "OP", "VALUE"),
    )
    export.add_argument("--logic", choices=("and", "or"), default="and")
    export.add_argument("--case-sensitive", action="store_true")
    export.add_argument("--field", action="append", help="Project fields")
    export.add_argument("--output", required=True)
    export.add_argument("--output-format", choices=("json", "jsonl"), default="json")
    export.add_argument("--pretty-file", action="store_true")
    add_output_args(export)

    stamp = sub.add_parser("stamp", help="Assign a known Farever/API version to this exact CDB fingerprint")
    stamp.add_argument("--version", required=True, help="Your build/API version label")
    stamp.add_argument("--label", help="Human-friendly label")
    stamp.add_argument("--notes")
    stamp.add_argument("--stamp-file")
    add_output_args(stamp)

    status = sub.add_parser("status", help="Check current CDB against a prior stamp")
    status.add_argument("--stamp-file")
    status.add_argument("--expect-version")
    add_output_args(status)

    ctx = sub.add_parser("agent-context", help="Compact context block for agents")
    ctx.add_argument("--sheet", action="append")
    ctx.add_argument("--sample", type=int, default=0)
    ctx.add_argument("--no-hash", action="store_true")
    ctx.add_argument("--stamp-file")
    add_output_args(ctx)

    return p


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    try:
        db = CDB(args.cdb)
    except FileNotFoundError:
        eprint(f"CDB not found: {args.cdb}")
        return EXIT_IO
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        eprint(f"Could not open CDB: {exc}")
        return EXIT_IO

    commands = {
        "info": command_info,
        "sheets": command_sheets,
        "schema": command_schema,
        "get": command_get,
        "search": command_search,
        "filter": command_filter,
        "refs": command_refs,
        "export": command_export,
        "stamp": command_stamp,
        "status": command_status,
        "agent-context": command_agent_context,
    }

    try:
        return commands[args.command](db, args)
    except BrokenPipeError:
        return EXIT_OK
    except ValueError as exc:
        return fail_query(str(exc), args)
    except Exception as exc:
        eprint(f"Unhandled error: {exc}")
        return EXIT_IO


if __name__ == "__main__":
    raise SystemExit(main())
