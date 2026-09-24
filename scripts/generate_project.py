#!/usr/bin/env python3
"""Deterministic, idempotent generator for Proximeet.xcodeproj (stdlib only).

Generates:
  Proximeet.xcodeproj/project.pbxproj
  Proximeet.xcodeproj/project.xcworkspace/contents.xcworkspacedata
  Proximeet.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist
  Proximeet.xcodeproj/xcshareddata/xcschemes/Proximeet.xcscheme

Format decisions
----------------
* objectVersion = 60 is the Xcode 15 project format. It is required because the
  app links its local Swift package through an XCLocalSwiftPackageReference,
  an object type introduced by Xcode 15.
* compatibilityVersion = "Xcode 15.0" is the "Project Format" label that Xcode
  15 pairs with objectVersion 60. The file contains Xcode-15-only objects
  (XCLocalSwiftPackageReference), so claiming "Xcode 14.0" compatibility would
  be inaccurate. Xcode 15.0 or later is required to open the project.
* The local package product dependency is written without a `package` key,
  matching what Xcode 15 writes for products of local packages.
* Object IDs are the first 24 upper-case hex digits of SHA-1 over a namespaced,
  stable key (never random), so re-running produces byte-identical output.
* No team, signing identity, entitlements, capabilities, usage descriptions,
  script phases or copy phases. PRODUCT_BUNDLE_IDENTIFIER com.proximeet.demo is
  provisional and must be registered under the owner's team before any
  distribution.
* ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS (present in the
  Xcode 15 template) is deliberately omitted so generated asset symbols cannot
  collide with hand-written Color/Image extensions in the app.

Sources are discovered at render time: every *.swift file under Proximeet/
(recursively, sorted) is compiled by the app target, grouped by directory.
Resources are explicitly allowlisted below. UI test Swift files are discovered
under ProximeetUITests/ and compiled only by the UI test target. Run this again
after adding, moving or removing Swift files.

Usage:
  python3 scripts/generate_project.py           # write or update the files
  python3 scripts/generate_project.py --check   # exit 1 and list differing files; write nothing
"""
from __future__ import annotations

import argparse
import hashlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

PROJECT_NAME = "Proximeet"
TARGET_NAME = "Proximeet"
PRODUCT_FILE = "Proximeet.app"
APP_DIR = "Proximeet"
UI_TEST_TARGET = "ProximeetUITests"
UI_TEST_PRODUCT = "ProximeetUITests.xctest"
PROJECT_DIR = "Proximeet.xcodeproj"
RESOURCE_FILES = (
    "Proximeet/Resources/Assets.xcassets",
    "Proximeet/Resources/PrivacyInfo.xcprivacy",
    "Proximeet/Resources/3D/ProximeetSignature.usdz",
    "Proximeet/Resources/SignatureStudio.skybox",
)
PACKAGE_RELATIVE_PATH = "ProximeetDomain"
PACKAGE_PRODUCT = "ProximeetDomain"
PACKAGE_TEST_TARGET = "ProximeetDomainTests"

OBJECT_VERSION = "60"
COMPATIBILITY_VERSION = "Xcode 15.0"
TOOLS_VERSION = "1500"  # LastUpgradeCheck / LastSwiftUpdateCheck / scheme LastUpgradeVersion
CREATED_ON_TOOLS_VERSION = "15.0"

BUNDLE_IDENTIFIER = "com.proximeet.demo"  # provisional; see module docstring

FIXTURE_ARGUMENTS = (
    "-ProximeetFixture band",
    "-ProximeetFixture signal",
    "-ProximeetFixture signal-selected",
    "-ProximeetFixture ready",
    "-ProximeetFixtureBand dating",
    "-ProximeetFixtureSignal withMyCrew",
    "-ProximeetReduceMotionPreview YES",
)

FILE_TYPES = {
    ".swift": "sourcecode.swift",
    ".xcassets": "folder.assetcatalog",
    ".xcprivacy": "text.xml",
    ".usdz": "file.usdz",
    ".skybox": "file.skybox",
}

# --------------------------------------------------------------------------
# Build settings
# --------------------------------------------------------------------------

_PROJECT_SHARED = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "CLANG_ANALYZER_NONNULL": "YES",
    "CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION": "YES_AGGRESSIVE",
    "CLANG_CXX_LANGUAGE_STANDARD": "gnu++20",
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "CLANG_ENABLE_OBJC_WEAK": "YES",
    "CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING": "YES",
    "CLANG_WARN_BOOL_CONVERSION": "YES",
    "CLANG_WARN_COMMA": "YES",
    "CLANG_WARN_CONSTANT_CONVERSION": "YES",
    "CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS": "YES",
    "CLANG_WARN_DIRECT_OBJC_ISA_USAGE": "YES_ERROR",
    "CLANG_WARN_DOCUMENTATION_COMMENTS": "YES",
    "CLANG_WARN_EMPTY_BODY": "YES",
    "CLANG_WARN_ENUM_CONVERSION": "YES",
    "CLANG_WARN_INFINITE_RECURSION": "YES",
    "CLANG_WARN_INT_CONVERSION": "YES",
    "CLANG_WARN_NON_LITERAL_NULL_CONVERSION": "YES",
    "CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF": "YES",
    "CLANG_WARN_OBJC_LITERAL_CONVERSION": "YES",
    "CLANG_WARN_OBJC_ROOT_CLASS": "YES_ERROR",
    "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER": "YES",
    "CLANG_WARN_RANGE_LOOP_ANALYSIS": "YES",
    "CLANG_WARN_STRICT_PROTOTYPES": "YES",
    "CLANG_WARN_SUSPICIOUS_MOVE": "YES",
    "CLANG_WARN_UNGUARDED_AVAILABILITY": "YES_AGGRESSIVE",
    "CLANG_WARN_UNREACHABLE_CODE": "YES",
    "CLANG_WARN__DUPLICATE_METHOD_MATCH": "YES",
    "COPY_PHASE_STRIP": "NO",
    "ENABLE_STRICT_OBJC_MSGSEND": "YES",
    "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
    "GCC_C_LANGUAGE_STANDARD": "gnu17",
    "GCC_NO_COMMON_BLOCKS": "YES",
    "GCC_WARN_64_TO_32_BIT_CONVERSION": "YES",
    "GCC_WARN_ABOUT_RETURN_TYPE": "YES_ERROR",
    "GCC_WARN_UNDECLARED_SELECTOR": "YES",
    "GCC_WARN_UNINITIALIZED_AUTOS": "YES_AGGRESSIVE",
    "GCC_WARN_UNUSED_FUNCTION": "YES",
    "GCC_WARN_UNUSED_VARIABLE": "YES",
    "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
    "LOCALIZATION_PREFERS_STRING_CATALOGS": "YES",
    "MTL_FAST_MATH": "YES",
    "SDKROOT": "iphoneos",
}

PROJECT_SETTINGS = {
    "Debug": {
        **_PROJECT_SHARED,
        "DEBUG_INFORMATION_FORMAT": "dwarf",
        "ENABLE_TESTABILITY": "YES",
        "GCC_DYNAMIC_NO_PIC": "NO",
        "GCC_OPTIMIZATION_LEVEL": "0",
        "GCC_PREPROCESSOR_DEFINITIONS": ["DEBUG=1", "$(inherited)"],
        "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
        "ONLY_ACTIVE_ARCH": "YES",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG $(inherited)",
        "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
    },
    "Release": {
        **_PROJECT_SHARED,
        "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
        "ENABLE_NS_ASSERTIONS": "NO",
        "MTL_ENABLE_DEBUG_INFO": "NO",
        "SWIFT_COMPILATION_MODE": "wholemodule",
        "SWIFT_OPTIMIZATION_LEVEL": "-O",
        "VALIDATE_PRODUCT": "YES",
    },
}

_TARGET_SHARED = {
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
    "CODE_SIGN_STYLE": "Automatic",
    "CURRENT_PROJECT_VERSION": "1",
    "ENABLE_PREVIEWS": "YES",
    "GENERATE_INFOPLIST_FILE": "YES",
    "INFOPLIST_KEY_CFBundleDisplayName": "Proximeet Demo",
    "INFOPLIST_KEY_ITSAppUsesNonExemptEncryption": "NO",
    "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES",
    "INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
    "INFOPLIST_KEY_UIStatusBarStyle": "UIStatusBarStyleLightContent",
    "INFOPLIST_KEY_UISupportedInterfaceOrientations": "UIInterfaceOrientationPortrait",
    "INFOPLIST_KEY_UIUserInterfaceStyle": "Dark",
    "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks",
    "MARKETING_VERSION": "0.1.0",
    "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_IDENTIFIER,
    "PRODUCT_NAME": "$(TARGET_NAME)",
    "SWIFT_EMIT_LOC_STRINGS": "YES",
    "SWIFT_STRICT_CONCURRENCY": "complete",
    "SWIFT_VERSION": "5.0",
    "TARGETED_DEVICE_FAMILY": "1",
}

TARGET_SETTINGS = {"Debug": dict(_TARGET_SHARED), "Release": dict(_TARGET_SHARED)}
UI_TEST_SETTINGS = {name: {
    "CODE_SIGN_STYLE": "Automatic",
    "GENERATE_INFOPLIST_FILE": "YES",
    "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks @loader_path/Frameworks",
    "PRODUCT_BUNDLE_IDENTIFIER": "com.proximeet.demo.uitests",
    "PRODUCT_NAME": "$(TARGET_NAME)",
    "SWIFT_STRICT_CONCURRENCY": "complete",
    "SWIFT_VERSION": "5.0",
    "TARGETED_DEVICE_FAMILY": "1",
    "TEST_TARGET_NAME": TARGET_NAME,
} for name in ("Debug", "Release")}

CONFIGURATIONS = ("Debug", "Release")

# --------------------------------------------------------------------------
# OpenStep (pbxproj) serialisation
# --------------------------------------------------------------------------

_UNQUOTED = re.compile(r"[A-Za-z0-9_$./]+")


def object_id(key: str) -> str:
    """Stable 24-hex-digit object identifier for a namespaced key."""
    return hashlib.sha1(f"proximeet.xcodeproj/v1:{key}".encode("utf-8")).hexdigest().upper()[:24]


def quote(value: str) -> str:
    if value and _UNQUOTED.fullmatch(value) and "//" not in value and "___" not in value:
        return value
    escaped = (value.replace("\\", "\\\\").replace('"', '\\"')
               .replace("\n", "\\n").replace("\t", "\\t"))
    return f'"{escaped}"'


class Ref:
    """A reference to another object, rendered as `ID /* comment */`."""

    def __init__(self, oid: str, comment: str | None) -> None:
        self.oid = oid
        self.comment = comment

    def render(self) -> str:
        return f"{self.oid} /* {self.comment} */" if self.comment else self.oid


def _tabs(level: int) -> str:
    return "\t" * level


def _ordered_items(fields: dict) -> list:
    keys = sorted(key for key in fields if key != "isa")
    return ([("isa", fields["isa"])] if "isa" in fields else []) + [(key, fields[key]) for key in keys]


def render_value(value: object, level: int) -> str:
    if isinstance(value, Ref):
        return value.render()
    if isinstance(value, str):
        return quote(value)
    if isinstance(value, list):
        lines = "".join(f"{_tabs(level + 1)}{render_value(item, level + 1)},\n" for item in value)
        return f"(\n{lines}{_tabs(level)})"
    if isinstance(value, dict):
        lines = "".join(
            f"{_tabs(level + 1)}{quote(key)} = {render_value(item, level + 1)};\n"
            for key, item in _ordered_items(value)
        )
        return f"{{\n{lines}{_tabs(level)}}}"
    raise TypeError(f"unsupported pbxproj value {value!r}")


def render_inline(fields: dict) -> str:
    parts = "".join(f"{quote(key)} = {render_value(item, 0)}; " for key, item in _ordered_items(fields))
    return f"{{{parts}}}"


class PBXObject:
    def __init__(self, oid: str, comment: str | None, fields: dict, inline: bool = False) -> None:
        self.oid = oid
        self.comment = comment
        self.fields = fields
        self.inline = inline

    @property
    def isa(self) -> str:
        return self.fields["isa"]

    def ref(self) -> Ref:
        return Ref(self.oid, self.comment)

    def render(self) -> str:
        head = f"{_tabs(2)}{Ref(self.oid, self.comment).render()} = "
        body = render_inline(self.fields) if self.inline else render_value(self.fields, 2)
        return f"{head}{body};\n"


# --------------------------------------------------------------------------
# Project model
# --------------------------------------------------------------------------


def discover_swift_sources(root: Path) -> list[str]:
    app = root / APP_DIR
    if not app.is_dir():
        return []
    return sorted(path.relative_to(root).as_posix() for path in app.rglob("*.swift") if path.is_file())


def discover_ui_test_sources(root: Path) -> list[str]:
    directory = root / UI_TEST_TARGET
    return sorted(path.relative_to(root).as_posix() for path in directory.rglob("*.swift")
                  if path.is_file()) if directory.is_dir() else []


def _sort_key(name: str) -> tuple[str, str]:
    return (name.lower(), name)


def build_objects(root: Path) -> tuple[list[PBXObject], str]:
    objects: list[PBXObject] = []

    def add(obj: PBXObject) -> PBXObject:
        objects.append(obj)
        return obj

    sources = discover_swift_sources(root)
    ui_sources = discover_ui_test_sources(root)
    members = sources + ui_sources + list(RESOURCE_FILES)

    # File references.
    file_refs: dict[str, PBXObject] = {}
    for relative in members:
        name = relative.rsplit("/", 1)[-1]
        suffix = name[name.rfind("."):] if "." in name else ""
        file_refs[relative] = add(PBXObject(
            object_id(f"fileref:{relative}"), name,
            {"isa": "PBXFileReference", "lastKnownFileType": FILE_TYPES[suffix],
             "path": name, "sourceTree": "<group>"},
            inline=True,
        ))
    product = add(PBXObject(
        object_id(f"product:{PRODUCT_FILE}"), PRODUCT_FILE,
        {"isa": "PBXFileReference", "explicitFileType": "wrapper.application",
         "includeInIndex": "0", "path": PRODUCT_FILE, "sourceTree": "BUILT_PRODUCTS_DIR"},
        inline=True,
    ))
    ui_product = add(PBXObject(
        object_id(f"product:{UI_TEST_PRODUCT}"), UI_TEST_PRODUCT,
        {"isa": "PBXFileReference", "explicitFileType": "wrapper.cfbundle",
         "includeInIndex": "0", "path": UI_TEST_PRODUCT, "sourceTree": "BUILT_PRODUCTS_DIR"},
        inline=True,
    ))

    # Groups mirroring the directory tree under Proximeet/.
    directories: set[str] = set()
    for relative in members:
        parts = relative.split("/")[:-1]
        for depth in range(1, len(parts) + 1):
            directories.add("/".join(parts[:depth]))
    directories.add(APP_DIR)
    directories.add(UI_TEST_TARGET)
    groups: dict[str, PBXObject] = {}
    for directory in sorted(directories, key=lambda d: (-d.count("/"), d)):
        name = directory.rsplit("/", 1)[-1]
        children = [
            (child.rsplit("/", 1)[-1], groups[child].ref()) for child in groups
            if child.rsplit("/", 1)[0] == directory and "/" in child
        ] + [
            (relative.rsplit("/", 1)[-1], file_refs[relative].ref()) for relative in members
            if relative.rsplit("/", 1)[0] == directory
        ]
        children.sort(key=lambda item: _sort_key(item[0]))
        groups[directory] = add(PBXObject(
            object_id(f"group:{directory}"), name,
            {"isa": "PBXGroup", "children": [ref for _, ref in children],
             "path": name, "sourceTree": "<group>"},
        ))
    products_group = add(PBXObject(
        object_id("group:<products>"), "Products",
        {"isa": "PBXGroup", "children": [product.ref(), ui_product.ref()], "name": "Products",
         "sourceTree": "<group>"},
    ))
    main_group = add(PBXObject(
        object_id("group:<main>"), None,
        {"isa": "PBXGroup", "children": [groups[APP_DIR].ref(), groups[UI_TEST_TARGET].ref(), products_group.ref()],
         "sourceTree": "<group>"},
    ))

    # Local Swift package.
    package_ref = add(PBXObject(
        object_id(f"localpackage:{PACKAGE_RELATIVE_PATH}"),
        f'XCLocalSwiftPackageReference "{PACKAGE_RELATIVE_PATH}"',
        {"isa": "XCLocalSwiftPackageReference", "relativePath": PACKAGE_RELATIVE_PATH},
    ))
    product_dependency = add(PBXObject(
        object_id(f"packageproduct:{PACKAGE_PRODUCT}"), PACKAGE_PRODUCT,
        {"isa": "XCSwiftPackageProductDependency", "productName": PACKAGE_PRODUCT},
    ))

    # Build files and phases.
    def build_file(phase: str, relative: str) -> PBXObject:
        ref = file_refs[relative]
        return add(PBXObject(
            object_id(f"buildfile:{phase}:{relative}"), f"{ref.comment} in {phase}",
            {"isa": "PBXBuildFile", "fileRef": ref.ref()}, inline=True,
        ))

    source_files = [build_file("Sources", relative) for relative in sources]
    resource_files = [build_file("Resources", relative) for relative in RESOURCE_FILES]
    framework_file = add(PBXObject(
        object_id(f"buildfile:Frameworks:package:{PACKAGE_PRODUCT}"),
        f"{PACKAGE_PRODUCT} in Frameworks",
        {"isa": "PBXBuildFile", "productRef": product_dependency.ref()}, inline=True,
    ))

    def phase(isa: str, name: str, files: list[PBXObject], owner: str = TARGET_NAME) -> PBXObject:
        return add(PBXObject(
            object_id(f"phase:{owner}:{name}"), name,
            {"isa": isa, "buildActionMask": "2147483647",
             "files": [item.ref() for item in files],
             "runOnlyForDeploymentPostprocessing": "0"},
        ))

    sources_phase = phase("PBXSourcesBuildPhase", "Sources", source_files)
    frameworks_phase = phase("PBXFrameworksBuildPhase", "Frameworks", [framework_file])
    resources_phase = phase("PBXResourcesBuildPhase", "Resources", resource_files)
    ui_sources_phase = phase("PBXSourcesBuildPhase", "Sources",
                             [build_file("UISources", relative) for relative in ui_sources], UI_TEST_TARGET)
    ui_frameworks_phase = phase("PBXFrameworksBuildPhase", "Frameworks", [], UI_TEST_TARGET)
    ui_resources_phase = phase("PBXResourcesBuildPhase", "Resources", [], UI_TEST_TARGET)

    # Build configurations.
    def configuration_list(owner_key: str, owner_comment: str,
                           settings: dict[str, dict]) -> PBXObject:
        configs = [
            add(PBXObject(
                object_id(f"config:{owner_key}:{name}"), name,
                {"isa": "XCBuildConfiguration", "buildSettings": dict(settings[name]),
                 "name": name},
            ))
            for name in CONFIGURATIONS
        ]
        return add(PBXObject(
            object_id(f"configlist:{owner_key}"), f"Build configuration list for {owner_comment}",
            {"isa": "XCConfigurationList",
             "buildConfigurations": [config.ref() for config in configs],
             "defaultConfigurationIsVisible": "0",
             "defaultConfigurationName": "Release"},
        ))

    target_configs = configuration_list(
        f"target:{TARGET_NAME}", f'PBXNativeTarget "{TARGET_NAME}"', TARGET_SETTINGS)
    ui_configs = configuration_list(
        f"target:{UI_TEST_TARGET}", f'PBXNativeTarget "{UI_TEST_TARGET}"', UI_TEST_SETTINGS)
    project_configs = configuration_list(
        "project", f'PBXProject "{PROJECT_NAME}"', PROJECT_SETTINGS)

    target = add(PBXObject(
        target_id(), TARGET_NAME,
        {"isa": "PBXNativeTarget",
         "buildConfigurationList": target_configs.ref(),
         "buildPhases": [sources_phase.ref(), frameworks_phase.ref(), resources_phase.ref()],
         "buildRules": [],
         "dependencies": [],
         "name": TARGET_NAME,
         "packageProductDependencies": [product_dependency.ref()],
         "productName": TARGET_NAME,
         "productReference": product.ref(),
         "productType": "com.apple.product-type.application"},
    ))
    ui_proxy = add(PBXObject(
        object_id("proxy:uitests:app"), "PBXContainerItemProxy",
        {"isa": "PBXContainerItemProxy", "containerPortal": Ref(object_id("project"), "Project object"),
         "proxyType": "1", "remoteGlobalIDString": target_id(), "remoteInfo": TARGET_NAME},
    ))
    ui_dependency = add(PBXObject(
        object_id("dependency:uitests:app"), "PBXTargetDependency",
        {"isa": "PBXTargetDependency", "target": target.ref(), "targetProxy": ui_proxy.ref()},
    ))
    ui_target = add(PBXObject(
        ui_target_id(), UI_TEST_TARGET,
        {"isa": "PBXNativeTarget", "buildConfigurationList": ui_configs.ref(),
         "buildPhases": [ui_sources_phase.ref(), ui_frameworks_phase.ref(), ui_resources_phase.ref()],
         "buildRules": [], "dependencies": [ui_dependency.ref()], "name": UI_TEST_TARGET,
         "productName": UI_TEST_TARGET, "productReference": ui_product.ref(),
         "productType": "com.apple.product-type.bundle.ui-testing"},
    ))

    project = add(PBXObject(
        object_id("project"), "Project object",
        {"isa": "PBXProject",
         "attributes": {
             "BuildIndependentTargetsInParallel": "1",
             "LastSwiftUpdateCheck": TOOLS_VERSION,
             "LastUpgradeCheck": TOOLS_VERSION,
             "TargetAttributes": {
                 target.oid: {"CreatedOnToolsVersion": CREATED_ON_TOOLS_VERSION},
                 ui_target.oid: {"CreatedOnToolsVersion": CREATED_ON_TOOLS_VERSION,
                                 "TestTargetID": target_id()},
             },
         },
         "buildConfigurationList": project_configs.ref(),
         "compatibilityVersion": COMPATIBILITY_VERSION,
         "developmentRegion": "en",
         "hasScannedForEncodings": "0",
         "knownRegions": ["en", "Base"],
         "mainGroup": Ref(main_group.oid, None),
         "packageReferences": [package_ref.ref()],
         "productRefGroup": products_group.ref(),
         "projectDirPath": "",
         "projectRoot": "",
         "targets": [target.ref(), ui_target.ref()]},
    ))

    identifiers = [obj.oid for obj in objects]
    duplicates = sorted({oid for oid in identifiers if identifiers.count(oid) > 1})
    if duplicates:
        raise RuntimeError(f"object ID collision: {duplicates}")
    return objects, project.oid


def target_id() -> str:
    return object_id(f"target:{TARGET_NAME}")


def ui_target_id() -> str:
    return object_id(f"target:{UI_TEST_TARGET}")


def render_pbxproj(root: Path) -> str:
    objects, root_object = build_objects(root)
    sections: dict[str, list[PBXObject]] = {}
    for obj in objects:
        sections.setdefault(obj.isa, []).append(obj)
    out = [
        "// !$*UTF8*$!\n",
        "{\n",
        "\tarchiveVersion = 1;\n",
        "\tclasses = {\n",
        "\t};\n",
        f"\tobjectVersion = {OBJECT_VERSION};\n",
        "\tobjects = {\n",
    ]
    for isa in sorted(sections):
        out.append(f"\n/* Begin {isa} section */\n")
        for obj in sorted(sections[isa], key=lambda item: item.oid):
            out.append(obj.render())
        out.append(f"/* End {isa} section */\n")
    out.append("\t};\n")
    out.append(f"\trootObject = {root_object} /* Project object */;\n")
    out.append("}\n")
    return "".join(out)


# --------------------------------------------------------------------------
# Workspace and scheme
# --------------------------------------------------------------------------

WORKSPACE_DATA = """<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "self:">
   </FileRef>
</Workspace>
"""

WORKSPACE_CHECKS = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
\t<key>IDEDidComputeMac32BitWarning</key>
\t<true/>
</dict>
</plist>
"""


def _xml_attr(value: str) -> str:
    return (value.replace("&", "&amp;").replace("<", "&lt;")
            .replace(">", "&gt;").replace('"', "&quot;"))


def _buildable_reference(indent: int, blueprint_id: str, buildable_name: str,
                         blueprint_name: str, container: str) -> str:
    pad = " " * indent
    return (
        f"{pad}<BuildableReference\n"
        f'{pad}   BuildableIdentifier = "primary"\n'
        f'{pad}   BlueprintIdentifier = "{_xml_attr(blueprint_id)}"\n'
        f'{pad}   BuildableName = "{_xml_attr(buildable_name)}"\n'
        f'{pad}   BlueprintName = "{_xml_attr(blueprint_name)}"\n'
        f'{pad}   ReferencedContainer = "{_xml_attr(container)}">\n'
        f"{pad}</BuildableReference>\n"
    )


def render_scheme() -> str:
    app_container = f"container:{PROJECT_DIR}"

    def app_ref(indent: int) -> str:
        return _buildable_reference(indent, target_id(), PRODUCT_FILE, TARGET_NAME, app_container)

    def ui_ref(indent: int) -> str:
        return _buildable_reference(indent, ui_target_id(), UI_TEST_PRODUCT, UI_TEST_TARGET, app_container)

    arguments = "".join(
        "         <CommandLineArgument\n"
        f'            argument = "{_xml_attr(argument)}"\n'
        '            isEnabled = "NO">\n'
        "         </CommandLineArgument>\n"
        for argument in FIXTURE_ARGUMENTS
    )
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        "<Scheme\n"
        f'   LastUpgradeVersion = "{TOOLS_VERSION}"\n'
        '   version = "1.7">\n'
        "   <BuildAction\n"
        '      parallelizeBuildables = "YES"\n'
        '      buildImplicitDependencies = "YES">\n'
        "      <BuildActionEntries>\n"
        "         <BuildActionEntry\n"
        '            buildForTesting = "YES"\n'
        '            buildForRunning = "YES"\n'
        '            buildForProfiling = "YES"\n'
        '            buildForArchiving = "YES"\n'
        '            buildForAnalyzing = "YES">\n'
        + app_ref(12)
        + "         </BuildActionEntry>\n"
        "         <BuildActionEntry\n"
        '            buildForTesting = "YES"\n'
        '            buildForRunning = "NO"\n'
        '            buildForProfiling = "NO"\n'
        '            buildForArchiving = "NO"\n'
        '            buildForAnalyzing = "YES">\n'
        + ui_ref(12)
        + "         </BuildActionEntry>\n"
        "      </BuildActionEntries>\n"
        "   </BuildAction>\n"
        "   <TestAction\n"
        '      buildConfiguration = "Debug"\n'
        '      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"\n'
        '      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"\n'
        '      shouldUseLaunchSchemeArgsEnv = "YES"\n'
        '      shouldAutocreateTestPlan = "YES">\n'
        "      <Testables>\n"
        "         <TestableReference\n"
        '            skipped = "NO"\n'
        '            parallelizable = "NO">\n'
        + ui_ref(12)
        + "         </TestableReference>\n"
        "         <TestableReference\n"
        '            skipped = "NO">\n'
        + _buildable_reference(12, PACKAGE_TEST_TARGET, PACKAGE_TEST_TARGET, PACKAGE_TEST_TARGET,
                               f"container:{PACKAGE_RELATIVE_PATH}")
        + "         </TestableReference>\n"
        "      </Testables>\n"
        "   </TestAction>\n"
        "   <LaunchAction\n"
        '      buildConfiguration = "Debug"\n'
        '      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"\n'
        '      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"\n'
        '      launchStyle = "0"\n'
        '      useCustomWorkingDirectory = "NO"\n'
        '      ignoresPersistentStateOnLaunch = "NO"\n'
        '      debugDocumentVersioning = "YES"\n'
        '      debugServiceExtension = "internal"\n'
        '      allowLocationSimulation = "NO">\n'
        "      <BuildableProductRunnable\n"
        '         runnableDebuggingMode = "0">\n'
        + app_ref(9)
        + "      </BuildableProductRunnable>\n"
        "      <CommandLineArguments>\n"
        + arguments
        + "      </CommandLineArguments>\n"
        "   </LaunchAction>\n"
        "   <ProfileAction\n"
        '      buildConfiguration = "Release"\n'
        '      shouldUseLaunchSchemeArgsEnv = "YES"\n'
        '      savedToolIdentifier = ""\n'
        '      useCustomWorkingDirectory = "NO"\n'
        '      debugDocumentVersioning = "YES">\n'
        "      <BuildableProductRunnable\n"
        '         runnableDebuggingMode = "0">\n'
        + app_ref(9)
        + "      </BuildableProductRunnable>\n"
        "   </ProfileAction>\n"
        "   <AnalyzeAction\n"
        '      buildConfiguration = "Debug">\n'
        "   </AnalyzeAction>\n"
        "   <ArchiveAction\n"
        '      buildConfiguration = "Release"\n'
        '      revealArchiveInOrganizer = "YES">\n'
        "   </ArchiveAction>\n"
        "</Scheme>\n"
    )


# --------------------------------------------------------------------------
# Entry points
# --------------------------------------------------------------------------


def render(root: Path = ROOT) -> dict[str, str]:
    """Relative path -> exact file text for every generated project file."""
    return {
        f"{PROJECT_DIR}/project.pbxproj": render_pbxproj(root),
        f"{PROJECT_DIR}/project.xcworkspace/contents.xcworkspacedata": WORKSPACE_DATA,
        f"{PROJECT_DIR}/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist": WORKSPACE_CHECKS,
        f"{PROJECT_DIR}/xcshareddata/xcschemes/{TARGET_NAME}.xcscheme": render_scheme(),
    }


def differing_files(root: Path, expected: dict[str, str]) -> list[str]:
    problems = []
    for relative, text in expected.items():
        path = root / relative
        if not path.is_file():
            problems.append(f"{relative}: missing")
        elif path.read_bytes() != text.encode("utf-8"):
            problems.append(f"{relative}: content differs")
    return problems


def unmanaged_files(root: Path) -> list[str]:
    """Files under Proximeet/ that the project does not include (asset catalog contents excluded)."""
    app = root / APP_DIR
    if not app.is_dir():
        return []
    included = set(discover_swift_sources(root)) | set(RESOURCE_FILES)
    found = []
    for path in sorted(app.rglob("*")):
        relative = path.relative_to(root).as_posix()
        if not path.is_file() or ".xcassets/" in relative or ".skybox/" in relative or relative in included:
            continue
        if path.name == ".DS_Store":
            continue
        found.append(relative)
    return found


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Generate Proximeet.xcodeproj deterministically.")
    parser.add_argument("--check", action="store_true",
                        help="exit 1 if on-disk files differ from a fresh render; write nothing")
    args = parser.parse_args(argv)
    expected = render(ROOT)
    for relative in unmanaged_files(ROOT):
        print(f"note: not in project (unsupported file type): {relative}", file=sys.stderr)
    for relative in RESOURCE_FILES:
        if not (ROOT / relative).exists():
            print(f"note: resource missing on disk (run scripts/generate_app_assets.py): {relative}",
                  file=sys.stderr)
    if args.check:
        problems = differing_files(ROOT, expected)
        for problem in problems:
            print(f"DIFFERS {problem}")
        print("generate_project --check: " + ("FAILED" if problems else "up to date"))
        return 1 if problems else 0
    for relative, text in expected.items():
        path = ROOT / relative
        data = text.encode("utf-8")
        if path.is_file() and path.read_bytes() == data:
            print(f"unchanged {relative}")
            continue
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        print(f"wrote     {relative}")
    print(f"{len(discover_swift_sources(ROOT))} Swift source(s) in target {TARGET_NAME}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
