"""Build assets/icons/atlas2 from unit-kind portraits. Requires Pillow."""
import hashlib
import json
import math
from pathlib import Path

from PIL import Image


def main():
    icons = Path(__file__).resolve().parents[1] / "assets" / "icons"
    sources = sorted((icons / "portraits").glob("*.png"))
    if not sources:
        raise RuntimeError("No unit-kind portraits found")
    unique = {}
    keys = {}
    for source in sources:
        with Image.open(source) as image:
            rgba = image.convert("RGBA")
        if rgba.size != (256, 256):
            raise ValueError(f"Unexpected portrait dimensions: {source}")
        digest = hashlib.sha256(rgba.tobytes()).hexdigest()
        if digest not in unique:
            unique[digest] = rgba
        keys[source.name] = digest

    # Preserve source pixels; share frames for identical unit portraits.
    columns = 16
    width, height = columns * 256, math.ceil(len(unique) / columns) * 256
    atlas = Image.new("RGBA", (width, height))
    frames_by_digest = {}
    for index, (digest, rgba) in enumerate(unique.items()):
        x, y = index % columns * 256, index // columns * 256
        atlas.paste(rgba, (x, y))
        frames_by_digest[digest] = dict(x=x, y=y, w=256, h=256,
                                        atlas_w=width, atlas_h=height)
    frames = {key: frames_by_digest[digest] for key, digest in keys.items()}
    atlas.save(icons / "atlas2.png")
    (icons / "atlas2.json").write_text(json.dumps({
        "meta": dict(width=width, height=height, total_packed=len(frames)),
        "frames": frames,
    }, indent=2) + "\n", encoding="utf-8")

    # Verify saved pixels and the exact keys consumed by TargetSnap.kind.
    with Image.open(icons / "atlas2.png") as saved:
        for source in sources:
            f = frames[source.name]
            crop = saved.crop((f["x"], f["y"], f["x"] + f["w"], f["y"] + f["h"]))
            with Image.open(source) as original:
                assert crop.tobytes() == original.convert("RGBA").tobytes(), source
    assert "Wolf_Z2W.png" in frames, "Coyote portrait missing"
    print(f"Verified {len(frames)} portraits, {len(unique)} unique frames, {width}x{height}")


if __name__ == "__main__":
    main()
