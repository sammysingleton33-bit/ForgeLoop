"""Record a review verdict for a generator, pinned to the current geometry hash of each asset.

  python3 blender/scripts/record_review.py house_cottage --verdict PASS --round 3 \
      --reviewer "fresh-context subagent" --scores '{"silhouette": 4, ...}' --notes "..." \
      [--asset-verdict house_cottage_03=NEEDS-WORK ...]

Writes blender/reviews/<generator>.json, re-applies reviews to manifest.d fragments and re-merges
manifest.json. Stdlib only. A later geometry change automatically drops the asset to UNREVIEWED.
"""

import argparse
import json
import sys
from pathlib import Path

BLENDER = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BLENDER))

from lib import manifest  # noqa: E402

CRITERIA = {"silhouette": 4, "variation": 4, "readability": 4, "proportions": 3, "palette": 3,
            "detail_density": 3, "cohesion": 3, "triangle_cost": 3}


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("generator")
    ap.add_argument("--verdict", required=True, choices=["PASS", "NEEDS-WORK"])
    ap.add_argument("--round", type=int, required=True)
    ap.add_argument("--reviewer", required=True)
    ap.add_argument("--scores", required=True, help="JSON object, keys: " + ", ".join(CRITERIA))
    ap.add_argument("--notes", default="")
    ap.add_argument("--asset-verdict", action="append", default=[], metavar="ID=VERDICT")
    a = ap.parse_args(argv)

    scores = json.loads(a.scores)
    missing = sorted(set(CRITERIA) - set(scores))
    if missing:
        ap.error(f"scores missing {missing}")
    below = [k for k, thr in CRITERIA.items() if int(scores[k]) < thr]
    if a.verdict == "PASS" and below:
        ap.error(f"verdict PASS contradicts scores below threshold: {below}")
    frag_path = manifest.FRAG_DIR / f"{a.generator}.json"
    frag = json.loads(frag_path.read_text())
    overrides = dict(x.split("=", 1) for x in a.asset_verdict)
    assets = {}
    for e in frag["assets"]:
        v = overrides.get(e["id"], a.verdict)
        assets[e["id"]] = {"verdict": v, "geometry_hash": e["geometry_hash"]}
    out = {"generator": a.generator, "generator_version": frag["assets"][0]["generator_version"],
           "round": a.round, "reviewer": a.reviewer, "verdict": a.verdict,
           "scores": {k: int(scores[k]) for k in CRITERIA}, "notes": a.notes, "assets": assets}
    manifest.REVIEW_DIR.mkdir(exist_ok=True)
    (manifest.REVIEW_DIR / f"{a.generator}.json").write_text(json.dumps(out, indent=2, sort_keys=True) + "\n")
    manifest.refresh_reviews()
    manifest.merge()
    print(f"recorded {a.verdict} for {len(assets)} {a.generator} assets (round {a.round})")


if __name__ == "__main__":
    main()
