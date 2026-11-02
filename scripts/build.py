#!/usr/bin/env python3
"""One-command local build. Xcode and signing are used only on macOS."""
import argparse
from pathlib import Path
import platform
import plistlib
import re
import shutil
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def run(*command):
    print("> " + " ".join(map(str, command)), flush=True)
    subprocess.run(list(map(str, command)), cwd=ROOT, check=True)


def package_source():
    output = ROOT / "dist/AIMat-source.zip"
    output.parent.mkdir(exist_ok=True)
    excluded = {".git", ".build", ".swiftpm", "build", "dist", "__pycache__", "DerivedData", ".tools"}
    project_folders = {"AIMat", "AIMat.xcodeproj", "Tests", "scripts", "docs", ".github"}
    project_files = {"README.md", "Package.swift", "model-lock.json", ".gitignore", "Build-AIMat.command", "Build-AIMat.cmd"}
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(ROOT.rglob("*")):
            relative = path.relative_to(ROOT)
            if not path.is_file() or any(part in excluded for part in relative.parts): continue
            if relative.parts[0] not in project_folders and relative.as_posix() not in project_files: continue
            if path.suffix in {".p12", ".p8", ".mobileprovision", ".download"} or path.name.startswith(".env"): continue
            archive.write(path, Path("AIMat") / relative)
    print(f"Source package: {output}")


def main():
    parser = argparse.ArgumentParser(description="AI Mắt · Compact IPA Builder")
    parser.add_argument("action", choices=["prepare", "check", "test", "simulator", "unsigned", "ipa", "source"], nargs="?", default="prepare")
    parser.add_argument("--team", help="Apple development team ID (10 characters)")
    parser.add_argument("--bundle-id", default="vn.aimat.camera", help="Unique bundle ID registered with your team")
    parser.add_argument("--method", choices=["debugging", "release-testing", "app-store-connect"], default="debugging")
    args = parser.parse_args()
    if args.action == "check":
        run(sys.executable, ROOT / "scripts/verify.py")
        return
    if args.action == "test":
        if not shutil.which("swift"): raise RuntimeError("Swift is unavailable. Run tests on macOS with Xcode, or use the included GitHub Actions workflow.")
        run("swift", "test")
        return
    if args.action == "ipa" and (not args.team or not re.fullmatch(r"[A-Z0-9]{10}", args.team)):
        raise RuntimeError("Signed IPA export requires --team YOURTEAMID (10 uppercase letters/digits).")
    if not re.fullmatch(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+){2,}", args.bundle_id):
        raise RuntimeError("Bundle ID must use reverse-domain format, e.g. vn.yourname.aimat.")
    if args.action in {"simulator", "unsigned", "ipa"}:
        if platform.system() != "Darwin" or not shutil.which("xcodebuild"):
            raise RuntimeError("IPA compilation needs macOS + Xcode. On Windows: run 'source' to package the project, then use a Mac or the included macOS GitHub Actions workflow. No installable IPA has been built.")
    run(sys.executable, ROOT / "scripts/fetch_model.py")
    run(sys.executable, ROOT / "scripts/generate_project.py")
    run(sys.executable, ROOT / "scripts/verify.py")
    if args.action == "prepare":
        print("Ready. Open AIMat.xcodeproj on a Mac and select your signing team.")
        return
    if args.action == "source":
        package_source()
        return
    common = ["xcodebuild", "-project", "AIMat.xcodeproj", "-scheme", "AIMat", "-configuration", "Release"]
    bundle = f"PRODUCT_BUNDLE_IDENTIFIER={args.bundle_id}"
    if args.action == "simulator":
        run(*common, "-sdk", "iphonesimulator", "-destination", "generic/platform=iOS Simulator",
            "-derivedDataPath", "build/simulator", "CODE_SIGNING_ALLOWED=NO", bundle, "build")
    elif args.action == "unsigned":
        run(*common, "-sdk", "iphoneos", "-destination", "generic/platform=iOS", "-derivedDataPath", "build/device",
            "CODE_SIGNING_ALLOWED=NO", bundle, "build")
        app = ROOT / "build/device/Build/Products/Release-iphoneos/AIMat.app"
        if not app.is_dir(): raise RuntimeError("Xcode did not produce AIMat.app.")
        output = ROOT / "build/AIMat-unsigned.ipa"
        with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
            for path in app.rglob("*"):
                if path.is_file(): archive.write(path, Path("Payload/AIMat.app") / path.relative_to(app))
        print(f"UNSIGNED artifact: {output}. Requires valid Apple signing before installation.")
    elif args.action == "ipa":
        run(*common, "-destination", "generic/platform=iOS", "-archivePath", "build/AIMat.xcarchive",
            "-allowProvisioningUpdates", f"DEVELOPMENT_TEAM={args.team}", bundle, "archive")
        options = ROOT / "build/ExportOptions.plist"
        options.write_bytes(plistlib.dumps({"method": args.method, "teamID": args.team,
            "signingStyle": "automatic", "destination": "export", "stripSwiftSymbols": True}))
        run("xcodebuild", "-exportArchive", "-archivePath", "build/AIMat.xcarchive", "-exportPath", "build/ipa",
            "-exportOptionsPlist", options, "-allowProvisioningUpdates")
        print("Signed IPA exported to build/ipa. Install using the distribution method your provisioning profile permits.")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.CalledProcessError) as error:
        print(f"Build stopped: {error}", file=sys.stderr)
        sys.exit(1)
