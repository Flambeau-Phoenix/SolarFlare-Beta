import os, json, math
from PIL import Image

WORKING_DIR = os.getcwd()
OUTPUT_PNG = "atlas.png"
OUTPUT_JSON = "atlas.json"

png_files = [
    f for f in os.listdir(WORKING_DIR) 
    if f.lower().endswith(".png") and f != OUTPUT_PNG
]

if not png_files:
    print(f"No PNG files found in {WORKING_DIR}")
    exit(1)

print(f"Found {len(png_files)} total PNG icons. Loading images...")

# Load and sort images by height (descending) for optimal row packing
images = []
for fname in png_files:
    fpath = os.path.join(WORKING_DIR, fname)
    try:
        img = Image.open(fpath).convert("RGBA")
        images.append((fname, img))
    except Exception as e:
        print(f"Skipping corrupt image {fname}: {e}")

images.sort(key=lambda item: item[1].size[1], reverse=True)

# Calculate required total surface area to estimate initial canvas size
total_area = sum(img.size[0] * img.size[1] for _, img in images)
min_side = int(math.ceil(math.sqrt(total_area * 1.3))) # 30% padding for packing inefficiency

# Round up to nearest power of 2 (e.g., 2048, 4096)
ATLAS_WIDTH = 2 ** math.ceil(math.log2(max(1024, min_side)))
ATLAS_HEIGHT = ATLAS_WIDTH

print(f"Targeting initial canvas size: {ATLAS_WIDTH}x{ATLAS_HEIGHT}")

atlas_img = Image.new("RGBA", (ATLAS_WIDTH, ATLAS_HEIGHT), (0, 0, 0, 0))
manifest = {}

x, y, max_h = 0, 0, 0
packed_count = 0

for name, img in images:
    w, h = img.size
    
    # Wrap to next row if horizontal boundary reached
    if x + w > ATLAS_WIDTH:
        x = 0
        y += max_h
        max_h = 0
    
    # Expand vertical canvas if we run out of space
    if y + h > ATLAS_HEIGHT:
        ATLAS_HEIGHT *= 2
        new_atlas = Image.new("RGBA", (ATLAS_WIDTH, ATLAS_HEIGHT), (0, 0, 0, 0))
        new_atlas.paste(atlas_img, (0, 0))
        atlas_img = new_atlas
        print(f"Expanding canvas height to {ATLAS_HEIGHT}px...")

    atlas_img.paste(img, (x, y))
    manifest[name] = {
        "x": x, 
        "y": y, 
        "w": w, 
        "h": h,
        "atlas_w": ATLAS_WIDTH,
        "atlas_h": ATLAS_HEIGHT
    }
    
    x += w
    max_h = max(max_h, h)
    packed_count += 1

# Crop unused bottom area while maintaining power-of-two height
final_height = 2 ** math.ceil(math.log2(max(1024, y + max_h)))
if final_height < ATLAS_HEIGHT:
    atlas_img = atlas_img.crop((0, 0, ATLAS_WIDTH, final_height))
    # Update manifest with final atlas bounds
    for item in manifest.values():
        item["atlas_h"] = final_height

# Save output
atlas_img.save(os.path.join(WORKING_DIR, OUTPUT_PNG))

# Write manifest including atlas dimensions for runtime UV math
output_data = {
    "meta": {
        "width": ATLAS_WIDTH,
        "height": final_height,
        "total_packed": packed_count
    },
    "frames": manifest
}

with open(os.path.join(WORKING_DIR, OUTPUT_JSON), "w") as f:
    json.dump(output_data, f, indent=2)

print(f"\nSUCCESS: Packed {packed_count}/{len(png_files)} icons into {OUTPUT_PNG} ({ATLAS_WIDTH}x{final_height}px)!")