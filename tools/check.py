#!/usr/bin/env python3
"""Compile all Luau sources, exercise the rules and inspect the generated place."""
import argparse
import pathlib
import subprocess
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--luau", default="luau")
parser.add_argument("--compiler", default="luau-compile")
parser.add_argument("--place-only", action="store_true")
parser.add_argument("--lab", action="store_true")
args = parser.parse_args()

if not args.place_only:
    sources = (sorted((ROOT / "src").rglob("*.lua")) + sorted((ROOT / "tests").glob("*.lua"))
               + sorted((ROOT / "lab").rglob("*.lua")) + sorted((ROOT / "tools").glob("*.luau")))
    for source in sources:
        subprocess.run([args.compiler, "--null", str(source)], check=True, stdout=subprocess.DEVNULL)
    print(f"Compiled {len(sources)} Luau files.", flush=True)
    subprocess.run([args.luau, "tests/run.lua"], cwd=ROOT, check=True)
    harness = ROOT / "tests" / "__server_generated.luau"
    template = (ROOT / "tests" / "server.spec.lua").read_text()
    server_source = (ROOT / "src" / "server" / "Main.server.lua").read_text()
    harness.write_text(template.replace("-- @SERVER_SOURCE@", server_source))
    try:
        subprocess.run([args.luau, str(harness)], cwd=ROOT, check=True)
    finally:
        harness.unlink(missing_ok=True)

place = ROOT / "Wizard.rbxlx"
tree = ET.parse(place)
expected = {
    "Rules": "ModuleScript", "Engine": "ModuleScript", "World": "ModuleScript",
    "Main": None,
}
scripts = []
for item in tree.iter("Item"):
    if item.get("class") in ("Script", "LocalScript", "ModuleScript"):
        name = item.find("./Properties/string[@name='Name']")
        source = item.find("./Properties/*[@name='Source']")
        assert name is not None and source is not None and source.text
        scripts.append((item.get("class"), name.text, source.text))
assert len(scripts) == 5, f"Expected five scripts in place, got {len(scripts)}"
assert sum(cls == "LocalScript" for cls, _, _ in scripts) == 1
assert sum(cls == "Script" for cls, _, _ in scripts) == 1
for cls, name, source in scripts:
    assert name in expected, f"Unexpected script: {name}"
    if expected[name]:
        assert cls == expected[name]
    suffix = ".client.lua" if cls == "LocalScript" else ".server.lua" if cls == "Script" else ".lua"
    candidates = list((ROOT / "src").rglob(name + suffix))
    assert len(candidates) == 1
    assert source == candidates[0].read_text(), f"Place is stale: {candidates[0]}"
print("Place verified: five scripts, correct script types, exact current sources.")

if args.lab:
    lab = ET.parse(ROOT / "AssetLab.rbxlx")
    mapping = {
        ("Script", "Main"): "lab/server/Main.server.lua",
        ("LocalScript", "Main"): "lab/client/Main.client.lua",
        **{("ModuleScript", name): f"src/assets/{name}.lua"
           for name in ("ArtDirection", "CardModel", "Tavern", "TableLayout")},
    }
    found = set()
    cards = 0
    for item in lab.iter("Item"):
        name = item.find("./Properties/string[@name='Name']")
        if name is None:
            continue
        if item.get("class") == "SurfaceGui":
            cards += 1
        if item.get("class") not in ("Script", "LocalScript", "ModuleScript"):
            continue
        key = (item.get("class"), name.text)
        assert key in mapping and key not in found, f"Unexpected lab script: {key}"
        found.add(key)
        source = item.find("./Properties/*[@name='Source']")
        assert source is not None and source.text == (ROOT / mapping[key]).read_text(), f"Stale lab: {key}"
    assert found == set(mapping) and cards == 12
    assert lab.find(".//Item[@class='Model']/Properties/string[@name='Name'][.='TavernStudy']") is not None
    print("Lab place verified: six current scripts, editable tavern, six baked samples and twelve card surfaces.")
