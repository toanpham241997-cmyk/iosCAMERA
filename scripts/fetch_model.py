#!/usr/bin/env python3
"""Fetch Apple's compact object detector. No third-party Python dependencies."""
import hashlib
import json
from pathlib import Path
import sys
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
MODEL = ROOT / "AIMat/Resources/YOLOv3TinyInt8LUT.mlmodel"
URL = "https://ml-assets.apple.com/coreml/models/Image/ObjectDetection/YOLOv3Tiny/YOLOv3TinyInt8LUT.mlmodel"
LOCK = ROOT / "model-lock.json"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    expected = json.loads(LOCK.read_text(encoding="utf-8")) if LOCK.exists() else None
    if MODEL.exists() and expected and digest(MODEL) == expected["sha256"]:
        print(f"Model verified: {MODEL.name} ({MODEL.stat().st_size:,} bytes)")
        return
    MODEL.parent.mkdir(parents=True, exist_ok=True)
    temporary = MODEL.with_suffix(".download")
    try:
        print("Downloading compact Core ML model from Apple...", flush=True)
        request = urllib.request.Request(URL, headers={"User-Agent": "AIMat-Build/1.0"})
        with urllib.request.urlopen(request, timeout=60) as response, temporary.open("wb") as destination:
            total = 0
            while chunk := response.read(256 * 1024):
                total += len(chunk)
                if total > 15_000_000:
                    raise ValueError("Unexpected model size; refusing this download.")
                destination.write(chunk)
        if temporary.stat().st_size < 5_000_000:
            raise ValueError("Download is too small to be the expected model.")
        actual = digest(temporary)
        if expected and actual != expected["sha256"]:
            raise ValueError("Model SHA-256 does not match model-lock.json. Review the upstream model before updating the lock.")
        temporary.replace(MODEL)
        if not expected:
            LOCK.write_text(json.dumps({"url": URL, "filename": MODEL.name, "bytes": MODEL.stat().st_size,
                "sha256": actual}, indent=2) + "\n", encoding="utf-8")
        print(f"Model ready: {MODEL.name} - SHA-256 {actual}")
    finally:
        temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"Model download failed: {error}", file=sys.stderr)
        sys.exit(1)
