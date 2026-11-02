#!/usr/bin/env python3
"""Generate a regular Xcode project using only Python's standard library."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "AIMat.xcodeproj"


def uid(name):
    return hashlib.sha1(name.encode()).hexdigest()[:24].upper()


def q(value):
    return json.dumps(str(value), ensure_ascii=False)


def generate():
    PROJECT.mkdir(exist_ok=True)
    sources = sorted(path.relative_to(ROOT).as_posix() for path in (ROOT / "AIMat").rglob("*.swift"))
    model = "AIMat/Resources/YOLOv3TinyInt8LUT.mlmodel"
    # Keep the reference even when the model has not been downloaded yet: a build
    # must fail clearly instead of silently shipping reduced detection capability.
    sources.append(model)
    resources = ["AIMat/Resources/Assets.xcassets", "AIMat/Resources/PrivacyInfo.xcprivacy"]
    objects = []

    def add(name, content):
        objects.append(f"\t\t{uid(name)} = {{ {content} }};")

    def refs(names):
        return "(" + ", ".join(uid(name) for name in names) + ",)"

    for path in sources + resources:
        kind = ("sourcecode.swift" if path.endswith(".swift") else "file.mlmodel" if path.endswith(".mlmodel")
                else "folder.assetcatalog" if path.endswith(".xcassets") else "text.xml")
        add("ref:" + path, f"isa = PBXFileReference; lastKnownFileType = {q(kind)}; path = {q(path)}; sourceTree = SOURCE_ROOT;")
        add("build:" + path, f"isa = PBXBuildFile; fileRef = {uid('ref:' + path)};")
    for path in ["AIMat/Info.plist", "README.md"]:
        add("ref:" + path, f"isa = PBXFileReference; path = {q(path)}; sourceTree = SOURCE_ROOT;")
    add("app", 'isa = PBXFileReference; explicitFileType = wrapper.application; path = AIMat.app; sourceTree = BUILT_PRODUCTS_DIR;')
    add("products", f'isa = PBXGroup; children = {refs(["app"])}; name = Products; sourceTree = "<group>";')
    add("group", f'isa = PBXGroup; children = {refs(["ref:" + p for p in sources + resources + ["AIMat/Info.plist", "README.md"]] + ["products"])}; sourceTree = "<group>";')
    add("sources", f"isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {refs(['build:' + p for p in sources])}; runOnlyForDeploymentPostprocessing = 0;")
    add("resources", f"isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = {refs(['build:' + p for p in resources])}; runOnlyForDeploymentPostprocessing = 0;")
    add("frameworks", "isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;")
    common = {
        "SDKROOT": "iphoneos", "IPHONEOS_DEPLOYMENT_TARGET": "17.0", "CLANG_ENABLE_MODULES": "YES",
        "SWIFT_VERSION": "5.0", "SWIFT_STRICT_CONCURRENCY": "minimal", "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
        "CLANG_ENABLE_OBJC_ARC": "YES", "GCC_C_LANGUAGE_STANDARD": "gnu17",
    }
    target = {
        "PRODUCT_NAME": "AIMat", "PRODUCT_BUNDLE_IDENTIFIER": "vn.aimat.camera", "CODE_SIGN_STYLE": "Automatic",
        "INFOPLIST_FILE": "AIMat/Info.plist", "GENERATE_INFOPLIST_FILE": "NO", "TARGETED_DEVICE_FAMILY": "1",
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon", "COREML_CODEGEN_LANGUAGE": "Swift",
        "MARKETING_VERSION": "1.0.0", "CURRENT_PROJECT_VERSION": "1", "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator",
        "SUPPORTS_MACCATALYST": "NO", "SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD": "NO",
        "SWIFT_EMIT_LOC_STRINGS": "YES", "ENABLE_PREVIEWS": "YES",
        "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks",
    }
    for scope, settings in [("project", common), ("target", target)]:
        for mode in ["Debug", "Release"]:
            values = dict(settings)
            if scope == "project":
                values.update({"SWIFT_OPTIMIZATION_LEVEL": "-Onone" if mode == "Debug" else "-O",
                    "DEBUG_INFORMATION_FORMAT": "dwarf" if mode == "Debug" else "dwarf-with-dsym"})
                if mode == "Debug": values["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "DEBUG"
                else: values["SWIFT_COMPILATION_MODE"] = "wholemodule"
            body = " ".join(f"{key} = {q(value)};" for key, value in values.items())
            add(f"{scope}:{mode}", f"isa = XCBuildConfiguration; buildSettings = {{ {body} }}; name = {mode};")
        add(f"{scope}:configs", f'isa = XCConfigurationList; buildConfigurations = {refs([f"{scope}:Debug", f"{scope}:Release"])}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
    add("target", f'isa = PBXNativeTarget; buildConfigurationList = {uid("target:configs")}; buildPhases = {refs(["sources", "frameworks", "resources"])}; buildRules = (); dependencies = (); name = AIMat; productName = AIMat; productReference = {uid("app")}; productType = "com.apple.product-type.application";')
    add("project", f'isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600; TargetAttributes = {{ {uid("target")} = {{ CreatedOnToolsVersion = 16.0; }}; }}; }}; buildConfigurationList = {uid("project:configs")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = vi; hasScannedForEncodings = 0; knownRegions = (vi, en, Base); mainGroup = {uid("group")}; productRefGroup = {uid("products")}; projectDirPath = ""; projectRoot = ""; targets = {refs(["target"])};')
    content = "// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 56;\n\tobjects = {\n" + "\n".join(objects) + f"\n\t}};\n\trootObject = {uid('project')};\n}}\n"
    (PROJECT / "project.pbxproj").write_text(content, encoding="utf-8")
    scheme_dir = PROJECT / "xcshareddata/xcschemes"
    scheme_dir.mkdir(parents=True, exist_ok=True)
    ref = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid("target")}" BuildableName="AIMat.app" BlueprintName="AIMat" ReferencedContainer="container:AIMat.xcodeproj"/>'
    scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref}</BuildActionEntry></BuildActionEntries></BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables/></TestAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
    (scheme_dir / "AIMat.xcscheme").write_text(scheme, encoding="utf-8")
    print(f"Generated {PROJECT.name}: {len(sources) - 1} Swift files + Core ML model.")


if __name__ == "__main__":
    generate()
