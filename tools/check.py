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
args = parser.parse_args()

if not args.place_only:
    sources = sorted((ROOT / "src").rglob("*.lua")) + sorted((ROOT / "tests").glob("*.lua"))
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
