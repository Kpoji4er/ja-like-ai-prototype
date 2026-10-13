"""Build a portable Windows ZIP from an explicit allowlist. No caches or user data."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import hashlib

root = Path(__file__).resolve().parent.parent
version = "0.1.0"
folder = f"JA-like-AI-Prototype-{version}-Windows-x64"
archive = root / "build" / f"{folder}.zip"
files = [root / name for name in ("README.md", "START.cmd", "launch.ps1")]
files += sorted(p for p in (root / "game").iterdir() if p.is_file())
files += sorted((root / "tools" / "godot").glob("*.exe"))
files += [root / "docs" / name for name in ("godot-license.txt", "godot-third-party-notices.txt", "preview.png")]
files += [root / "scripts" / name for name in ("log-task.ps1", "setup-godot.ps1")]
archive.parent.mkdir(exist_ok=True)
with ZipFile(archive, "w", compression=ZIP_DEFLATED, compresslevel=6) as bundle:
    for path in files:
        if not path.is_file():
            raise FileNotFoundError(path)
        bundle.write(path, f"{folder}/{path.relative_to(root).as_posix()}")
with ZipFile(archive) as bundle:
    bad = bundle.testzip()
    if bad:
        raise RuntimeError(f"ZIP integrity failure: {bad}")
digest = hashlib.file_digest(archive.open("rb"), "sha256").hexdigest()
checksum = archive.with_suffix(".sha256")
checksum.write_text(f"{digest}  {archive.name}\n", encoding="ascii")
print(f"READY: {archive.name} ({archive.stat().st_size / 1024 / 1024:.1f} MiB)")
print(f"SHA256: {digest}")
