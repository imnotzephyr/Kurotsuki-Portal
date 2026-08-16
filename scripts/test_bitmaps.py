# Bitmap tester: simulates AHK's Gdip_ImageSearch against all field bitmaps.
#
# AHK's Gdip_ImageSearch works as follows:
#   1. Slide the bitmap across the search region pixel-by-pixel
#   2. At each position, compare each pixel of the bitmap to the screenshot
#   3. If ALL pixels match within the tolerance, return that position
#   4. If NO position matches, return 0
#
# This tool replicates that exact algorithm:
#   - Tolerance defaults to 30 (same as Gdip_ImageSearch default)
#   - Returns "FOUND at (x, y)" if any position has all pixels within tolerance
#   - Returns "NOT FOUND" otherwise
#   - Also prints the BEST match percentage for tuning purposes

import re
import sys
import base64
import argparse
from io import BytesIO
from pathlib import Path

from PIL import Image, ImageChops

# Allow this to be run from any directory by adding the hermes venv to path
sys.path.insert(0, r"C:\Users\e1hua\AppData\Local\hermes\hermes-agent\venv\Lib\site-packages")


def load_bitmaps(bitmaps_ahk_path):
    """Parse images/bitmaps.ahk and return a dict of name -> PIL Image.

    Loads both Viciousbee[field] entries (field-specific) and standalone
    bitmaps like VBWarning (yellow warning icon).
    """
    src = Path(bitmaps_ahk_path).read_text(encoding="utf-8")
    bitmaps = {}
    # Match: bitmaps["Viciousbee"]["fieldname"] := Gdip_BitmapFromBase64("...")
    field_pattern = re.compile(
        r'bitmaps\["Viciousbee"\]\["(\w+)"\]\s*:=\s*Gdip_BitmapFromBase64\("([^"]+)"'
    )
    for m in field_pattern.finditer(src):
        field, b64 = m.group(1), m.group(2)
        try:
            img = Image.open(BytesIO(base64.b64decode(b64))).convert("RGB")
            bitmaps[f"Viciousbee.{field}"] = img
        except Exception:
            pass
    # Match: bitmaps["name"] := Gdip_BitmapFromBase64("...") (standalone)
    # Skip ones that have a [ subscript (Map or field entries).
    standalone_pattern = re.compile(
        r'bitmaps\["(\w+)"\]\s*:=\s*Gdip_BitmapFromBase64\("([^"]+)"'
    )
    for m in standalone_pattern.finditer(src):
        name, b64 = m.group(1), m.group(2)
        # Skip if this is a field-bitmap entry (already loaded above)
        if name == "Viciousbee":
            continue
        if name in bitmaps:
            continue  # already loaded as field entry
        try:
            img = Image.open(BytesIO(base64.b64decode(b64))).convert("RGB")
            bitmaps[name] = img
        except Exception:
            pass
    return bitmaps


def get_chat_region(ss_img):
    """Auto-detect the chat region based on screenshot dimensions."""
    W, H = ss_img.size
    if W == 1920 and H == 1009:
        return W - 500, 175, 500, 100  # x, y, w, h
    elif W == 960 and H == 540:
        return W - 250, 80, 250, 100
    elif W == 1920 and H == 1080:
        return W - 500, 175, 500, 100  # same as 1009 for chat position
    else:
        # Fallback: assume top-right region
        return W - min(500, W // 2), H // 6, min(500, W // 2), 100


def gdip_image_search(ss_img, bitmap, tolerance=30):
    """Simulate AHK's Gdip_ImageSearch: slide bitmap across image, find first
    position where ALL pixels match within tolerance.

    Returns (found, position, best_match_pct) where:
      - found: True if a match was found
      - position: (x, y) of the match in screenshot coords, or None
      - best_match_pct: percentage of pixels within tolerance at the best match
    """
    W, H = ss_img.size
    tw, th = bitmap.size

    best_pct = 0.0
    best_pos = None

    # Slide bitmap across the entire image
    for y in range(H - th + 1):
        for x in range(W - tw + 1):
            window = ss_img.crop((x, y, x + tw, y + th))
            diff = ImageChops.difference(bitmap, window)
            dp = list(diff.getdata())
            # Check if ALL pixels are within tolerance
            matches = 0
            for r, g, b in dp:
                if r <= tolerance and g <= tolerance and b <= tolerance:
                    matches += 1
            pct = matches / len(dp) if dp else 0

            # Track best match for diagnostics
            if pct > best_pct:
                best_pct = pct
                best_pos = (x, y)

            # If 100% within tolerance, this is a match (Gdip_ImageSearch behavior)
            if pct >= 1.0:
                return (True, (x, y), 1.0)

    return (False, best_pos, best_pct)


def main():
    parser = argparse.ArgumentParser(
        description="Test field bitmaps against a BSS screenshot using AHK-compatible Gdip_ImageSearch simulation."
    )
    parser.add_argument("screenshot", help="Path to BSS screenshot (PNG)")
    parser.add_argument(
        "--bitmaps",
        default=r"C:\Users\e1hua\Desktop\ViciousBeeEater_v0.0.3\VicHopMacro-main (1)\VicHopMacro-main\images\bitmaps.ahk",
        help="Path to bitmaps.ahk",
    )
    parser.add_argument(
        "--tolerance",
        type=int,
        default=30,
        help="Per-pixel tolerance (0-255). Gdip_ImageSearch default is 30.",
    )
    parser.add_argument(
        "--field",
        choices=["pepper", "mountain", "cactus", "rose", "spider", "clover", "all"],
        default="all",
        help="Which field bitmap(s) to test",
    )
    args = parser.parse_args()

    ss_path = Path(args.screenshot)
    if not ss_path.exists():
        print(f"ERROR: Screenshot not found: {ss_path}")
        sys.exit(1)

    bm_path = Path(args.bitmaps)
    if not bm_path.exists():
        print(f"ERROR: bitmaps.ahk not found: {bm_path}")
        sys.exit(1)

    bitmaps = load_bitmaps(bm_path)
    if not bitmaps:
        print(f"ERROR: No bitmaps found in {bm_path}")
        sys.exit(1)

    ss_img = Image.open(ss_path).convert("RGB")
    W, H = ss_img.size
    chat_x, chat_y, chat_w, chat_h = get_chat_region(ss_img)

    print(f"Screenshot: {ss_path}")
    print(f"  Size: {W}x{H}")
    print(f"  Chat region: x={chat_x}, y={chat_y}, w={chat_w}, h={chat_h}")
    print(f"Bitmaps: {bm_path}")
    print(f"  Loaded {len(bitmaps)} field bitmap(s): {', '.join(sorted(bitmaps.keys()))}")
    print(f"Tolerance: {args.tolerance}/255")
    print()

    fields_to_test = [args.field] if args.field != "all" else sorted(bitmaps.keys())

    for field in fields_to_test:
        if field not in bitmaps:
            print(f"  [{field:>10}] BITMAP NOT FOUND in bitmaps.ahk")
            continue

        bm = bitmaps[field]
        tw, th = bm.size

        # Search only in the chat region (not the whole screenshot)
        # This is what ViciousSpawnLocation does in the macro
        chat_ss = ss_img.crop((chat_x, chat_y, chat_x + chat_w, chat_y + chat_h))

        found, best_pos, best_pct = gdip_image_search(chat_ss, bm, args.tolerance)

        if found:
            # Convert chat-relative position back to screenshot coords
            real_pos = (best_pos[0] + chat_x, best_pos[1] + chat_y)
            print(f"  [{field:>10}] DETECTED at {best_pos} (chat), {real_pos} (screen)")
        else:
            real_pos = (best_pos[0] + chat_x, best_pos[1] + chat_y) if best_pos else None
            status = f"NOT DETECTED (best match: {best_pct*100:.1f}%)"
            print(f"  [{field:>10}] {status}")
            if best_pos:
                print(f"                 Best at {best_pos} (chat), {real_pos} (screen)")

    print()
    print("Result interpretation:")
    print("  DETECTED    -> Gdip_ImageSearch would return 1 (match found)")
    print("  NOT DETECTED -> Gdip_ImageSearch would return 0 (no match)")
    print("  Match percentage is shown for tuning tolerance or re-capturing bitmaps")


if __name__ == "__main__":
    main()
