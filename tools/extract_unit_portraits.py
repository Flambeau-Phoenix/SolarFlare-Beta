#!/usr/bin/env python3
"""Extract UI/Portraits/Units from Farever res.pak and curate kind-keyed PNGs."""

from __future__ import annotations

import json
import shutil
import struct
import sys
from pathlib import Path

from PIL import Image

PAK = Path(r"~\steamapps\common\Farever\res.pak")
CDB = Path(r"PATHtoDATA.CDB")
RAW_OUT = Path(r"OutPutPath")
CURATED = Path(r"CuratedUsedPortraitPath")


class Reader:
	def __init__(self, buf: bytes, pos: int = 0):
		self.buf = buf
		self.pos = pos

	def read_byte(self) -> int:
		v = self.buf[self.pos]
		self.pos += 1
		return v

	def read_str(self, n: int) -> str:
		s = self.buf[self.pos : self.pos + n].decode("utf-8", errors="replace")
		self.pos += n
		return s

	def read_i32(self) -> int:
		(v,) = struct.unpack_from("<i", self.buf, self.pos)
		self.pos += 4
		return v

	def read_f64(self) -> float:
		(v,) = struct.unpack_from("<d", self.buf, self.pos)
		self.pos += 8
		return v


def read_entry(r: Reader) -> dict:
	name = r.read_str(r.read_byte())
	flags = r.read_byte()
	if flags & 1:
		count = r.read_i32()
		return {
			"name": name,
			"dir": True,
			"content": [read_entry(r) for _ in range(count)],
		}
	data_pos = r.read_f64() if flags & 2 else r.read_i32()
	data_size = r.read_i32()
	_checksum = r.read_i32()
	return {
		"name": name,
		"dir": False,
		"pos": int(data_pos),
		"size": data_size,
	}


def read_header(pak: Path) -> tuple[int, dict]:
	with pak.open("rb") as f:
		head = f.read(12)
		if head[:3] != b"PAK":
			raise SystemExit("not a Heaps PAK")
		header_size = struct.unpack_from("<i", head, 4)[0]
		payload_len = header_size - 16
		payload = f.read(payload_len)
		marker = f.read(4)
		if marker != b"DATA":
			raise SystemExit("missing DATA marker")
		root = read_entry(Reader(payload))
		return header_size, root


def find_dir(node: dict, parts: list[str]) -> dict | None:
	if not parts:
		return node if node.get("dir") else None
	want = parts[0]
	if not node.get("dir"):
		return None
	for child in node["content"]:
		if child["name"] == want:
			return find_dir(child, parts[1:])
	return None


def iter_files(node: dict, prefix: str = ""):
	rel = prefix
	if node["name"]:
		rel = f"{prefix}/{node['name']}" if prefix else node["name"]
	if node.get("dir"):
		for child in node["content"]:
			yield from iter_files(child, rel)
	else:
		yield rel, node


def magic_at(f, abs_pos: int) -> bytes:
	f.seek(abs_pos)
	return f.read(4)


def extract_blob(f, abs_pos: int, size: int, dest: Path):
	dest.parent.mkdir(parents=True, exist_ok=True)
	f.seek(abs_pos)
	remaining = size
	with dest.open("wb") as out:
		while remaining > 0:
			chunk = f.read(min(4 * 1024 * 1024, remaining))
			if not chunk:
				raise EOFError(dest)
			out.write(chunk)
			remaining -= len(chunk)


def to_png(src: Path, dest: Path) -> bool:
	dest.parent.mkdir(parents=True, exist_ok=True)
	try:
		if src.suffix.lower() == ".png" and src.read_bytes()[:4] == b"\x89PNG":
			if src.resolve() != dest.resolve():
				shutil.copy2(src, dest)
			return True
		# Farever packs DX10 DDS under .png names — Pillow opens them.
		with Image.open(src) as im:
			rgba = im.convert("RGBA")
			rgba.save(dest, format="PNG")
		return dest.exists() and dest.stat().st_size > 0
	except Exception as e:
		print(f"convert fail {src.name}: {e}", file=sys.stderr)
		return False


def sanitize_kind(kind: str) -> str:
	if not kind:
		return ""
	out = []
	for ch in kind:
		if ch.isalnum() or ch in ("_", "-"):
			out.append(ch)
	return "".join(out)


def main() -> None:
	if not PAK.exists():
		raise SystemExit(f"missing pak: {PAK}")
	print("reading pak header…")
	header_size, root = read_header(PAK)
	units_dir = find_dir(root, ["UI", "Portraits", "Units"])
	if units_dir is None:
		# some packs use forward path segments differently
		units_dir = find_dir(root, ["ui", "Portraits", "Units"])
	if units_dir is None:
		raise SystemExit("UI/Portraits/Units not found in pak")

	RAW_OUT.mkdir(parents=True, exist_ok=True)
	extracted: dict[str, Path] = {}
	with PAK.open("rb") as f:
		for rel, node in iter_files(units_dir, "UI/Portraits/Units"):
			name = Path(node["name"]).name
			stem = Path(name).stem
			abs_pos = header_size + node["pos"]
			magic = magic_at(f, abs_pos)
			tmp = RAW_OUT / name
			if magic == b"DDS ":
				tmp = RAW_OUT / (stem + ".dds")
			elif magic == b"\x89PNG":
				tmp = RAW_OUT / (stem + ".png")
			print(f"extract {name} ({node['size']} bytes, magic={magic!r})")
			extract_blob(f, abs_pos, node["size"], tmp)
			png = RAW_OUT / (stem + ".png")
			ok = to_png(tmp, png)
			if ok:
				extracted[stem] = png
				extracted[name] = png
				extracted[stem + ".png"] = png
			# Drop temp DDS only after a successful PNG write.
			if ok and tmp.suffix.lower() == ".dds" and tmp.exists() and tmp.resolve() != png.resolve():
				try:
					tmp.unlink()
				except OSError:
					pass

	print(f"extracted {len({p for p in extracted.values()})} unique PNGs")

	with CDB.open(encoding="utf-8") as fh:
		db = json.load(fh)
	unit_sheet = next(s for s in db["sheets"] if s["name"] == "unit")

	CURATED.mkdir(parents=True, exist_ok=True)
	# wipe previous curated set (keep folder)
	for old in CURATED.glob("*.png"):
		old.unlink()

	copied = 0
	missing = 0
	seen_kinds: set[str] = set()
	for line in unit_sheet.get("lines", []):
		kind = sanitize_kind(str(line.get("id") or ""))
		if not kind or kind in seen_kinds:
			continue
		gfx = line.get("gfx")
		if not isinstance(gfx, dict):
			continue
		file_path = str(gfx.get("file") or "").replace("\\", "/")
		if "Portraits/Units/" not in file_path and "Portraits\\Units\\" not in file_path:
			continue
		base = Path(file_path).name
		stem = Path(base).stem
		src = extracted.get(stem) or extracted.get(base) or extracted.get(stem + ".png")
		if src is None or not src.exists():
			missing += 1
			continue
		dest = CURATED / f"{kind}.png"
		shutil.copy2(src, dest)
		seen_kinds.add(kind)
		copied += 1

	# also keep unique art stems for atlas convenience (no kind remap collisions)
	stems_dir = CURATED / "_by_stem"
	stems_dir.mkdir(exist_ok=True)
	for old in stems_dir.glob("*.png"):
		old.unlink()
	stem_copied = 0
	for stem, src in sorted({Path(p).stem: p for p in extracted.values()}.items()):
		safe = sanitize_kind(stem)
		if not safe:
			continue
		shutil.copy2(src, stems_dir / f"{safe}.png")
		stem_copied += 1

	manifest = {
		"kind_portraits": copied,
		"missing_kind_sources": missing,
		"unique_stems": stem_copied,
		"raw_dir": str(RAW_OUT),
		"curated_dir": str(CURATED),
		"note": "GameIcons key = unit kind id (basename). Atlas frames should use the same keys.",
	}
	(CURATED / "MANIFEST.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
	print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
	main()
