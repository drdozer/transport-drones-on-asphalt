#!/usr/bin/env python3
"""tdoa depot-matrix scenario runner (see docs/harness.md).

For each provisioned env spec (solo / retarget-smoke / py-smoke), overlays the
tdoa-harness testmod into a hermetic scratch instance (symlinks only; the env
itself is never mutated), creates a deterministic empty map, benchmark-runs the
depot-matrix driver, reads script-output/tdoa-harness/results.json, and maps
the verdicts onto the exit code:

    0  pass   — every run case passed (skipped cases are env-dependent by design)
    1  fail   — a case failed against its expected behaviour
    2  harness-error — results missing / incomplete / instance died

Standalone by design: parses devctl.conf only; no devctl verbs, no venv —
safe to run while other agents hold lib/ in flight. Env dirs are provisioned
out of band (`devctl mods env create <spec>`).

    python3 testing/run-scenario.py                     # all three envs
    python3 testing/run-scenario.py solo                # one env
    python3 testing/run-scenario.py solo retarget-smoke --ticks 5400
"""
import json
import os
import shutil
import subprocess
import sys
import time

HARNESS_NAME = "tdoa-harness"
RESULTS_REL = os.path.join("script-output", HARNESS_NAME, "results.json")
CREATE_BUDGET_S = 240      # --create: init + all rig builds
BENCH_TICKS = 5600         # driver: build at 100, deadline rel 5000, + margin
BENCH_BUDGET_S = 900

SEED = 21012021            # fixed; map determinism via the captured gen tree
# (the runner patches the seed into the decoded, engine-own MapGenSettings —
# minimal hand trees deserialize fine but the terrain under the rigs is
# cleaned by the driver's purge anyway)
MAP_GEN = {"seed": SEED}


def find_root():
    d = os.path.dirname(os.path.abspath(__file__))
    while d != os.path.dirname(d):
        if os.path.exists(os.path.join(d, "devctl.conf")):
            return d
        d = os.path.dirname(d)
    sys.exit("run-scenario: could not locate the superproject root (no devctl.conf above)")


def conf_value(root, key):
    with open(os.path.join(root, "devctl.conf")) as f:
        for line in f:
            line = line.strip()
            if line.startswith(key + "="):
                return line.split("=", 1)[1].strip().strip('"')
    sys.exit(f"run-scenario: {key} not found in devctl.conf")


def resolve_env_dirs(root, stems):
    """<stem> -> env dir under .cache/envs/<install>/<stem>-<hash8>; unique match required."""
    out = {}
    for stem in stems:
        matches = []
        envs_root = os.path.join(root, ".cache", "envs")
        if not os.path.isdir(envs_root):
            sys.exit(f"run-scenario: no envs provisioned under {envs_root}")
        for install in sorted(os.listdir(envs_root)):
            idir = os.path.join(envs_root, install)
            if not os.path.isdir(idir):
                continue
            for dirname in sorted(os.listdir(idir)):
                if (dirname == stem or dirname.startswith(stem + "-")) and os.path.isfile(f"{idir}/{dirname}/manifest.json"):
                    with open(f"{idir}/{dirname}/manifest.json") as f:
                        manifest = json.load(f)
                    if manifest.get("spec_name") == stem:
                        matches.append((idir, dirname, manifest))
        if not matches:
            sys.exit(f"run-scenario: env '{stem}' not provisioned — "
                     f"create it with: devctl mods env create <spec-path>")
        if len(matches) > 1:
            listing = "\n  ".join(f"{d}" for _, d, _ in matches)
            sys.exit(f"run-scenario: env '{stem}' is ambiguous ({len(matches)} provisioned):\n  {listing}")
        idir, dirname, manifest = matches[0]
        out[stem] = (os.path.join(idir, dirname), manifest)
    return out


def build_scratch(root, env_dir, manifest):
    """Hermetic scratch overlay: env mods (symlinked through) + the harness."""
    scratch = os.path.join(root, ".cache", "tdoa-harness", os.path.basename(env_dir))
    if os.path.isdir(scratch):
        shutil.rmtree(scratch)
    os.makedirs(os.path.join(scratch, "config"))
    mods_dir = os.path.join(scratch, "mods")
    os.makedirs(mods_dir)

    for entry in sorted(os.listdir(os.path.join(env_dir, "mods"))):
        os.symlink(os.path.join(env_dir, "mods", entry), os.path.join(mods_dir, entry))
    harness_src = os.path.join(root, "mods", "transport-drones-on-asphalt", "testmods", HARNESS_NAME)
    if not os.path.isdir(harness_src):
        sys.exit(f"run-scenario: harness testmod missing: {harness_src}")
    os.symlink(harness_src, os.path.join(mods_dir, HARNESS_NAME))

    # env mod-lists are usually at the env root; older provisionings kept it
    # in config/ or lost it — synthesize from the manifest as the fallback.
    mod_list = None
    for cand in (os.path.join(env_dir, "mod-list.json"),
                 os.path.join(env_dir, "config", "mod-list.json")):
        if os.path.isfile(cand):
            with open(cand) as f:
                mod_list = json.load(f)
            break
    names = {m["name"] for m in mod_list["mods"]} if mod_list else set()
    mods_from_manifest = manifest.get("mods", {})
    if not mod_list or not ({"Transport-Drones-On-Asphalt", "Transport_Drones"} <= names):
        mod_list = {"mods": [{"name": "base", "enabled": True}]
                    + [{"name": n, "enabled": True} for n in sorted(mods_from_manifest)]
                    + [{"name": n, "enabled": bool(en)}
                       for n, en in sorted(manifest.get("data_dir_mods", {}).items())]}
    names = {m["name"] for m in mod_list["mods"]}
    for dep in ("Transport-Drones-On-Asphalt", "Transport_Drones"):
        if dep not in names:
            sys.exit(f"run-scenario: env {os.path.basename(env_dir)} lacks {dep} — not a tdoa env")
    mod_list["mods"].append({"name": HARNESS_NAME, "enabled": True})
    with open(os.path.join(scratch, "mod-list.json"), "w") as f:
        json.dump(mod_list, f, indent=2)

    with open(os.path.join(scratch, "config", "config.ini"), "w") as f:
        f.write("[path]\nread-data=__PATH__executable__/../../data\n"
                f"write-data={scratch}\n")
    with open(os.path.join(scratch, "map-gen.json"), "w") as f:
        json.dump(MAP_GEN, f)
    return scratch


def run_cmd(root, scratch, env_dir, args, budget):
    install = None
    stem = args.get("stem")
    # binary from the env's install (devctl.conf naming)
    manifest = args["manifest"]
    install = manifest.get("install", "")
    key = ("FACTORIO_" + install.upper() + "_PATH")
    install_path = conf_value(root, key)
    factorio = os.path.join(install_path, "bin", "x64", "factorio")
    if not os.path.exists(factorio):
        sys.exit(f"run-scenario: factorio binary not found at {factorio}")

    cmd = [factorio, "-c", os.path.join(scratch, "config", "config.ini"),
           "--mod-directory", os.path.join(scratch, "mods")] + args["cmd"]
    env = dict(os.environ)
    log_path = os.path.join(scratch, args["log"])
    with open(log_path, "w") as logf:
        proc = subprocess.Popen(cmd, stdout=logf, stderr=subprocess.STDOUT)
        proc.wait(timeout=budget)
    if proc.returncode != 0:
        return proc.returncode, log_path
    return 0, log_path


def run_env(root, stem, env_dir, manifest, ticks):
    scratch = build_scratch(root, env_dir, manifest)
    results_path = os.path.join(scratch, RESULTS_REL)

    rc, log_path = run_cmd(root, scratch, env_dir, {
        "stem": stem, "manifest": manifest, "log": "create.log",
        "cmd": ["--map-gen-settings", os.path.join(scratch, "map-gen.json"),
                "--create", os.path.join(scratch, "scenario.zip")],
    }, CREATE_BUDGET_S)
    print(f"[{stem}] create rc={rc}", flush=True)
    if rc != 0:
        print(f"[{stem}] --- create log tail ---", flush=True)
        _tail(log_path)
        return None

    rc, log_path = run_cmd(root, scratch, env_dir, {
        "stem": stem, "manifest": manifest, "log": "benchmark.log",
        "cmd": ["--benchmark", os.path.join(scratch, "scenario.zip"),
                "--benchmark-ticks", str(ticks)],
    }, BENCH_BUDGET_S)
    print(f"[{stem}] benchmark rc={rc}", flush=True)
    if rc != 0:
        print(f"[{stem}] --- benchmark log tail ---", flush=True)
        _tail(log_path)
        return None

    # benchmark writes the results during the run; small poll for the file
    deadline = time.time() + 30
    while time.time() < deadline:
        if os.path.exists(results_path):
            break
        time.sleep(1)
    if not os.path.exists(results_path):
        print(f"[{stem}] --- no results file; benchmark log tail ---", flush=True)
        _tail(log_path)
        return None
    with open(results_path) as f:
        return json.load(f)


def _tail(path, n=25):
    try:
        with open(path) as f:
            lines = f.readlines()
        print("".join(lines[-n:]), flush=True)
    except OSError:
        print("(no log)", flush=True)


def main():
    root = find_root()
    argv = sys.argv[1:]
    ticks = BENCH_TICKS
    if "--ticks" in argv:
        i = argv.index("--ticks")
        ticks = int(argv[i + 1])
        del argv[i:i + 2]
    stems = argv or ["solo", "retarget-smoke", "py-smoke", "ford-smoke"]
    env_dirs = resolve_env_dirs(root, stems)

    overall = "pass"
    for stem in stems:
        env_dir, manifest = env_dirs[stem]
        print(f"\n=== {stem} ({os.path.basename(env_dir)}, install {manifest.get('install')}) ===", flush=True)
        results = run_env(root, stem, env_dir, manifest, ticks)
        if results is None:
            overall = "harness-error"
            continue
        for case in results.get("cases", []):
            print(f"  {case['key']:42} expect={case['expect']:7} verdict={case['verdict']:16} {case['reason']}", flush=True)
        if results.get("overall") != "pass":
            overall = "fail" if overall != "harness-error" else overall
            if any(c["verdict"] == "harness-invalid" for c in results.get("cases", [])):
                overall = "harness-error"

    print(f"\nverdict: {overall}", flush=True)
    if overall == "pass":
        sys.exit(0)
    sys.exit(1 if overall == "fail" else 2)


if __name__ == "__main__":
    main()