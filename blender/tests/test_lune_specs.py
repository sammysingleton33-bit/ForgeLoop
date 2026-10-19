"""The Lune measurement specs under blender/scripts/lune (EnvDump, EnvInventory, EnvRelief, ...) boot the real WorldService and pin
figures of the world (props placed, dressing parts). roblox/scripts/check.sh does not run them, so a stale pin (616 props and 8,309 parts
after the arena changed the world to 615 and 8,271) only failed when someone ran them by hand. This runs the whole folder, so a stale pin
fails the blender check (and CI) the day the world changes."""

import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
LUNE = shutil.which("lune")
SPEC_DIR = ROOT / "blender" / "scripts" / "lune"

pytestmark = pytest.mark.skipif(LUNE is None, reason="lune not available")


def test_the_lune_measurement_specs_pass():
    specs = sorted(SPEC_DIR.glob("*.spec.luau"))
    assert specs, "blender/scripts/lune has no spec files: this guard has nothing to guard"
    result = subprocess.run(
        [
            LUNE,
            "run",
            "roblox/tests/harness/run.luau",
            "--project",
            "games/game-001/default.project.json",
            "--specs",
            "blender/scripts/lune",
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=900,
    )
    out = result.stdout + result.stderr
    summary = re.search(r"Lune tests: (\d+) passed, (\d+) failed, (\d+) broken file\(s\), (\d+) spec file\(s\)", out)
    assert summary, f"no summary line in the Lune output:\n{out[-2000:]}"
    passed, failed, broken, files = (int(g) for g in summary.groups())
    assert result.returncode == 0 and failed == 0 and broken == 0, out[-3000:]
    assert files == len(specs), f"the runner found {files} spec files, the folder has {len(specs)}"
    assert passed >= len(specs)
