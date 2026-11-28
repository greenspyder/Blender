"""Inventário das dependências, GLBs, inicialização das cenas e ferramentas Blender."""
import ast
from collections import Counter
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "validation_foundation"
OUTPUT.mkdir(exist_ok=True)
paths = sorted(p for p in ROOT.rglob("*") if p.is_file() and ".godot" not in p.parts)
paths = [p for p in paths if not p.relative_to(ROOT).parts[0].startswith("validation")]
resources = {}
broken = []
python_files = []
for path in paths:
    name = path.relative_to(ROOT).as_posix()
    if path.suffix == ".py":
        ast.parse(path.read_text(), filename=name)
        python_files.append(name)
    if path.suffix not in {".gd", ".tscn", ".tres", ".gdshader"} and path.name != "project.godot":
        continue
    deps = sorted(set(re.findall(r'''["']res://([^"'\n]+?\.(?:gd|tres|tscn|glb|gdshader|png))["']''', path.read_text())))
    resources[name] = deps
    broken.extend([name, dep] for dep in deps if not (ROOT / dep).is_file())

models = {}
for asset in sorted((ROOT / "assets").glob("*.glb")):
    with asset.open("rb") as f:
        magic, version, size, chunk_size, chunk_type = struct.unpack("<4s4I", f.read(20))
        assert magic == b"glTF" and version == 2 and chunk_type == 0x4E4F534A and size == asset.stat().st_size
        doc = json.loads(f.read(chunk_size))
    models[asset.name] = {"meshes":len(doc.get("meshes", [])), "materials":len(doc.get("materials", [])),
                          "skins":[len(s["joints"]) for s in doc.get("skins", [])], "animations":len(doc.get("animations", [])),
                          "nodes":[n.get("name") for n in doc.get("nodes", []) if "mesh" in n]}

scenes = []
with tempfile.TemporaryDirectory(prefix="rose-scene-audit-") as data_dir:
    for path in paths:
        if path.suffix != ".tscn":
            continue
        name = path.relative_to(ROOT).as_posix()
        proc = subprocess.run(["godot", "--headless", "--fixed-fps", "60", "--path", str(ROOT),
                               "--quit-after", "4", "res://" + name], capture_output=True, text=True,
                              env=dict(os.environ, XDG_DATA_HOME=data_dir), timeout=60)
        log = (proc.stdout + proc.stderr).strip()
        ok = proc.returncode == 0 and "SCRIPT ERROR" not in log and "ERROR:" not in log
        scenes.append({"scene":name, "passed":ok, "output":log})
report = {"types":Counter(p.suffix for p in paths if p.suffix in {".gd",".tscn",".tres",".glb",".py"}),
          "dependencies":resources, "broken":broken, "blender_and_python_scripts":python_files, "models":models, "scene_boot":scenes}
(OUTPUT / "inventory.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
print(report["types"], "referências ausentes", broken, "cenas com erro", [s["scene"] for s in scenes if not s["passed"]])
raise SystemExit(1 if broken or any(not s["passed"] for s in scenes) else 0)
