"""Inspect and exercise a fresh portable ZIP without reading the working game cache."""
from pathlib import Path, PurePosixPath
from zipfile import ZipFile
from datetime import datetime
import json
import re
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
archive = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "build/JA-like-AI-Prototype-0.3.1-Windows-x64.zip"
destination = root / ".runtime" / ("release-verify-" + datetime.now().strftime("%Y%m%d-%H%M%S"))
destination.mkdir(parents=True)
with ZipFile(archive) as bundle:
    names = bundle.namelist()
    prefixes = {PurePosixPath(name).parts[0] for name in names}
    assert len(prefixes) == 1, "Archive must have one top-level folder"
    prefix = next(iter(prefixes))
    for name in names:
        parts = PurePosixPath(name).parts
        assert not PurePosixPath(name).is_absolute() and ".." not in parts, name
        assert not {".runtime", ".godot", "saves", "build", ".git"}.intersection(parts[1:]), name
    required = ["START.cmd", "START-OPENGL.cmd", "DEMO.cmd", "launch.ps1", "game/project.godot", "game/main.tscn", "game/main.gd", "docs/ASSETS.md"]
    required += [f"game/assets/textures/{part}.jpg" for part in ("ground-color", "ground-normal", "plaster-color", "plaster-normal")]
    for name in required:
        assert f"{prefix}/{name}" in names, name
    for name in names:
        if not name.endswith(".gd"):
            continue
        source = bundle.read(name).decode("utf-8-sig")
        for resource in re.findall(r'(?:load|preload)\("res://([^"\n]+)"\)', source):
            assert f"{prefix}/game/{resource}" in names, f"Missing resource {resource}"
    assert bundle.testzip() is None, "ZIP CRC failure"
    bundle.extractall(destination)

portable = destination / prefix
reports = {}
for label, args in [("tests", ["--headless", "--", "--test"]), ("campaign", ["--headless", "--", "--campaign-test"]), ("render", ["--quit-after", "2000", "--", "--capture"])]:
    result = subprocess.run(["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(portable / "launch.ps1"), *args], cwd=portable, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=90)
    output = result.stdout + result.stderr
    (root / "build" / f"portable-{label}.log").write_text(output, encoding="utf-8")
    assert result.returncode == 0 and "ERROR:" not in output, output
    assert {"tests": "ALL TESTS PASSED", "campaign": "CAMPAIGN TESTS: []", "render": "SCREENSHOT_SAVED"}[label] in output, output
    reports[label] = "passed"
reports["portable_path"] = str(portable)
reports["archive_entries"] = len(names)
reports["screenshot"] = str(portable / "build/preview.png")
(root / "build/release-validation.json").write_text(json.dumps(reports, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps(reports, ensure_ascii=False))
