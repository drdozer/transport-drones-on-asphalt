#!/usr/bin/env python3
"""tdoa depot-matrix SHOWCASE runner (visual; see docs/harness.md).

The headless matrix runner (run-scenario.py) cannot render: `game.
take_screenshot` does NOTHING when Factorio runs headless. To produce the
showcase screenshots the driver's showcase milestones render here instead:

1. builds the scratch instance for ONE env (default solo) exactly as the
   matrix runner does (build_scratch; symlinks only, env untouched),
2. adds the `tdoa-showcase` wrapper testmod (its first-tick remote call arms
   the driver's screenshot milestones — mod globals do not cross mod envs),
3. silences the brief windowed session via config (full-screen=false,
   master-volume=0 — real key names verified in a live config.ini),
4. pre-creates the deterministic map HEADLESSLY (same create path as the
   runner — ticks don't run at create, so milestones don't fire there),
5. re-opens the created save in a real WINDOWED singleplayer client on
   DISPLAY=:0 (`--load-game` goes straight into the game); the game window
   runs the whole depot matrix live and take_screenshot writes PNGs into
   script-output/tdoa-harness/showcase/,
6. tails factorio-current.log for HARNESS progress, nudges the window into
   focus on log silence (singleplayer can pause silently on focus loss —
   observed 2026-10-21: one run froze ~tick 730 and resumed on refocus; the
   same save then ran to verdict unattended), waits for the results file
   (+ grace for the last render), then terminates the client.

The singleplayer client ignores --rcon-port (connection refused, verified —
rcon is server-scoped), so no external drive channel exists here.

Exit codes as the matrix runner: 0 all cases pass, 1 fail, 2 harness-error.

    python3 testing/showcase.py            # solo env, windowed showcase
    python3 testing/showcase.py retarget-smoke
"""
import importlib.util
import json
import os
import subprocess
import sys
import time

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("run_scenario",
    os.path.join(_HERE, "run-scenario.py"))
rs = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(rs)

SHOWCASE_NAME = "tdoa-showcase"
SHOTS_REL = os.path.join("script-output", rs.HARNESS_NAME, "showcase")
WINDOW_BUDGET_S = 600     # ~85 s of sim at 60 UPS; budget covers pauses


def nudge_focus():
    env = {**os.environ, "DISPLAY": ":0"}
    subprocess.run(["xdotool", "search", "--class", "factorio", "windowactivate"],
                   env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                   timeout=20)


def main():
    root = rs.find_root()
    stems = sys.argv[1:] or ["solo"]
    env_dirs = rs.resolve_env_dirs(root, stems)

    overall = "pass"
    for stem in stems:
        env_dir, manifest = env_dirs[stem]
        print(f"\n=== showcase: {stem} ({env_dir}) ===", flush=True)
        scratch = rs.build_scratch(root, env_dir, manifest)
        wrapper_src = os.path.join(root, "mods", "transport-drones-on-asphalt",
                                   "testmods", SHOWCASE_NAME)
        if not os.path.isdir(wrapper_src):
            sys.exit(f"showcase: wrapper testmod missing: {wrapper_src}")
        os.symlink(wrapper_src, os.path.join(scratch, "mods", SHOWCASE_NAME))
        with open(os.path.join(scratch, "mod-list.json")) as f:
            mod_list = json.load(f)
        mod_list["mods"].append({"name": SHOWCASE_NAME, "enabled": True})
        with open(os.path.join(scratch, "mod-list.json"), "w") as f:
            json.dump(mod_list, f, indent=2)
        # windowed session polish: no fullscreen takeover, muted
        with open(os.path.join(scratch, "config", "config.ini"), "w") as f:
            f.write("[path]\nread-data=__PATH__executable__/../../data\n"
                    f"write-data={scratch}\n\n[graphics]\nfull-screen=false\n"
                    "\n[sound]\nmaster-volume=0\n")

        rc, log_path = rs.run_cmd(root, scratch, env_dir, {
            "stem": stem, "manifest": manifest, "log": "create.log",
            "cmd": ["--map-gen-settings", os.path.join(scratch, "map-gen.json"),
                    "--create", os.path.join(scratch, "scenario.zip")],
        }, rs.CREATE_BUDGET_S)
        print(f"create rc={rc}", flush=True)
        if rc != 0:
            rs._tail(log_path)
            overall = "harness-error"
            continue

        install_path = rs.conf_value(root,
            "FACTORIO_" + str(manifest.get("install", "")).upper() + "_PATH")
        factorio = os.path.join(install_path, "bin", "x64", "factorio")
        env = dict(os.environ)
        env["DISPLAY"] = ":0"
        cmd = [factorio, "-c", os.path.join(scratch, "config", "config.ini"),
               "--mod-directory", os.path.join(scratch, "mods"),
               "--load-game", os.path.join(scratch, "scenario.zip")]
        with open(os.path.join(scratch, "window.log"), "w") as logf:
            proc = subprocess.Popen(cmd, stdout=logf, stderr=subprocess.STDOUT,
                                    env=env, start_new_session=True)
        results_path = os.path.join(scratch, rs.RESULTS_REL)
        cur_log = os.path.join(scratch, "factorio-current.log")
        print(f"windowed client pid {proc.pid}", flush=True)

        results = None
        probe_deadline = time.time() + WINDOW_BUDGET_S
        log_pos = 0
        last_progress = time.time()
        nudged = False
        while time.time() < probe_deadline:
            time.sleep(3)
            if os.path.isfile(cur_log):
                with open(cur_log, errors="replace") as f:
                    f.seek(log_pos)
                    fresh = f.read()
                    log_pos = f.tell()
                if fresh:
                    last_progress = time.time()
                for line in fresh.splitlines():
                    if "HARNESS" in line:
                        i = line.find("HARNESS")
                        print("   " + line[i:i + 150], flush=True)
            if (time.time() - last_progress > 45 and proc.poll() is None
                    and not nudged):
                print("   no log progress for ~45 s — nudging window focus", flush=True)
                nudge_focus()
                nudged = True
                last_progress = time.time()
            if os.path.exists(results_path):
                results = json.load(open(results_path))
                break
            if proc.poll() is not None:
                print("--- client exited early; window.log tail:", flush=True)
                rs._tail(os.path.join(scratch, "window.log"))
                overall = "harness-error"
                break

        time.sleep(8)                     # render flush for the last shot
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=20)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=10)

        if results is None:
            if os.path.exists(results_path):
                results = json.load(open(results_path))
            else:
                overall = "harness-error"
                continue

        shots = results.get("showcase_shots", [])
        shot_files = []
        for p in shots:
            if p.startswith("FAILED"):
                print(f"  shot {p}", flush=True)
                overall = "harness-error"
                continue
            full = os.path.join(scratch, "script-output", p)
            ok_file = os.path.isfile(full)
            if ok_file:
                shot_files.append(full)
            print(f"  shot {('OK ' if ok_file else 'MISSING ')}{p}", flush=True)
        for case in results.get("cases", []):
            print(f"  {case['key']:42} expect={case['expect']:7} "
                  f"verdict={case['verdict']:16} {case['reason']}", flush=True)
        if results.get("overall") != "pass":
            overall = "fail"
        if results.get("overall") == "pass" and shot_files and stem == stems[0]:
            print(f"\nshowcase PNGs ({len(shot_files)}): opening in gwenview ...", flush=True)
            for f in shot_files:
                print(f"    {f}", flush=True)
            subprocess.Popen(["gwenview", *shot_files],
                             env=env,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                             start_new_session=True)

    print(f"\nverdict: {overall}", flush=True)
    sys.exit(0 if overall == "pass" else 1 if overall == "fail" else 2)


if __name__ == "__main__":
    main()