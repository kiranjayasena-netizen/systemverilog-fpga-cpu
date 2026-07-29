"""Run lightweight publication checks that do not require Vivado."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REQUIRED = [
    "README.md",
    "LICENSE",
    "CITATION.cff",
    "constraints/basys3.xdc",
    "programs/final_benchmark.mem",
    "scripts/run_xsim_regression.ps1",
    "scripts/run_vivado_impl_phase20_phase19a_119p0.tcl",
    "docs/reproducing-the-book-results.md",
]


def fail(message: str) -> None:
    print(f"ERROR: {message}")
    global FAILED
    FAILED = True


FAILED = False

for relative_path in REQUIRED:
    if not (ROOT / relative_path).is_file():
        fail(f"required file is missing: {relative_path}")

for markdown_file in ROOT.rglob("*.md"):
    text = markdown_file.read_text(encoding="utf-8")
    for target in re.findall(r"\[[^\]]+\]\(([^)]+)\)", text):
        target = target.split("#", 1)[0]
        if not target or re.match(r"^(?:https?|mailto):", target):
            continue
        resolved = (markdown_file.parent / target).resolve()
        if not resolved.exists():
            fail(
                f"broken local link in {markdown_file.relative_to(ROOT)}: "
                f"{target}"
            )

xdc = ROOT / "constraints/basys3.xdc"
if xdc.is_file() and re.search(r"<[A-Z0-9_]+>", xdc.read_text(encoding="utf-8")):
    fail("constraints/basys3.xdc still contains placeholder values")

if FAILED:
    sys.exit(1)

print("Repository publication checks passed.")
