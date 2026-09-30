#!/usr/bin/env python3
"""Independent consistency checks for the checked-in Proximeet Xcode project.

Read-only: parses the on-disk project, scheme and its test plans, asset catalog, privacy manifest,
local package manifest and Swift sources, and cross-checks them against each
other and against the filesystem. It does not reuse the generator's data model;
the only generator interaction is check 10, which imports
scripts/generate_project.py (and scripts/generate_app_assets.py) and compares
their in-memory render with the files on disk without writing anything.

Usage:
  python3 scripts/validate_project.py           # PASS/FAIL per check, exit 1 on any failure
  python3 scripts/validate_project.py --diff    # also print unified diffs for check 10
"""
from __future__ import annotations

import argparse
import difflib
import importlib.util
import json
import os
import plistlib
import re
import shutil
import struct
import subprocess
import sys
import traceback
import xml.etree.ElementTree as ET
import zlib
from pathlib import Path
from typing import Callable

ROOT = Path(__file__).resolve().parent.parent
PROJECT_DIR = ROOT / "Proximeet.xcodeproj"
PBXPROJ = PROJECT_DIR / "project.pbxproj"
SCHEME = PROJECT_DIR / "xcshareddata" / "xcschemes" / "Proximeet.xcscheme"
WORKSPACE_DATA = PROJECT_DIR / "project.xcworkspace" / "contents.xcworkspacedata"
WORKSPACE_CHECKS = PROJECT_DIR / "project.xcworkspace" / "xcshareddata" / "IDEWorkspaceChecks.plist"
APP_DIR = ROOT / "Proximeet"
RESOURCES_DIR = APP_DIR / "Resources"
CATALOG = RESOURCES_DIR / "Assets.xcassets"
PRIVACY = RESOURCES_DIR / "PrivacyInfo.xcprivacy"
PACKAGE_NAME = "ProximeetDomain"
PACKAGE_TEST_TARGET = "ProximeetDomainTests"
# The scheme's test plans, in order; the first is the default (check 7). The Room plans keep the verified
# Room commit 1a5f97e's order, options and UI selections; RoomVerificationMain adds two source-reading-test
# skips (chapter 09). The Wave plans (chapter 09) are only listed after them.
EXPECTED_TEST_PLANS = ("TestPlans/RoomVerificationMain.xctestplan", "TestPlans/RoomVerificationSmall.xctestplan",
                       "TestPlans/WaveVerificationMain.xctestplan", "TestPlans/WaveVerificationSmall.xctestplan")
# Review classes whose skip flag a plan must set when it selects any of their tests, named here as well as
# read from the class's `reviewFlag = "…"` declaration, so a renamed or reworded declaration cannot quietly
# turn the check off: without its flag the class skips itself, and a skipped test is not a pass (check 7).
REQUIRED_PLAN_FLAGS = {"RoomReviewTests": "PROXIMEET_ROOM_REVIEW", "WaveReviewTests": "PROXIMEET_WAVE_REVIEW"}
# Classes whose every test method must be selected by at least one scheme plan: the chapter's own native
# verification leaves none of them out (docs/verification/wave-xcode-cloud-manifest.tsv, check 7).
COMPLETE_PLAN_CLASSES = ("RoomReviewTests", "WaveReviewTests")
APP_TARGET = "Proximeet"
UI_TEST_TARGET = "ProximeetUITests"
EXPECTED_BUNDLE_ID = "com.goseng.proximeet"
EXPECTED_DEVELOPMENT_TEAM = "2G437MAN6W"
EXPECTED_RESOURCES = {
    "Proximeet/Resources/Assets.xcassets",
    "Proximeet/Resources/PrivacyInfo.xcprivacy",
    "Proximeet/Resources/3D/ProximeetSignature.usdz",
    "Proximeet/Resources/SignatureStudio.skybox",
}
ALLOWED_PHASES = ("PBXSourcesBuildPhase", "PBXFrameworksBuildPhase", "PBXResourcesBuildPhase")
FORBIDDEN_PHASES = ("PBXShellScriptBuildPhase", "PBXCopyFilesBuildPhase", "PBXHeadersBuildPhase",
                    "PBXRezBuildPhase", "PBXBuildRule")
GROUP_ISAS = ("PBXGroup", "PBXVariantGroup", "XCVersionGroup")
OBJECT_ID = re.compile(r"[0-9A-F]{24}")

# In-memory generator output supplied by --rendered. Checks 1-9 read through these helpers,
# so the would-be project can be validated without writing anything to disk. Empty by
# default: a normal run reads only the files that actually exist.
OVERLAY: dict[Path, bytes] = {}


def v_is_file(path: Path) -> bool:
    return path in OVERLAY or path.is_file()


def v_exists(path: Path) -> bool:
    return path in OVERLAY or any(path in key.parents for key in OVERLAY) or path.exists()


def v_read_bytes(path: Path) -> bytes:
    return OVERLAY[path] if path in OVERLAY else path.read_bytes()


def v_read_text(path: Path) -> str:
    return v_read_bytes(path).decode("utf-8")

# Reference-carrying fields and the object types they may point to (None = any).
REFERENCE_FIELDS: dict[str, tuple[str, ...] | None] = {
    "children": ("PBXGroup", "PBXFileReference", "PBXVariantGroup", "XCVersionGroup",
                 "PBXReferenceProxy"),
    "files": ("PBXBuildFile",),
    "fileRef": ("PBXFileReference", "PBXVariantGroup", "XCVersionGroup", "PBXReferenceProxy"),
    "buildPhases": None,
    "buildConfigurations": ("XCBuildConfiguration",),
    "buildConfigurationList": ("XCConfigurationList",),
    "targets": ("PBXNativeTarget", "PBXAggregateTarget", "PBXLegacyTarget"),
    "mainGroup": ("PBXGroup",),
    "productRefGroup": ("PBXGroup",),
    "productReference": ("PBXFileReference", "PBXReferenceProxy"),
    "packageReferences": ("XCLocalSwiftPackageReference", "XCRemoteSwiftPackageReference"),
    "packageProductDependencies": ("XCSwiftPackageProductDependency",),
    "productRef": ("XCSwiftPackageProductDependency",),
    "dependencies": ("PBXTargetDependency",),
    "package": ("XCLocalSwiftPackageReference", "XCRemoteSwiftPackageReference"),
    "target": ("PBXNativeTarget", "PBXAggregateTarget", "PBXLegacyTarget"),
    "targetProxy": ("PBXContainerItemProxy",),
}


# ==========================================================================
# OpenStep property list parser (project.pbxproj)
# ==========================================================================


class ParseError(Exception):
    pass


class OpenStepParser:
    PUNCTUATION = "{}()=;,"

    def __init__(self, text: str) -> None:
        self.text = text
        self.i = 0
        self.n = len(text)

    def _where(self) -> str:
        line = self.text.count("\n", 0, self.i) + 1
        return f"line {line}"

    def _skip(self) -> None:
        text = self.text
        while self.i < self.n:
            char = text[self.i]
            if char.isspace():
                self.i += 1
            elif text.startswith("/*", self.i):
                end = text.find("*/", self.i + 2)
                if end < 0:
                    raise ParseError(f"unterminated comment at {self._where()}")
                self.i = end + 2
            elif text.startswith("//", self.i):
                end = text.find("\n", self.i)
                self.i = self.n if end < 0 else end + 1
            else:
                return

    def _peek(self) -> str:
        self._skip()
        return self.text[self.i] if self.i < self.n else ""

    def _expect(self, char: str) -> None:
        found = self._peek()
        if found != char:
            raise ParseError(f"expected {char!r} but found {found or 'EOF'!r} at {self._where()}")
        self.i += 1

    def parse(self) -> object:
        value = self._value()
        if self._peek():
            raise ParseError(f"trailing content at {self._where()}")
        return value

    def _value(self) -> object:
        char = self._peek()
        if char == "{":
            return self._dict()
        if char == "(":
            return self._list()
        return self._string()

    def _dict(self) -> dict:
        self.i += 1
        result: dict = {}
        while True:
            if self._peek() == "}":
                self.i += 1
                return result
            key = self._string()
            self._expect("=")
            value = self._value()
            self._expect(";")
            if key in result:
                raise ParseError(f"duplicate key {key!r} at {self._where()}")
            result[key] = value

    def _list(self) -> list:
        self.i += 1
        result: list = []
        while True:
            if self._peek() == ")":
                self.i += 1
                return result
            result.append(self._value())
            char = self._peek()
            if char == ",":
                self.i += 1
            elif char != ")":
                raise ParseError(f"expected ',' or ')' but found {char or 'EOF'!r} at {self._where()}")

    def _string(self) -> str:
        char = self._peek()
        if char == '"':
            return self._quoted()
        if not char or char in self.PUNCTUATION:
            raise ParseError(f"expected a string but found {char or 'EOF'!r} at {self._where()}")
        start = self.i
        text = self.text
        while self.i < self.n:
            char = text[self.i]
            if char.isspace() or char in self.PUNCTUATION or char == '"':
                break
            if text.startswith("/*", self.i) or text.startswith("//", self.i):
                break
            self.i += 1
        token = text[start:self.i]
        if not re.fullmatch(r"[A-Za-z0-9_$./:\-+@<>]+", token):
            raise ParseError(f"invalid unquoted string {token!r} at {self._where()}")
        return token

    def _quoted(self) -> str:
        self.i += 1
        out: list[str] = []
        escapes = {"n": "\n", "t": "\t", "r": "\r", '"': '"', "\\": "\\", "'": "'"}
        while self.i < self.n:
            char = self.text[self.i]
            if char == '"':
                self.i += 1
                return "".join(out)
            if char == "\\":
                if self.i + 1 >= self.n:
                    break
                following = self.text[self.i + 1]
                if following not in escapes:
                    raise ParseError(f"unsupported escape \\{following} at {self._where()}")
                out.append(escapes[following])
                self.i += 2
                continue
            if char == "\n":
                raise ParseError(f"newline inside quoted string at {self._where()}")
            out.append(char)
            self.i += 1
        raise ParseError("unterminated quoted string")


# ==========================================================================
# Check infrastructure
# ==========================================================================


class Check:
    def __init__(self, number: int, title: str) -> None:
        self.number = number
        self.title = title
        self.failures: list[str] = []
        self.notes: list[str] = []

    def fail(self, message: str) -> None:
        self.failures.append(message)

    def note(self, message: str) -> None:
        self.notes.append(message)

    def require(self, condition: bool, message: str) -> bool:
        if not condition:
            self.fail(message)
        return condition


class Context:
    def __init__(self, show_diff: bool) -> None:
        self.show_diff = show_diff
        self._project: dict | None = None
        self._project_error: str | None = None

    @property
    def project(self) -> dict:
        if self._project is None and self._project_error is None:
            try:
                text = v_read_text(PBXPROJ)
                if not text.startswith("// !$*UTF8*$!"):
                    raise ParseError("missing '// !$*UTF8*$!' header")
                parsed = OpenStepParser(text).parse()
                if not isinstance(parsed, dict):
                    raise ParseError("top level is not a dictionary")
                self._project = parsed
            except (OSError, UnicodeDecodeError, ParseError) as error:
                self._project_error = f"{PBXPROJ.relative_to(ROOT)}: {error}"
        if self._project is None:
            raise RuntimeError(f"project.pbxproj unavailable ({self._project_error})")
        return self._project

    @property
    def objects(self) -> dict[str, dict]:
        objects = self.project.get("objects")
        if not isinstance(objects, dict):
            raise RuntimeError("project.pbxproj has no objects dictionary")
        return objects

    def of_isa(self, isa: str) -> dict[str, dict]:
        return {oid: obj for oid, obj in self.objects.items()
                if isinstance(obj, dict) and obj.get("isa") == isa}

    @property
    def root(self) -> dict:
        return self.objects[self.project["rootObject"]]

    def app_target(self) -> tuple[str, dict]:
        matches = [(oid, obj) for oid, obj in self.of_isa("PBXNativeTarget").items()
                   if obj.get("name") == APP_TARGET]
        if len(matches) != 1:
            raise RuntimeError(f"expected one native target named {APP_TARGET}, found {len(matches)}")
        return matches[0]

    def phase_of(self, target: dict, isa: str) -> dict | None:
        phases = [self.objects.get(oid) for oid in target.get("buildPhases", [])]
        matches = [phase for phase in phases if isinstance(phase, dict) and phase.get("isa") == isa]
        return matches[0] if len(matches) == 1 else None

    # ---- path resolution through the group hierarchy --------------------
    def resolved_paths(self) -> tuple[dict[str, Path | None], list[str]]:
        objects = self.objects
        problems: list[str] = []
        parent: dict[str, str] = {}
        for oid, obj in objects.items():
            if obj.get("isa") in GROUP_ISAS:
                for child in obj.get("children", []):
                    if child in parent:
                        problems.append(f"{child} is a child of more than one group")
                    parent[child] = oid
        main_group = self.root.get("mainGroup")
        project_root = ROOT / self.root.get("projectDirPath", "")
        cache: dict[str, Path | None] = {}

        def resolve(oid: str, trail: tuple[str, ...] = ()) -> Path | None:
            if oid in cache:
                return cache[oid]
            if oid in trail:
                problems.append(f"group cycle through {oid}")
                return None
            obj = objects[oid]
            tree = obj.get("sourceTree", "<group>")
            path = obj.get("path")
            if oid == main_group:
                result: Path | None = project_root / path if path else project_root
            elif tree == "<group>":
                if oid not in parent:
                    problems.append(f"{oid} ({obj.get('path') or obj.get('name')}) is not in any group")
                    result = None
                else:
                    base = resolve(parent[oid], trail + (oid,))
                    result = None if base is None else (base / path if path else base)
            elif tree == "SOURCE_ROOT":
                result = project_root / path if path else project_root
            elif tree == "<absolute>":
                result = Path(path) if path else None
            else:
                result = None  # build-directory relative (for example BUILT_PRODUCTS_DIR)
            cache[oid] = result
            return result

        for oid, obj in objects.items():
            if obj.get("isa") in GROUP_ISAS + ("PBXFileReference",):
                resolve(oid)
        return cache, problems

    def build_file_paths(self, phase: dict | None, paths: dict[str, Path | None]) -> list[str]:
        if phase is None:
            return []
        result = []
        for build_id in phase.get("files", []):
            build = self.objects.get(build_id, {})
            file_ref = build.get("fileRef")
            if file_ref is None:
                result.append(f"<product:{build.get('productRef')}>")
                continue
            path = paths.get(file_ref)
            result.append(rel(path) if path is not None else f"<unresolved:{file_ref}>")
        return result


def rel(path: Path) -> str:
    try:
        return path.resolve().relative_to(ROOT.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def package_manifest() -> str:
    return (ROOT / PACKAGE_NAME / "Package.swift").read_text(encoding="utf-8")


def package_targets(manifest: str) -> dict[str, str]:
    """Target name -> kind ("target", "testTarget", ...) declared in Package.swift."""
    return {name: kind for kind, name in re.findall(
        r"\.(target|testTarget|executableTarget|binaryTarget|macro|plugin)\(\s*name:\s*\"([^\"]+)\"",
        manifest)}


def disk_swift_sources() -> set[str]:
    if not APP_DIR.is_dir():
        return set()
    return {rel(path) for path in APP_DIR.rglob("*.swift") if path.is_file()}


CHECKS: list[tuple[int, str, Callable[[Context, Check], None]]] = []


def check(number: int, title: str) -> Callable:
    def register(function: Callable[[Context, Check], None]) -> Callable:
        CHECKS.append((number, title, function))
        return function
    return register


# ==========================================================================
# 1. Structure and references
# ==========================================================================


@check(1, "pbxproj parses; objectVersion 60; every object reference resolves")
def check_structure(ctx: Context, c: Check) -> None:
    project = ctx.project
    c.require(project.get("archiveVersion") == "1", f"archiveVersion is {project.get('archiveVersion')!r}")
    c.require(project.get("objectVersion") == "60", f"objectVersion is {project.get('objectVersion')!r}, expected 60")
    c.require(project.get("classes") == {}, "classes is not an empty dictionary")
    objects = ctx.objects
    root = project.get("rootObject")
    if c.require(root in objects, f"rootObject {root!r} does not exist"):
        c.require(objects[root].get("isa") == "PBXProject", "rootObject is not a PBXProject")
    for oid, obj in objects.items():
        c.require(bool(OBJECT_ID.fullmatch(oid)), f"object ID {oid!r} is not 24 upper-case hex digits")
        if not c.require(isinstance(obj, dict) and "isa" in obj, f"object {oid} has no isa"):
            continue
        for field, allowed in REFERENCE_FIELDS.items():
            if field not in obj:
                continue
            value = obj[field]
            targets = value if isinstance(value, list) else [value]
            for target in targets:
                if not isinstance(target, str) or target not in objects:
                    c.fail(f"{obj['isa']} {oid}.{field} -> {target!r} does not exist")
                    continue
                target_isa = objects[target].get("isa", "")
                if field == "buildPhases":
                    c.require(target_isa.endswith("BuildPhase"),
                              f"{oid}.buildPhases -> {target} is {target_isa}")
                elif allowed is not None:
                    c.require(target_isa in allowed, f"{oid}.{field} -> {target} is {target_isa}")
        if obj["isa"] == "PBXProject":
            attributes = obj.get("attributes", {}).get("TargetAttributes", {})
            for target in attributes:
                c.require(target in objects, f"TargetAttributes key {target} does not exist")
    referenced: dict[str, int] = {}
    for obj in objects.values():
        if obj.get("isa", "").endswith("BuildPhase"):
            for build_id in obj.get("files", []):
                referenced[build_id] = referenced.get(build_id, 0) + 1
    for build_id, build in ctx.of_isa("PBXBuildFile").items():
        count = referenced.get(build_id, 0)
        c.require(count == 1, f"PBXBuildFile {build_id} is referenced by {count} build phases")
        c.require(("fileRef" in build) != ("productRef" in build),
                  f"PBXBuildFile {build_id} must have exactly one of fileRef/productRef")
    c.note(f"{len(objects)} objects")


# ==========================================================================
# 2. Source membership
# ==========================================================================


@check(2, "Sources phase == every *.swift under Proximeet/, each once; paths exist")
def check_sources(ctx: Context, c: Check) -> None:
    paths, problems = ctx.resolved_paths()
    for problem in problems:
        c.fail(problem)
    for oid, obj in ctx.objects.items():
        isa = obj.get("isa")
        if isa not in GROUP_ISAS + ("PBXFileReference",):
            continue
        if obj.get("sourceTree") == "BUILT_PRODUCTS_DIR":
            continue
        path = paths.get(oid)
        label = obj.get("path") or obj.get("name") or oid
        if path is None:
            c.fail(f"{isa} {label} has no resolvable path")
            continue
        if isa == "PBXFileReference" or obj.get("path"):
            c.require(v_exists(path), f"{isa} {label} -> {rel(path)} does not exist on disk")
        if isa == "PBXFileReference":
            inside_catalog = any(part.endswith(".xcassets") for part in Path(rel(path)).parts[:-1])
            c.require(not inside_catalog, f"asset catalog contents enumerated: {rel(path)}")
    _, target = ctx.app_target()
    sources = ctx.build_file_paths(ctx.phase_of(target, "PBXSourcesBuildPhase"), paths)
    duplicates = sorted({path for path in sources if sources.count(path) > 1})
    c.require(not duplicates, f"compiled more than once: {duplicates}")
    in_phase = set(sources)
    on_disk = disk_swift_sources()
    for path in sorted(on_disk - in_phase):
        c.fail(f"on disk but not compiled: {path}")
    for path in sorted(in_phase - on_disk):
        c.fail(f"compiled but not a Swift file under Proximeet/: {path}")
    for phase_id in target.get("buildPhases", []):
        for path in ctx.build_file_paths(ctx.objects.get(phase_id), paths):
            c.require(not path.startswith(f"{PACKAGE_NAME}/"),
                      f"package source {path} is a member of the app target")
    c.note(f"{len(on_disk)} Swift file(s) on disk, {len(in_phase)} in the Sources phase")
    if not on_disk:
        c.note("no Swift sources exist under Proximeet/ yet")


# ==========================================================================
# 3. Resources
# ==========================================================================


@check(3, "Resources phase contains only catalog, privacy, signature USDZ and studio skybox")
def check_resources(ctx: Context, c: Check) -> None:
    paths, _ = ctx.resolved_paths()
    _, target = ctx.app_target()
    resources = ctx.build_file_paths(ctx.phase_of(target, "PBXResourcesBuildPhase"), paths)
    c.require(sorted(resources) == sorted(EXPECTED_RESOURCES),
              f"Resources phase is {sorted(resources)}, expected {sorted(EXPECTED_RESOURCES)}")
    sources = ctx.build_file_paths(ctx.phase_of(target, "PBXSourcesBuildPhase"), paths)
    non_swift = [path for path in sources if not path.endswith(".swift")]
    c.require(not non_swift, f"non-Swift files in Sources: {non_swift}")
    for oid, obj in ctx.of_isa("PBXFileReference").items():
        path = paths.get(oid)
        if path is None:
            continue
        if rel(path).endswith(".xcassets"):
            c.require(obj.get("lastKnownFileType") == "folder.assetcatalog",
                      f"{rel(path)} lastKnownFileType is {obj.get('lastKnownFileType')!r}")
        if rel(path).endswith(".xcprivacy"):
            c.require(obj.get("lastKnownFileType") == "text.xml",
                      f"{rel(path)} lastKnownFileType is {obj.get('lastKnownFileType')!r}")
        if rel(path).endswith(".skybox"):
            c.require(obj.get("lastKnownFileType") == "file.skybox",
                      "studio skybox must be a compilable skybox resource, not a generic copied folder")
            images = [child for child in path.iterdir() if child.is_file()] if path.is_dir() else []
            c.require(len(images) == 1 and images[0].suffix == ".exr",
                      "studio skybox must contain exactly one EXR image")


# ==========================================================================
# 4. Local package
# ==========================================================================


@check(4, "local package ProximeetDomain linked via XCLocalSwiftPackageReference")
def check_package(ctx: Context, c: Check) -> None:
    local = ctx.of_isa("XCLocalSwiftPackageReference")
    remote = ctx.of_isa("XCRemoteSwiftPackageReference")
    c.require(not remote, f"{len(remote)} XCRemoteSwiftPackageReference object(s) present")
    matching = [oid for oid, obj in local.items() if obj.get("relativePath") == PACKAGE_NAME]
    c.require(len(local) == 1 and len(matching) == 1,
              f"expected exactly one XCLocalSwiftPackageReference {PACKAGE_NAME}, found "
              f"{[obj.get('relativePath') for obj in local.values()]}")
    if matching:
        c.require(matching[0] in ctx.root.get("packageReferences", []),
                  "local package is not listed in PBXProject.packageReferences")
    manifest_path = ROOT / PACKAGE_NAME / "Package.swift"
    if c.require(manifest_path.is_file(), f"{rel(manifest_path)} missing"):
        manifest = package_manifest()
        c.require(re.search(r'\.library\(\s*name:\s*"ProximeetDomain"', manifest) is not None,
                  'Package.swift does not declare .library(name: "ProximeetDomain"')
        c.require(package_targets(manifest).get(PACKAGE_TEST_TARGET) == "testTarget",
                  f'Package.swift does not declare testTarget "{PACKAGE_TEST_TARGET}"')
        c.require(re.search(r"\.package\(\s*url:", manifest) is None,
                  "Package.swift declares a remote package dependency")
    products = {oid: obj for oid, obj in ctx.of_isa("XCSwiftPackageProductDependency").items()
                if obj.get("productName") == PACKAGE_NAME}
    if not c.require(len(products) == 1, f"expected one product dependency {PACKAGE_NAME}"):
        return
    product_id, product = next(iter(products.items()))
    if "package" in product:
        c.require(product["package"] in matching, "product dependency points at another package")
    _, target = ctx.app_target()
    c.require(product_id in target.get("packageProductDependencies", []),
              "target packageProductDependencies does not include ProximeetDomain")
    frameworks = ctx.phase_of(target, "PBXFrameworksBuildPhase")
    linked = [ctx.objects.get(build_id, {}).get("productRef") for build_id in
              (frameworks or {}).get("files", [])]
    c.require(product_id in linked, "Frameworks phase does not link the ProximeetDomain product")


# ==========================================================================
# 5. Build phases
# ==========================================================================


@check(5, "build phases are only Sources, Frameworks, Resources")
def check_phases(ctx: Context, c: Check) -> None:
    for isa in FORBIDDEN_PHASES:
        present = ctx.of_isa(isa)
        c.require(not present, f"{len(present)} {isa} object(s) present")
    for oid, target in ctx.of_isa("PBXNativeTarget").items():
        kinds = [ctx.objects.get(phase, {}).get("isa") for phase in target.get("buildPhases", [])]
        c.require(sorted(kinds) == sorted(ALLOWED_PHASES),
                  f"target {target.get('name')} phases are {kinds}")
        c.require(target.get("buildRules", []) == [], f"target {target.get('name')} has build rules")
    targets = ctx.of_isa("PBXNativeTarget")
    expected = {APP_TARGET: "com.apple.product-type.application",
                UI_TEST_TARGET: "com.apple.product-type.bundle.ui-testing"}
    c.require({target.get("name") for target in targets.values()} == set(expected),
              f"expected app and UI test targets, found {[t.get('name') for t in targets.values()]}")
    for oid, target in targets.items():
        c.require(target.get("productType") == expected.get(target.get("name")),
                  f"target {target.get('name')} productType is {target.get('productType')!r}")


# ==========================================================================
# 6. Build settings
# ==========================================================================


def configurations(ctx: Context, owner: dict) -> dict[str, dict]:
    config_list = ctx.objects.get(owner.get("buildConfigurationList", ""), {})
    result = {}
    for config_id in config_list.get("buildConfigurations", []):
        config = ctx.objects.get(config_id, {})
        result[config.get("name", config_id)] = config.get("buildSettings", {})
    return result


@check(6, "target build settings: Goseng bundle ID and automatic signing, iOS 17, generated Info.plist, no entitlements")
def check_settings(ctx: Context, c: Check) -> None:
    project_configs = configurations(ctx, ctx.root)
    _, target = ctx.app_target()
    target_configs = configurations(ctx, target)
    for name in ("Debug", "Release"):
        if not (c.require(name in project_configs, f"project has no {name} configuration")
                and c.require(name in target_configs, f"target has no {name} configuration")):
            continue
        project_settings, target_settings = project_configs[name], target_configs[name]
        effective = {**project_settings, **target_settings}
        c.require(target_settings.get("PRODUCT_BUNDLE_IDENTIFIER") == EXPECTED_BUNDLE_ID,
                  f"{name}: PRODUCT_BUNDLE_IDENTIFIER is {target_settings.get('PRODUCT_BUNDLE_IDENTIFIER')!r}")
        c.require(target_settings.get("DEVELOPMENT_TEAM") == EXPECTED_DEVELOPMENT_TEAM,
                  f"{name}: DEVELOPMENT_TEAM must match Goseng LLC")
        c.require(effective.get("CODE_SIGN_STYLE") == "Automatic",
                  f"{name}: CODE_SIGN_STYLE must be Automatic")
        for level, settings in (("project", project_settings), ("target", target_settings)):
            team = [key for key, value in settings.items()
                    if key.split("[")[0] == "DEVELOPMENT_TEAM"
                    and value not in ("", None, EXPECTED_DEVELOPMENT_TEAM)]
            c.require(not team, f"{name}/{level}: unexpected DEVELOPMENT_TEAM in {team}")
            entitlements = [key for key in settings if key.split("[")[0] == "CODE_SIGN_ENTITLEMENTS"]
            c.require(not entitlements, f"{name}/{level}: CODE_SIGN_ENTITLEMENTS present")
            usage = [key for key in settings
                     if re.fullmatch(r"INFOPLIST_KEY_NS\w*UsageDescription", key.split("[")[0])]
            c.require(not usage, f"{name}/{level}: usage-description keys {usage}")
            profiles = [key for key in settings if key.split("[")[0].startswith("PROVISIONING_PROFILE")]
            c.require(not profiles, f"{name}/{level}: provisioning profile keys {profiles}")
        c.require(effective.get("IPHONEOS_DEPLOYMENT_TARGET") == "17.0",
                  f"{name}: IPHONEOS_DEPLOYMENT_TARGET is {effective.get('IPHONEOS_DEPLOYMENT_TARGET')!r}")
        c.require(effective.get("GENERATE_INFOPLIST_FILE") == "YES",
                  f"{name}: GENERATE_INFOPLIST_FILE is {effective.get('GENERATE_INFOPLIST_FILE')!r}")
        c.require(effective.get("ASSETCATALOG_COMPILER_APPICON_NAME") == "AppIcon",
                  f"{name}: ASSETCATALOG_COMPILER_APPICON_NAME is "
                  f"{effective.get('ASSETCATALOG_COMPILER_APPICON_NAME')!r}")
        c.require(effective.get("SDKROOT") == "iphoneos", f"{name}: SDKROOT is {effective.get('SDKROOT')!r}")


# ==========================================================================
# 7. Scheme
# ==========================================================================


def _test_sources(container: str, name: str) -> list[Path]:
    folder = ROOT / UI_TEST_TARGET if container == "container:Proximeet.xcodeproj" else \
        ROOT / PACKAGE_NAME / "Tests" / name
    return sorted(path for path in folder.rglob("*.swift") if path.is_file()) if folder.is_dir() else []


def check_test_plan(c: Check, reference: str, targets: dict[str, dict],
                    manifest_targets: dict[str, str],
                    selected: dict[str, set[str]] | None = None) -> list[tuple[str, str]]:
    """Validate one scheme test plan; return its testables as (name, container).

    `selected`, when given, collects every UI test method the plan selects, by class."""
    path = ROOT / reference[len("container:"):]
    if not c.require(reference.startswith("container:") and v_is_file(path), f"test plan {reference} missing"):
        return []
    label = path.name
    try:
        plan = json.loads(v_read_text(path))
    except ValueError as error:
        c.fail(f"{label} is not JSON: {error}")
        return []
    c.require(plan.get("version") == 1, f"{label}: version is {plan.get('version')!r}, not 1")
    options = [plan.get("defaultOptions", {})] + [item.get("options", {}) for item in plan.get("configurations", [])]
    for option in options:
        # A repeated or retried test is not a verdict: every selected test must execute once and pass.
        c.require(not {"testRepetitionMode", "maximumTestRepetitions"} & set(option),
                  f"{label}: test repetition is set")
    environment = {entry.get("key"): entry.get("value") for entry in plan.get("defaultOptions", {}).get(
        "environmentVariableEntries", []) if entry.get("enabled", True)}
    testables = []
    for entry in plan.get("testTargets", []):
        target = entry.get("target", {})
        container, identifier, name = (target.get(key) for key in ("containerPath", "identifier", "name"))
        testables.append((name, container))
        c.require(entry.get("parallelizable") is False, f"{label}: {name} must set parallelizable false")
        if container == "container:Proximeet.xcodeproj":
            native = targets.get(identifier)
            c.require(native is not None and native.get("name") == name == UI_TEST_TARGET,
                      f"{label}: {identifier} is not the {UI_TEST_TARGET} native target")
            c.require(bool(entry.get("selectedTests")), f"{label}: {name} must select its tests explicitly")
        elif container == f"container:{PACKAGE_NAME}":
            c.require(identifier == name and manifest_targets.get(name) == "testTarget",
                      f"{label}: {name} is not a {PACKAGE_NAME} testTarget")
        else:
            c.fail(f"{label}: unexpected containerPath {container!r}")
            continue
        texts = {source: source.read_text(encoding="utf-8") for source in _test_sources(container, name)}
        tests = entry.get("selectedTests", []) + entry.get("skippedTests", [])
        c.require(len(tests) == len(set(tests)), f"{label}: {name} lists a test twice")
        for test in tests:
            match = re.fullmatch(r"(\w+)(?:/(\w+)\(\))?", test)
            if not c.require(match is not None, f"{label}: malformed test identifier {test!r}"):
                continue
            owner, method = match.groups()
            files = [source for source, text in texts.items()
                     if re.search(rf"\bclass\s+{owner}\s*:", text)]
            if not c.require(len(files) == 1, f"{label}: class {owner} is not declared once in {name}"):
                continue
            text = texts[files[0]]
            c.require(method is None or re.search(rf"\bfunc\s+{method}\(", text) is not None,
                      f"{label}: {owner} has no func {method}(")
            flag = re.search(r'reviewFlag\s*=\s*"(PROXIMEET_\w+)"', text)
            required_flag = REQUIRED_PLAN_FLAGS.get(owner)
            if test in entry.get("selectedTests", []):
                # Without its flag the class skips itself, and a skipped test is not a pass.
                flags = ({flag.group(1)} if flag else set()) | ({required_flag} if required_flag else set())
                for name_of_flag in sorted(flags):
                    c.require(environment.get(name_of_flag) == "1", f"{label}: {owner} needs {name_of_flag}=1")
                if required_flag:
                    c.require(f'"{required_flag}"' in text, f"{label}: {owner} does not read {required_flag}")
            if selected is not None and method is not None and test in entry.get("selectedTests", []):
                selected.setdefault(owner, set()).add(method)
        c.note(f"{label}: {name}, {len(entry.get('selectedTests', []))} selected, "
               f"{len(entry.get('skippedTests', []))} skipped")
    return testables


@check(7, "shared scheme references the app and UI tests; its test plans select existing tests")
def check_scheme(ctx: Context, c: Check) -> None:
    for path in (WORKSPACE_DATA, WORKSPACE_CHECKS):
        c.require(v_is_file(path), f"{rel(path)} missing")
    if v_is_file(WORKSPACE_DATA):
        workspace = ET.fromstring(v_read_bytes(WORKSPACE_DATA))
        c.require([ref.get("location") for ref in workspace.iter("FileRef")] == ["self:"],
                  "contents.xcworkspacedata does not reference self:")
    if v_is_file(WORKSPACE_CHECKS):
        checks = plistlib.loads(v_read_bytes(WORKSPACE_CHECKS))
        c.require(checks.get("IDEDidComputeMac32BitWarning") is True,
                  "IDEDidComputeMac32BitWarning is not true")
    if not c.require(v_is_file(SCHEME), f"{rel(SCHEME)} missing"):
        return
    scheme = ET.fromstring(v_read_bytes(SCHEME))
    c.require(scheme.tag == "Scheme", "scheme root element is not <Scheme>")
    targets = ctx.of_isa("PBXNativeTarget")
    manifest_targets = package_targets(package_manifest())
    local_packages = {obj.get("relativePath") for obj in ctx.of_isa("XCLocalSwiftPackageReference").values()}
    for reference in scheme.iter("BuildableReference"):
        container = reference.get("ReferencedContainer", "")
        blueprint = reference.get("BlueprintIdentifier")
        name = reference.get("BlueprintName")
        if container == "container:Proximeet.xcodeproj":
            target = targets.get(blueprint)
            if not c.require(target is not None, f"BlueprintIdentifier {blueprint} is not a native target"):
                continue
            c.require(target.get("name") == name,
                      f"BlueprintName {name!r} != target name {target.get('name')!r}")
            product = ctx.objects.get(target.get("productReference", ""), {})
            c.require(product.get("path") == reference.get("BuildableName"),
                      f"BuildableName {reference.get('BuildableName')!r} != product {product.get('path')!r}")
        elif container.startswith("container:"):
            package_dir = container[len("container:"):]
            c.require((ROOT / package_dir / "Package.swift").is_file(),
                      f"{container} has no Package.swift")
            c.require(package_dir in local_packages, f"{container} is not a local package reference")
            c.require(name in manifest_targets, f"{name!r} is not a target in {package_dir}/Package.swift")
            c.require(blueprint == name, f"package BlueprintIdentifier {blueprint!r} != BlueprintName {name!r}")
        else:
            c.fail(f"unexpected ReferencedContainer {container!r}")
    build_names = [ref.get("BlueprintName") for entry in scheme.iter("BuildActionEntry")
                   for ref in entry.iter("BuildableReference")]
    c.require(APP_TARGET in build_names, "BuildAction does not build the app")
    c.require(UI_TEST_TARGET in build_names, "BuildAction does not build the UI test bundle")
    # The Test action runs committed test plans (Room and Wave verification in Xcode Cloud,
    # docs/verification/room-xcode-cloud-verification.md and wave-xcode-cloud-verification.md), so the
    # testables live in the plans: one source of truth, never a scheme list beside them and never an
    # autocreated plan.
    test_action = scheme.find("TestAction")
    c.require(test_action is not None and test_action.find("Testables") is None
              and test_action.get("shouldAutocreateTestPlan") is None,
              "TestAction must select its tests only through its test plans")
    plans = [(ref.get("reference", ""), ref.get("default") == "YES") for ref in scheme.iter("TestPlanReference")]
    expected = [f"container:{path}" for path in EXPECTED_TEST_PLANS]
    c.require([path for path, _ in plans] == expected,
              f"TestAction plans {[path for path, _ in plans]} != {expected}")
    c.require([default for _, default in plans] == [True] + [False] * (len(plans) - 1),
              f"{EXPECTED_TEST_PLANS[0]} must be the one default test plan")
    testables: list[tuple[str, str]] = []
    selected: dict[str, set[str]] = {}
    for reference, _ in plans:
        testables += check_test_plan(c, reference, targets, manifest_targets, selected)
    # Every plan runs under the verified Room plans' options (coverage off, 900/1200-s allowances,
    # timeouts on, en/US, captures kept): only the environment may differ, and only by adding flags,
    # so a later chapter's plan can never run a test under weaker settings than the Room's.
    loaded = []
    for reference, _ in plans:
        path = ROOT / reference[len("container:"):]
        try:
            loaded.append((path.name, json.loads(v_read_text(path)).get("defaultOptions", {})))
        except (OSError, ValueError):
            continue  # already reported by check_test_plan
    if loaded:
        base_label, base = loaded[0]
        base_environment = {(entry.get("key"), entry.get("value"))
                            for entry in base.get("environmentVariableEntries", [])}
        for label, options in loaded[1:]:
            others = {key: value for key, value in options.items() if key != "environmentVariableEntries"}
            c.require(others == {key: value for key, value in base.items() if key != "environmentVariableEntries"},
                      f"{label}: defaultOptions differ from {base_label} beyond its environment")
            environment = {(entry.get("key"), entry.get("value"))
                           for entry in options.get("environmentVariableEntries", [])}
            c.require(base_environment <= environment, f"{label}: drops {sorted(base_environment - environment)}")
    texts = [source.read_text(encoding="utf-8") for source in _test_sources("container:Proximeet.xcodeproj", "")]
    for owner in COMPLETE_PLAN_CLASSES:
        declared = [text for text in texts if re.search(rf"\bclass\s+{owner}\s*:", text)]
        if not c.require(len(declared) == 1, f"class {owner} is not declared once in {UI_TEST_TARGET}"):
            continue
        methods = set(re.findall(r"\bfunc\s+(test\w*)\s*\(", declared[0]))
        missing = sorted(methods - selected.get(owner, set()))
        c.require(not missing, f"{owner}: no test plan selects {missing}")
        c.note(f"{owner}: all {len(methods)} test methods selected by the plans")
    c.require((PACKAGE_TEST_TARGET, f"container:{PACKAGE_NAME}") in testables,
              f"no test plan includes {PACKAGE_TEST_TARGET}")
    c.require((UI_TEST_TARGET, "container:Proximeet.xcodeproj") in testables,
              f"no test plan includes {UI_TEST_TARGET}")
    launch = scheme.find("LaunchAction")
    if c.require(launch is not None, "no LaunchAction"):
        runnable = launch.find("BuildableProductRunnable/BuildableReference")
        c.require(runnable is not None and runnable.get("BlueprintName") == APP_TARGET,
                  "LaunchAction does not run the app")
        c.require(launch.get("buildConfiguration") == "Debug", "LaunchAction is not Debug")
    for action, config in (("TestAction", "Debug"), ("ProfileAction", "Release"),
                           ("AnalyzeAction", "Debug"), ("ArchiveAction", "Release")):
        element = scheme.find(action)
        c.require(element is not None and element.get("buildConfiguration") == config,
                  f"{action} missing or not {config}")
    arguments = list(scheme.iter("CommandLineArgument"))
    for argument in arguments:
        c.require(argument.get("isEnabled") == "NO",
                  f"launch argument {argument.get('argument')!r} is enabled by default")
    c.note(f"{len(arguments)} launch argument(s), all disabled by default" if arguments else "no launch arguments")


# ==========================================================================
# 8. Assets
# ==========================================================================


def read_png(data: bytes) -> tuple[dict, bytes]:
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError("not a PNG signature")
    position, chunks, idat = 8, [], b""
    header: dict = {}
    while position < len(data):
        if position + 8 > len(data):
            raise ValueError("truncated chunk header")
        length, tag = struct.unpack(">I4s", data[position:position + 8])
        body = data[position + 8:position + 8 + length]
        crc_bytes = data[position + 8 + length:position + 12 + length]
        if len(body) != length or len(crc_bytes) != 4:
            raise ValueError(f"truncated {tag!r} chunk")
        if struct.unpack(">I", crc_bytes)[0] != zlib.crc32(tag + body) & 0xFFFFFFFF:
            raise ValueError(f"bad CRC in {tag!r} chunk")
        chunks.append(tag)
        if tag == b"IHDR":
            width, height, depth, color, compression, filtering, interlace = struct.unpack(">IIBBBBB", body)
            header = {"width": width, "height": height, "depth": depth, "color": color,
                      "compression": compression, "filter": filtering, "interlace": interlace}
        elif tag == b"IDAT":
            idat += body
        position += 12 + length
        if tag == b"IEND":
            break
    if not chunks or chunks[0] != b"IHDR" or chunks[-1] != b"IEND":
        raise ValueError(f"chunk order {chunks}")
    header["chunks"] = [tag.decode("latin-1") for tag in chunks]
    return header, zlib.decompress(idat)


def unfilter(raw: bytes, width: int, height: int, bpp: int) -> bytes:
    stride = width * bpp
    out = bytearray()
    previous = bytearray(stride)
    position = 0
    for _ in range(height):
        kind = raw[position]
        line = bytearray(raw[position + 1:position + 1 + stride])
        position += 1 + stride
        if kind == 1:
            for i in range(bpp, stride):
                line[i] = (line[i] + line[i - bpp]) & 0xFF
        elif kind == 2:
            for i in range(stride):
                line[i] = (line[i] + previous[i]) & 0xFF
        elif kind == 3:
            for i in range(stride):
                left = line[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + ((left + previous[i]) >> 1)) & 0xFF
        elif kind == 4:
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                b = previous[i]
                cc = previous[i - bpp] if i >= bpp else 0
                p = a + b - cc
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - cc)
                predictor = a if pa <= pb and pa <= pc else (b if pb <= pc else cc)
                line[i] = (line[i] + predictor) & 0xFF
        elif kind != 0:
            raise ValueError(f"invalid filter type {kind}")
        out += line
        previous = line
    return bytes(out)


def check_icon_png(c: Check, data: bytes, name: str) -> None:
    """Structural PNG checks: chunk CRCs, IHDR, no alpha, scanline length, safe margin."""
    try:
        header, raw = read_png(data)
    except (ValueError, zlib.error, struct.error) as error:
        c.fail(f"{name}: {error}")
        return
    c.require((header["width"], header["height"]) == (1024, 1024),
              f"{name} is {header['width']}x{header['height']}")
    c.require(header["depth"] == 8, f"{name} bit depth {header['depth']}")
    c.require(header["color"] == 2, f"{name} colour type {header['color']} (need 2: RGB, no alpha)")
    c.require(header["interlace"] == 0, f"{name} is interlaced")
    c.require("tRNS" not in header["chunks"], f"{name} has a tRNS transparency chunk")
    expected = 1024 * (1 + 3 * 1024)
    if not c.require(len(raw) == expected, f"{name} decompressed {len(raw)} bytes, expected {expected}"):
        return
    try:
        pixels = unfilter(raw, 1024, 1024, 3)
    except ValueError as error:
        c.fail(f"{name}: {error}")
        return
    background = pixels[0:3]
    margin = 120
    edge_row = background * 1024
    edge_cols = background * margin
    clean = all(
        pixels[y * 3072:(y + 1) * 3072] == edge_row if (y < margin or y >= 1024 - margin)
        else (pixels[y * 3072:y * 3072 + 3 * margin] == edge_cols
              and pixels[(y + 1) * 3072 - 3 * margin:(y + 1) * 3072] == edge_cols)
        for y in range(1024)
    )
    c.require(clean, f"{name}: artwork is not inside a {margin} px uniform safe margin")
    colours = len({pixels[i:i + 3] for i in range(0, len(pixels), 3)})
    c.require(colours > 16, f"{name}: only {colours} distinct colours (blank artwork?)")
    c.note(f"{name}: 1024x1024 RGB8, chunks {header['chunks']}, {len(data)} bytes, "
           f"background #{background.hex().upper()}, {colours} distinct colours")


@check(8, "asset catalog: Contents.json files, AppIcon 1024x1024 RGB PNG, AccentColor")
def check_assets(ctx: Context, c: Check) -> None:
    root_contents = CATALOG / "Contents.json"
    if c.require(v_is_file(root_contents), f"{rel(root_contents)} missing"):
        info = json.loads(v_read_text(root_contents)).get("info", {})
        c.require(info.get("version") == 1, "Assets.xcassets/Contents.json info.version != 1")
    icon_contents = CATALOG / "AppIcon.appiconset" / "Contents.json"
    if c.require(v_is_file(icon_contents), f"{rel(icon_contents)} missing"):
        images = json.loads(v_read_text(icon_contents)).get("images", [])
        files = [image.get("filename") for image in images if image.get("filename")]
        c.require(len(images) == 1 and images[0].get("size") == "1024x1024"
                  and images[0].get("idiom") == "universal" and images[0].get("platform") == "ios",
                  f"AppIcon is not a single universal iOS 1024x1024 image: {images}")
        for name in files:
            png = icon_contents.parent / name
            if c.require(v_is_file(png), f"AppIcon references missing {name}"):
                check_icon_png(c, v_read_bytes(png), name)
    accent = CATALOG / "AccentColor.colorset" / "Contents.json"
    if c.require(v_is_file(accent), f"{rel(accent)} missing"):
        colors = json.loads(v_read_text(accent)).get("colors", [])
        c.require(any("color" in entry and "components" in entry["color"] for entry in colors),
                  "AccentColor has no color entry")


# ==========================================================================
# 9. Privacy manifest
# ==========================================================================


@check(9, "PrivacyInfo.xcprivacy declares no tracking, collection or required-reason APIs")
def check_privacy(ctx: Context, c: Check) -> None:
    if not c.require(v_is_file(PRIVACY), f"{rel(PRIVACY)} missing"):
        return
    manifest = plistlib.loads(v_read_bytes(PRIVACY))
    c.require(manifest.get("NSPrivacyTracking") is False, "NSPrivacyTracking is not false")
    for key in ("NSPrivacyTrackingDomains", "NSPrivacyCollectedDataTypes", "NSPrivacyAccessedAPITypes"):
        c.require(manifest.get(key) == [], f"{key} is {manifest.get(key)!r}, expected []")


# ==========================================================================
# 10. Reproducibility
# ==========================================================================


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot import {rel(path)}")
    module = importlib.util.module_from_spec(spec)
    sys.dont_write_bytecode = True  # stay read-only: no __pycache__
    spec.loader.exec_module(module)
    return module


def compare_rendered(c: Check, rendered: dict[str, bytes], show_diff: bool, label: str) -> None:
    for relative, expected in rendered.items():
        path = ROOT / relative
        if not path.is_file():
            c.fail(f"{relative} missing (run python3 scripts/{label}.py)")
            actual = b""
        else:
            actual = path.read_bytes()
            if actual == expected:
                continue
            c.fail(f"{relative} differs from {label} render()")
        if show_diff and not relative.endswith(".png"):
            diff = difflib.unified_diff(
                actual.decode("utf-8", "replace").splitlines(keepends=True),
                expected.decode("utf-8", "replace").splitlines(keepends=True),
                fromfile=f"disk/{relative}", tofile=f"render/{relative}")
            sys.stdout.writelines(diff)


@check(10, "on-disk project and assets are byte-identical to their generators' render()")
def check_reproducible(ctx: Context, c: Check) -> None:
    generator = load_module("proximeet_generate_project", ROOT / "scripts" / "generate_project.py")
    first = generator.render(ROOT)
    second = generator.render(ROOT)
    c.require(first == second, "generate_project.render() is not stable across two calls")
    expected_files = {
        "Proximeet.xcodeproj/project.pbxproj",
        "Proximeet.xcodeproj/project.xcworkspace/contents.xcworkspacedata",
        "Proximeet.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist",
        "Proximeet.xcodeproj/xcshareddata/xcschemes/Proximeet.xcscheme",
    }
    c.require(set(first) == expected_files, f"render() produced {sorted(first)}")
    try:
        OpenStepParser(first["Proximeet.xcodeproj/project.pbxproj"]).parse()
    except ParseError as error:
        c.fail(f"rendered pbxproj does not parse: {error}")
    compare_rendered(c, {key: value.encode("utf-8") for key, value in first.items()},
                     ctx.show_diff, "generate_project")
    assets = load_module("proximeet_generate_app_assets", ROOT / "scripts" / "generate_app_assets.py")
    rendered_assets = assets.render()
    c.require(rendered_assets == assets.render(), "generate_app_assets.render() is not stable across two calls")
    for relative, expected in rendered_assets.items():
        if relative.endswith(".png"):
            check_icon_png(c, expected, f"render:{relative.rsplit('/', 1)[-1]}")
    for relative, expected in rendered_assets.items():
        path = ROOT / relative
        if relative.endswith(".png") and path.is_file() and path.read_bytes() != expected:
            # Different zlib builds may compress differently; compare decoded pixels.
            if assets.decoded_png_data(path.read_bytes()) == assets.decoded_png_data(expected):
                c.note(f"{relative}: compressed bytes differ, decoded pixels identical")
                rendered_assets[relative] = path.read_bytes()
    compare_rendered(c, rendered_assets, ctx.show_diff, "generate_app_assets")


# ==========================================================================
# 11. Guardrails
# ==========================================================================

FORBIDDEN_APIS = (
    "URLSession", "URLRequest", "UserDefaults", "@AppStorage", "@SceneStorage", "FileManager",
    "SecItem", "Keychain", "CoreLocation", "CLLocation", "CoreBluetooth", "MultipeerConnectivity",
    "NWConnection", "import Network", "Firebase", "Mixpanel", "Amplitude", "import Segment",
    "TimelineView", "repeatForever", "Timer.", "asyncAfter", "Task.sleep", "CADisplayLink",
    "import Metal", "HaloCore", "app.projecthalo",
)
# SDK names that must start an identifier (so `shimmerAmplitude` is not flagged).
WORD_START_APIS = {"Firebase", "Mixpanel", "Amplitude"}
API_PATTERNS = tuple(
    (token, re.compile((r"(?<![A-Za-z0-9_])" if token in WORD_START_APIS else "") + re.escape(token)))
    for token in FORBIDDEN_APIS
)
DISHONEST_PHRASES = (
    "age verified", "identity verified", "you're verified", "you are verified",
    "locks only when you join", "visible only after venue check-in", "checked in", "you're live",
    "is nearby", "sign in with",
)
# Approved copy that contains a phrase above but makes no claim about the guest: each entry is the exact
# literal, the phrase it may contain, and where it was approved. Nothing else is excused.
APPROVED_COPY_EXCEPTIONS = {
    # Room waiting (chapter 08, Figma 67:341): explains a future venue privacy threshold; nobody is
    # checked in by the demo.
    "Introductions appear only when a venue session has enough people checked in.": "checked in",
}
# Domain sources that hold visible copy, scanned for dishonest copy like the app's own sources. WaveDemo.swift
# holds the approved Wave copy (chapter 09, Figma page 74:567); none of it needs an exception above.
COPY_SOURCES = ("ProximeetDomain/Sources/ProximeetDomain/RoomDemo.swift",
                "ProximeetDomain/Sources/ProximeetDomain/WaveDemo.swift")
# Built by concatenation so this file does not match its own repository scan.
REPOSITORY_PATTERNS = (
    ("legacy bundle identifier", re.compile(re.escape("app.projecthalo" + ".lab"))),
    ("unexpected development team", re.compile(
        "DEVELOPMENT_TEAM" + r'\s*=\s*"?(?!' + re.escape(EXPECTED_DEVELOPMENT_TEAM)
        + r'(?:[";\s]|$))[A-Z0-9]+')),
    ("CI workflow reference", re.compile(re.escape(".github" + "/workflows"))),
)
REPOSITORY_SKIP_DIRS = {".git", ".build", ".claude-run", "docs", "__pycache__"}
BINARY_SUFFIXES = {".png", ".jpg", ".jpeg", ".pdf", ".o", ".a", ".pcm", ".swiftmodule", ".zip"}


def lex_swift(text: str) -> tuple[str, list[tuple[int, str]]]:
    """Return (code with comments blanked, [(line, literal text)]).

    Handles // and nested /* */ comments, "..." and multi-line \"\"\" strings,
    raw strings (#"..."#) and \\( ... ) interpolation. Newlines are preserved so
    line numbers stay correct.
    """
    code: list[str] = []
    literals: list[tuple[int, str]] = []
    n = len(text)
    state = {"i": 0, "line": 1}

    def emit(segment: str) -> None:
        code.append(segment)
        state["line"] += segment.count("\n")

    def scan_code(nested: bool) -> None:
        depth = 0
        while state["i"] < n:
            i = state["i"]
            if text.startswith("//", i):
                end = text.find("\n", i)
                end = n if end < 0 else end
                emit(" " * (end - i))
                state["i"] = end
                continue
            if text.startswith("/*", i):
                level, j = 0, i
                while j < n:
                    if text.startswith("/*", j):
                        level, j = level + 1, j + 2
                    elif text.startswith("*/", j):
                        level, j = level - 1, j + 2
                        if level == 0:
                            break
                    else:
                        j += 1
                emit("".join("\n" if ch == "\n" else " " for ch in text[i:j]))
                state["i"] = j
                continue
            char = text[i]
            if char in "#\"":
                k = i
                while k < n and text[k] == "#":
                    k += 1
                if k < n and text[k] == '"':
                    scan_string(k - i, k)
                    continue
            if nested:
                if char == "(":
                    depth += 1
                elif char == ")":
                    if depth == 0:
                        return
                    depth -= 1
            emit(char)
            state["i"] = i + 1

    def scan_string(hashes: int, quote_at: int) -> None:
        multiline = text.startswith('"""', quote_at)
        opener = "#" * hashes + ('"""' if multiline else '"')
        closer = ('"""' if multiline else '"') + "#" * hashes
        escape = "\\" + "#" * hashes
        start_line = state["line"]
        emit(opener)
        state["i"] = quote_at + (3 if multiline else 1)
        content: list[str] = []
        while state["i"] < n:
            i = state["i"]
            if text.startswith(closer, i):
                emit(closer)
                state["i"] = i + len(closer)
                break
            if text.startswith(escape, i):
                after = i + len(escape)
                if after < n and text[after] == "(":
                    emit(text[i:after + 1])
                    state["i"] = after + 1
                    scan_code(nested=True)
                    if state["i"] < n:
                        emit(")")
                        state["i"] += 1
                    content.append(" ")
                    continue
                emit(text[i:after + 1])
                content.append(text[after:after + 1])
                state["i"] = after + 1
                continue
            char = text[i]
            if char == "\n" and not multiline:
                break  # unterminated single-line literal; resume as code
            content.append(char)
            emit(char)
            state["i"] = i + 1
        literals.append((start_line, "".join(content)))

    scan_code(nested=False)
    return "".join(code), literals


def scan_swift(text: str) -> list[tuple[int, str]]:
    """[(line, finding)] for forbidden APIs (comments ignored) and dishonest copy (literals only)."""
    code, literals = lex_swift(text)
    findings: list[tuple[int, str]] = []
    for number, line in enumerate(code.split("\n"), start=1):
        for token, pattern in API_PATTERNS:
            if pattern.search(line):
                findings.append((number, f"forbidden API {token!r}"))
    for start_line, literal in literals:
        for match in re.finditer(r"\bVERIFIED\b", literal):
            findings.append((start_line + literal.count("\n", 0, match.start()),
                             "dishonest copy 'VERIFIED'"))
        lowered = literal.lower().replace("’", "'")
        for phrase in DISHONEST_PHRASES:
            index = lowered.find(phrase)
            if index >= 0 and APPROVED_COPY_EXCEPTIONS.get(literal.strip()) == phrase:
                continue
            if index >= 0:
                findings.append((start_line + literal.count("\n", 0, index),
                                 f"dishonest copy {phrase!r} in {literal.strip()[:60]!r}"))
    return findings


# Known-answer fixture proving the scanner is not vacuous: comment-only tokens and
# `//` inside a raw string must not hide or create findings.
SCANNER_FIXTURE = (
    "import SwiftUI // URLSession mentioned in a comment\n"
    "/* UserDefaults in a block /* nested */ comment */\n"
    "let tick = Timer.publish(every: 1, on: .main, in: .common)\n"
    'let a = Text(#"path // not a comment"#); let r = URLRequest(url: u)\n'
    'let b = Text("Hello \\(name.uppercased()) \\"quoted\\"")\n'
    'let c = Text("""\n    Age VERIFIED\n    """)\n'
    "let d = Text(\"You’re verified\")\n"
    "let shimmerAmplitude = 2.0\n"
    'let e = Text("Introductions appear only when a venue session has enough people checked in.")\n'
    'let f = Text("You are checked in.")\n'
)
SCANNER_EXPECTED = [
    (3, "forbidden API 'Timer.'"),
    (4, "forbidden API 'URLRequest'"),
    (7, "dishonest copy 'VERIFIED'"),
    (7, "dishonest copy 'age verified' in 'Age VERIFIED'"),
    (9,"dishonest copy \"you're verified\" in 'You’re verified'"),
    (12, "dishonest copy 'checked in' in 'You are checked in.'"),
]


# The Wave (chapter 09) is a fictional, local demo: nothing is sent, delivered, timed or logged. Its two
# sources are held to a stricter list on top of the app-wide one: no clock, scheduling, notification or
# logging API in code, and no delivery or presence claim in copy.
WAVE_SOURCES = ("Proximeet/Scenes/WaveView.swift", "ProximeetDomain/Sources/ProximeetDomain/WaveDemo.swift")
WAVE_APIS = ("Date(", "Date.now", "Clock", "DispatchQueue", ".delay(", "NotificationCenter", "print(",
             "Logger", "os_log", "NSLog")
WAVE_API_PATTERNS = tuple((token, re.compile(re.escape(token))) for token in WAVE_APIS)
WAVE_PHRASES = ("delivered", "online now", "read receipt", "typing", "notified")


def scan_wave(text: str) -> list[tuple[int, str]]:
    """[(line, finding)] for the Wave-only APIs (comments ignored) and phrases (literals only)."""
    code, literals = lex_swift(text)
    findings: list[tuple[int, str]] = []
    for number, line in enumerate(code.split("\n"), start=1):
        for token, pattern in WAVE_API_PATTERNS:
            if pattern.search(line):
                findings.append((number, f"Wave forbids {token!r}"))
    for start_line, literal in literals:
        lowered = literal.lower()
        for phrase in WAVE_PHRASES:
            index = lowered.find(phrase)
            if index >= 0:
                findings.append((start_line + literal.count("\n", 0, index),
                                 f"Wave copy claims {phrase!r} in {literal.strip()[:60]!r}"))
    return findings


WAVE_FIXTURE = (
    "// Nothing is delivered and no Clock is read; a comment may say so.\n"
    "let now = Date.now\n"
    "withAnimation(.easeOut(duration: 0.8).delay(0.2)) { joined = true }\n"
    'let a = Text("Wave delivered")\n'
    'let b = Text("Nothing is sent.")\n'
    "let clock = ContinuousClock()\n"
)
WAVE_EXPECTED = [
    (2, "Wave forbids 'Date.now'"),
    (3, "Wave forbids '.delay('"),
    (4, "Wave copy claims 'delivered' in 'Wave delivered'"),
    (6, "Wave forbids 'Clock'"),
]


@check(11, "guardrails: no persistence/network/tracking/timing APIs or dishonest copy")
def check_guardrails(ctx: Context, c: Check) -> None:
    self_test = sorted(scan_swift(SCANNER_FIXTURE))
    c.require(self_test == SCANNER_EXPECTED,
              f"scanner self-test mismatch: got {self_test}, expected {SCANNER_EXPECTED}")
    swift_files = sorted(APP_DIR.rglob("*.swift")) if APP_DIR.is_dir() else []
    for name in COPY_SOURCES:
        # A moved or renamed copy source would otherwise drop out of the scan without a word.
        if c.require((ROOT / name).is_file(), f"copy source {name} missing"):
            swift_files.append(ROOT / name)
    for path in swift_files:
        for number, finding in scan_swift(path.read_text(encoding="utf-8")):
            c.fail(f"{rel(path)}:{number}: {finding}")
    c.note(f"scanner self-test passed; scanned {len(swift_files)} Swift file(s) under Proximeet/ and the domain copy sources"
           if self_test == SCANNER_EXPECTED else f"scanned {len(swift_files)} Swift file(s)")
    wave_test = sorted(scan_wave(WAVE_FIXTURE))
    c.require(wave_test == WAVE_EXPECTED,
              f"Wave scanner self-test mismatch: got {wave_test}, expected {WAVE_EXPECTED}")
    wave_scanned = 0
    for name in WAVE_SOURCES:
        if c.require((ROOT / name).is_file(), f"Wave source {name} missing"):
            wave_scanned += 1
            for number, finding in scan_wave((ROOT / name).read_text(encoding="utf-8")):
                c.fail(f"{name}:{number}: {finding}")
    c.note(f"Wave scanner self-test passed; {wave_scanned} Wave source(s) free of clock, scheduling, notification "
           "and logging APIs and of delivery or presence copy" if wave_test == WAVE_EXPECTED
           else f"scanned {wave_scanned} Wave source(s)")
    scanned = 0
    for directory, subdirectories, files in os.walk(ROOT):
        subdirectories[:] = sorted(d for d in subdirectories if d not in REPOSITORY_SKIP_DIRS)
        here = Path(directory)
        if here.name == ".github" and "workflows" in subdirectories:
            c.fail(f"{rel(here / 'workflows')} exists")
        for name in sorted(files):
            path = here / name
            if name in REPOSITORY_SKIP_DIRS or path.suffix.lower() in BINARY_SUFFIXES:
                continue
            try:
                if path.stat().st_size > 5_000_000:
                    continue
                text = path.read_bytes().decode("utf-8", "ignore")
            except OSError:
                continue
            scanned += 1
            for label, pattern in REPOSITORY_PATTERNS:
                for match in pattern.finditer(text):
                    line = text.count("\n", 0, match.start()) + 1
                    c.fail(f"{rel(path)}:{line}: {label} ({match.group(0)!r})")
    c.note(f"repository scan covered {scanned} text file(s) (excluding .git, .build, .claude-run, docs)")


# ==========================================================================
# 12. Referenced raster art
# ==========================================================================

# Image("Name") and Image(decorative: "Name") literals in app code. SF Symbols use
# Image(systemName:) and are not asset-catalog references.
IMAGE_REFERENCE = re.compile(r'\bImage\(\s*(?:decorative:\s*)?"([^"\\]+)"')


@check(12, "every Image(\"…\") name in app code resolves to one imageset whose files exist")
def check_image_references(ctx: Context, c: Check) -> None:
    names: dict[str, list[str]] = {}
    swift_files = sorted(APP_DIR.rglob("*.swift")) if APP_DIR.is_dir() else []
    for path in swift_files:
        code, _ = lex_swift(path.read_text(encoding="utf-8"))
        for match in IMAGE_REFERENCE.finditer(code):
            line = code.count("\n", 0, match.start()) + 1
            names.setdefault(match.group(1), []).append(f"{rel(path)}:{line}")
    if not names:
        c.note("no asset-catalog image references in app code")
        return
    for name, sites in sorted(names.items()):
        where = ", ".join(sites)
        sets = sorted(CATALOG.rglob(f"{name}.imageset")) if CATALOG.is_dir() else []
        if not c.require(len(sets) == 1,
                         f"{name!r} ({where}) matches {len(sets)} imageset(s) in {rel(CATALOG)}"):
            continue
        imageset = sets[0]
        namespaced = [folder for folder in imageset.relative_to(CATALOG).parents
                      if folder != Path(".") and _provides_namespace(CATALOG / folder)]
        c.require(not namespaced,
                  f"{name!r} is inside a namespace folder {[p.as_posix() for p in namespaced]}; "
                  "the code would need the namespaced name")
        contents = imageset / "Contents.json"
        try:
            images = json.loads(contents.read_text(encoding="utf-8")).get("images", [])
        except (OSError, ValueError) as error:
            c.fail(f"{rel(contents)}: {error}")
            continue
        files = [image.get("filename") for image in images if image.get("filename")]
        if c.require(bool(files), f"{rel(contents)} lists no image files"):
            for filename in files:
                c.require((imageset / filename).is_file(),
                          f"{rel(imageset)} references missing {filename}")
            c.note(f"{name}: {rel(imageset)} ({', '.join(files)}); used at {where}")


def _provides_namespace(folder: Path) -> bool:
    try:
        properties = json.loads((folder / "Contents.json").read_text(encoding="utf-8")).get("properties", {})
    except (OSError, ValueError):
        return False
    return properties.get("provides-namespace") is True


# ==========================================================================
# UI test isolation and runner settings
# ==========================================================================


@check(13, "UI test target compiles only UI tests and depends on the app")
def check_ui_tests(ctx: Context, c: Check) -> None:
    matches = [(oid, target) for oid, target in ctx.of_isa("PBXNativeTarget").items()
               if target.get("name") == UI_TEST_TARGET]
    if not c.require(len(matches) == 1, "one UI test target is required"):
        return
    _, target = matches[0]
    paths, _ = ctx.resolved_paths()
    sources = ctx.build_file_paths(ctx.phase_of(target, "PBXSourcesBuildPhase"), paths)
    on_disk = {rel(path) for path in (ROOT / UI_TEST_TARGET).rglob("*.swift") if path.is_file()}
    c.require(bool(on_disk), "UI test source is absent")
    c.require(len(sources) == len(set(sources)) and set(sources) == on_disk,
              f"UI test source membership differs: project={sources}, disk={sorted(on_disk)}")
    app_id, _ = ctx.app_target()
    dependencies = [ctx.objects.get(oid, {}).get("target") for oid in target.get("dependencies", [])]
    c.require(dependencies == [app_id], "UI runner must depend on exactly the app target")
    for name, settings in configurations(ctx, target).items():
        c.require(settings.get("TEST_TARGET_NAME") == APP_TARGET,
                  f"{name}: TEST_TARGET_NAME must name the demo app")
        c.require(settings.get("GENERATE_INFOPLIST_FILE") == "YES",
                  f"{name}: UI test Info.plist must be generated")
        c.require(settings.get("PRODUCT_BUNDLE_IDENTIFIER") == f"{EXPECTED_BUNDLE_ID}.uitests",
                  f"{name}: unexpected UI test bundle identifier")
        c.require(settings.get("DEVELOPMENT_TEAM") == EXPECTED_DEVELOPMENT_TEAM,
                  f"{name}: UI runner DEVELOPMENT_TEAM must match Goseng LLC")
        c.require(settings.get("CODE_SIGN_STYLE") == "Automatic",
                  f"{name}: UI runner CODE_SIGN_STYLE must be Automatic")
    c.note(f"{len(on_disk)} UI test source(s); real taps are separate from fixture captures")


# ==========================================================================
# Advisory plutil lint and entry point
# ==========================================================================


def advisory_plutil() -> None:
    tool = shutil.which("plutil")
    if tool is None:
        print("ADVISORY plutil not found; skipped")
        return
    for path in (PRIVACY, WORKSPACE_CHECKS, PBXPROJ):
        if not path.is_file():
            continue
        try:
            result = subprocess.run([tool, "-lint", str(path)], capture_output=True, text=True,
                                    timeout=30, check=False)
            output = (result.stdout + result.stderr).strip().replace("\n", " | ")
            print(f"ADVISORY plutil -lint {rel(path)}: exit {result.returncode}: {output}")
        except (OSError, subprocess.SubprocessError) as error:
            print(f"ADVISORY plutil -lint {rel(path)}: could not run ({error})")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate the Proximeet Xcode project (read-only).")
    parser.add_argument("--diff", action="store_true", help="print unified diffs for check 10")
    parser.add_argument("--no-plutil", action="store_true", help="skip the advisory plutil lint")
    parser.add_argument("--rendered", action="store_true",
                        help="run checks 1-9 against the generators' in-memory render() output "
                             "instead of files on disk (writes nothing; check 10 is skipped)")
    args = parser.parse_args(argv)
    ctx = Context(show_diff=args.diff)
    if args.rendered:
        project = load_module("proximeet_generate_project", ROOT / "scripts" / "generate_project.py")
        assets = load_module("proximeet_generate_app_assets", ROOT / "scripts" / "generate_app_assets.py")
        for relative, text in project.render(ROOT).items():
            OVERLAY[ROOT / relative] = text.encode("utf-8")
        for relative, data in assets.render().items():
            OVERLAY[ROOT / relative] = data
        print(f"IN-MEMORY RENDER: checking {len(OVERLAY)} generated file(s) that are NOT on disk; "
              "nothing is written")
    failed = 0
    for number, title, function in sorted(CHECKS, key=lambda item: item[0]):
        if args.rendered and number == 10:
            print(f"SKIP [{number:2d}] {title} (not meaningful with --rendered)")
            continue
        result = Check(number, title)
        try:
            function(ctx, result)
        except Exception as error:  # noqa: BLE001 - a crashed check is a failed check
            result.fail(f"check raised {type(error).__name__}: {error}")
            if os.environ.get("VALIDATE_TRACEBACK"):
                traceback.print_exc()
        status = "FAIL" if result.failures else "PASS"
        failed += bool(result.failures)
        print(f"{status} [{number:2d}] {title}")
        for message in result.failures:
            print(f"       - {message}")
        for message in result.notes:
            print(f"       . {message}")
    if not args.no_plutil:
        advisory_plutil()
    print(f"validate_project: {len(CHECKS)} checks, {failed} failed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
