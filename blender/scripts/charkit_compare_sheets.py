"""Before / after review sheets of two kit versions for a fresh D-019 reviewer (FL-0135 silhouettes). PIL only.

  python3 blender/scripts/charkit_compare_sheets.py --old DIR_OLD --new DIR_NEW --out IMG_DIR [--max-kb 250]

DIR_* hold the PNGs of blender/scripts/charkit_render_set.py rendered with the old and the new kit files. Every sheet is a JPEG <= --max-kb.
"""

import argparse
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import charkit_review_sheets as H  # noqa: E402


def pair(old, new, name, title_old, title_new, width, tool=None):
    return H.stack([(title_old, H.load(old, name)), (title_new, H.load(new, name))], width)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--old", required=True)
    ap.add_argument("--new", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--max-kb", type=int, default=250)
    a = ap.parse_args()
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    o, n = a.old, a.new
    sheets = {}
    sheets["sheet_aerial170"] = H.stack(
        [("BEFORE (current kit): 30 citizens around a farm, 170 studs, 50 deg down; left: crop enlarged 3.75x, right: actual pixels", H.aerial_pair(o, "crowd170")),
         ("AFTER (bolder silhouettes): same roster, same camera", H.aerial_pair(n, "crowd170"))], 1268)
    sheets["sheet_lineup170"] = H.stack(
        [("BEFORE: the eleven identities in a row at 170 studs, 50 deg down (3.75x crop, names under the feet; the 1:1 strip below)", H.lineup_panel(o, "lineup170")),
         ("AFTER: the same eleven, same camera", H.lineup_panel(n, "lineup170"))], 905)
    sheets["sheet_gameplay40"] = pair(o, n, "crowd40", "BEFORE: the crowd at about 40 studs", "AFTER: same roster, same camera", 1100)
    sheets["sheet_identities"] = H.stack(
        [("BEFORE: the eleven identities from the front (about 35 studs)", H.load(o, "jobs")), ("AFTER: from the front", H.load(n, "jobs")),
         ("BEFORE: from behind", H.load(o, "jobs_back")), ("AFTER: from behind", H.load(n, "jobs_back")),
         ("BEFORE: from above, 50 deg down, about 60 studs", H.load(o, "jobs_air")), ("AFTER: from above", H.load(n, "jobs_air"))], 1200)
    sheets["sheet_silhouettes"] = H.stack(
        [("BEFORE: silhouettes from the front", H.load(o, "sil_jobs")), ("AFTER: from the front", H.load(n, "sil_jobs")),
         ("BEFORE: turned 40 degrees", H.load(o, "sil_jobs_yaw")), ("AFTER: turned 40 degrees", H.load(n, "sil_jobs_yaw")),
         ("BEFORE: seen from 50 deg above", H.load(o, "sil_air")), ("AFTER: seen from 50 deg above", H.load(n, "sil_air"))], 1400)
    sheets["sheet_portraits"] = H.stack([("BEFORE: head-and-shoulders portraits of the eleven identities", H.load(o, "portraits")),
                                         ("AFTER", H.load(n, "portraits"))], 1100)
    sheets["sheet_variation"] = H.stack([("BEFORE: 36 looks (skin x hair x hair colour x outfit); rows 1-4 idle citizens, 5 farmers, 6 builders", H.load(o, "looks")),
                                         ("AFTER", H.load(n, "looks"))], 1100)
    for name, im in sheets.items():
        q = H.save(im, out / f"{name}.jpg", a.max_kb)
        print(f"{name}.jpg {im.width}x{im.height} quality {q} {(out / f'{name}.jpg').stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
