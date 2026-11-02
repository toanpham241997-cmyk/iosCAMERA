#!/usr/bin/env python3
"""Cross-platform project integrity checks (not an iOS compiler or device test)."""
import hashlib
import json
from pathlib import Path
import plistlib
import re
import struct
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


def verify():
    checks = []

    def require(condition, message):
        if not condition: raise AssertionError(message)
        checks.append(message)

    info = plistlib.loads((ROOT / "AIMat/Info.plist").read_bytes())
    require(bool(info.get("NSCameraUsageDescription")), "Camera usage description")
    require(bool(info.get("NSPhotoLibraryAddUsageDescription")), "Add-only Photos usage description")
    require("NSMicrophoneUsageDescription" not in info, "No unnecessary microphone permission")
    require(info["UISupportedInterfaceOrientations"] == ["UIInterfaceOrientationPortrait"], "Portrait orientation matches pixel-buffer transform")
    privacy = plistlib.loads((ROOT / "AIMat/Resources/PrivacyInfo.xcprivacy").read_bytes())
    require(privacy["NSPrivacyTracking"] is False and not privacy["NSPrivacyCollectedDataTypes"], "Privacy manifest declares no tracking or collection")
    lock = json.loads((ROOT / "model-lock.json").read_text(encoding="utf-8"))
    model = ROOT / "AIMat/Resources" / lock["filename"]
    require(model.exists() and model.stat().st_size == lock["bytes"], "Bundled model size matches lock")
    require(hashlib.sha256(model.read_bytes()).hexdigest() == lock["sha256"], "Bundled model SHA-256 matches lock")
    project = (ROOT / "AIMat.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
    declared = re.findall(r"^\s*([0-9A-F]{24}) = \{", project, re.M)
    references = set(re.findall(r"\b[0-9A-F]{24}\b", project))
    require(len(declared) == len(set(declared)) and references == set(declared), "All Xcode object references resolve uniquely")
    sources = list((ROOT / "AIMat").rglob("*.swift"))
    for source in sources:
        path = source.relative_to(ROOT).as_posix()
        require(project.count(f'path = "{path}";') == 1, f"Xcode includes {path}")
    require(project.count(f'path = "AIMat/Resources/{lock["filename"]}";') == 1, "Xcode includes compiled Core ML input")
    ET.parse(ROOT / "AIMat.xcodeproj/xcshareddata/xcschemes/AIMat.xcscheme")
    require(True, "Shared Xcode scheme is valid XML")
    assets = ROOT / "AIMat/Resources/Assets.xcassets"
    for path in assets.rglob("Contents.json"): json.loads(path.read_text())
    icon = assets / "AppIcon.appiconset/AppIcon.png"
    data = icon.read_bytes()
    require(data[:8] == b"\x89PNG\r\n\x1a\n" and struct.unpack(">II", data[16:24]) == (1024, 1024), "App icon is a 1024px PNG")
    require(data[25] == 2, "App icon is opaque RGB")
    for script in (ROOT / "scripts").glob("*.py"):
        compile(script.read_text(encoding="utf-8"), str(script), "exec")
    require(True, "All Python build tools compile")
    tests = (ROOT / "Tests/CoreTests.swift").read_text(encoding="utf-8")
    require(len(re.findall(r"func test\w+\(", tests)) >= 9, "Swift core test suite is present")
    print(f"PASS: {len(checks)} project integrity checks.")
    print("These checks do not compile Swift or validate camera behavior. Run swift test and xcodebuild on macOS.")


if __name__ == "__main__":
    try:
        verify()
    except Exception as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)
