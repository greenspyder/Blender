"""Run from the project: python3 tools/validate_gameplay.py. Requires Godot on PATH."""
from pathlib import Path
import json
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
LOGS = ROOT / 'validation_cloth_hotfix'
LOGS.mkdir(exist_ok=True)

def run(args, env):
    proc = subprocess.run(['godot', '--headless', '--path', str(ROOT), *args],
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                          text=True, timeout=120, env=env)
    return proc.returncode == 0 and 'SCRIPT ERROR' not in proc.stdout and '\nERROR:' not in proc.stdout, proc.stdout

with tempfile.TemporaryDirectory(prefix='rose-validation-') as data_dir:
    env = dict(os.environ, XDG_DATA_HOME=data_dir)
    ok, log = run(['--editor', '--import', '--quit'], env)
    (LOGS / 'import.log').write_text(log)
    if not ok:
        raise SystemExit('Import failed; see import.log')
    syntax = []
    for path in sorted(ROOT.rglob('*.gd')):
        if '.godot' in path.parts:
            continue
        indents = [line[:len(line)-len(line.lstrip())] for line in path.read_text().splitlines() if line.strip()]
        mixed = any('\t' in i for i in indents) and any(' ' in i for i in indents)
        ok, log = run(['--check-only', '--script', str(path)], env)
        syntax.append({'file':str(path.relative_to(ROOT)), 'passed':ok and not mixed,
                       'mixed_indentation':mixed, 'log':log if not ok else ''})
    (LOGS / 'syntax.json').write_text(json.dumps(syntax, indent=2))
    results = []
    for path in sorted((ROOT / 'tests').glob('*.gd')):
        ok, log = run(['--fixed-fps', '60', '--script', str(path)], env)
        (LOGS / (path.stem + '.log')).write_text(log)
        results.append({'test':path.stem, 'passed':ok})
        print(path.stem, 'PASS' if ok else 'FAIL', flush=True)
    (LOGS / 'results.json').write_text(json.dumps(results, indent=2))
    raise SystemExit(0 if all(r['passed'] for r in results + syntax) else 1)
