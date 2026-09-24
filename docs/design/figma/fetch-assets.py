"""Fetch the exact Figma icon references and reject non-SVG responses.

Run beside asset-manifest.json on a machine with access to the supplied URLs.
Does not contact Apple, change app code, or deploy anything.
"""
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import urllib.request
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parent
manifest = json.loads((root / "asset-manifest.json").read_text())
(root / "assets").mkdir(exist_ok=True)

def fetch(item):
    item = dict(item)
    filename = item.get("target_filename") or Path(item["path"]).name
    target = root / "assets" / filename
    try:
        with urllib.request.urlopen(item["source"], timeout=20) as response:
            data = response.read()
        svg = ET.fromstring(data)
        if svg.tag.split("}")[-1] != "svg":
            raise ValueError("Response is not SVG")
        if not svg.get("viewBox") and not (svg.get("width") and svg.get("height")):
            raise ValueError("SVG has no root dimensions")
        target.write_bytes(data)
        item.update(status="available", path=str(target), bytes=len(data),
                    width=svg.get("width"), height=svg.get("height"), viewBox=svg.get("viewBox"))
        item.pop("error", None)
    except Exception as exc:
        item.update(status="unavailable", error=str(exc), target_filename=filename)
        item.pop("path", None)
    return item

with ThreadPoolExecutor(max_workers=4) as pool:
    results = list(pool.map(fetch, manifest))
(root / "asset-manifest.json").write_text(json.dumps(results, indent=2))
for item in results:
    print(item["screen"], item["name"], item["status"], item.get("error", ""))
raise SystemExit(0 if all(item["status"] == "available" for item in results) else 1)
