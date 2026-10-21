# tdoa depot-matrix harness — design contract

How the road-integration behaviour of `Transport-Drones-On-Asphalt` is tested
end to end (retarget ticket tasks 7-9, round 2; the ticket's standing
requirement: automated, headless, not manual play-testing).

## What a case is

One depot rig per case row in `testmods/tdoa-harness/cases.lua`, all built in
parallel on ONE deterministic map (seed pinned by the runner
`testing/run-scenario.py`; 2-wide roads throughout — the superproject
convention of in-game absolute coordinates):

- Two 2-wide road segments on a y-strip, split by an unfilled **2×2 gap**
  (small gaps stay connected — drones route around via the second lane; 2×2
  across both lanes genuinely splits the components: verified against
  Transport_Drones 2.1.4's `script/road_network.lua` tile-node graph).
- West segment: fuel depot + request depot (same end); east segment: supply
  depot. Stocked by script: drones in `crafter_input` (recipe set FIRST —
  `set_recipe` re-slots the crafting inventory and clears drones inserted
  before it), petroleum-gas in the fuel depot (burned by the depots for
  energy), `small-lamp` cargo in the supply depot; request via its
  `request-<item>` recipe (a recipe exists for every non-hidden item).
- Timeline (relative to the build tick 100): the fuel depot's push-model
  drone fuels the request depot (**the harness self-check** — no fuel
  delivery = `harness-invalid`, not a case failure); at rel 600 the gap is
  filled with the case tile via raised `set_tiles` (Transport_Drones watches
  `script_raised_set_tiles`; `add_node` MERGES the two road networks — the
  same idiom as upstream's own `script/self_test.lua`
  `check_road_network_split`); then the request depot dispatches its drone
  across the gap; verdict at rel 5000; benchmark runs 5600 ticks.

## The assertion

**The supply loses cargo** (`supply_drain_tick`) — a real delivery drains
the supply depot across the gap. The request's own output inventory is
engine-managed (the request recipe's craft can leave engine-managed cargo in
it) and is recorded but NOT asserted. `blocked` cases: supply intact at
deadline + the tile NOT in the mod's road set.

Results: `script-output/tdoa-harness/results.json` per run; runner exit
0 pass / 1 fail / 2 harness-error.

## Adding a test tile

One row in `testmods/tdoa-harness/cases.lua`:

```lua
  {
    key = "my-tile",
    fill = { tile = "my-tile-prototype" },   -- or { prefix_tiles = "Arci-" }
    expect = "road",                          -- or "blocked"
    note = "why this tile matters",
  },
```

`{ prefix_tiles = "Arci-" }` expands to one rig per road-set tile matching
the prefix — generated directional variants need zero hand-maintenance (the
2026-10-21 matrix covered 68 Arci tiles this way). A tile whose prototype is
absent in the current env is `skipped`, not failed — the env spec selects
the combination.

## Env matrix (the combination dimension)

The env spec **is** the combination: `chase_deps` gives the mandatory-only
cell automatically (no stubs); optional partners enter via `stub`+pins.
Specs live in `envs/`:

| env spec | install | mods | covers |
|---|---|---|---|
| `solo.toml` | dlc | tdoa + Transport_Drones 2.1.4 | controls + negatives (the mandatory-only cell) |
| `retarget-smoke.toml` | dlc | + AsphaltRoadsPatched 1.5.0 | the Arci integration |
| `py-smoke.toml` | factorio_2_experimental | + pyindustry 3.1.6 (+ARP) | the py branch |

**py always targets the DLC-less install**: py mods refuse the Space Age DLC
(`pypostprocessing` hard-errors at data stage; the engine loads owned
data-dir DLC mods regardless of the disabled flags — see test-envs.md's
empirical correction). `factorio_2_experimental` (v2.1.21, base+core only)
satisfies pyindustry's `base >= 2.1.21`.

Run:

    python3 testing/run-scenario.py                 # all three
    python3 testing/run-scenario.py solo retarget-smoke
    python3 testing/run-scenario.py solo --ticks 5600

The runner is standalone (parses devctl.conf only, no devctl verbs/venv),
overlays the harness onto each provisioned env by symlinks, and leaves the
envs untouched. 2026-10-21 matrix result: **solo 5 pass/3 skipped,
retarget 71 pass/1 skipped, py 72 pass — zero fails**; every delivered case
proved by a real supply drain through the filled gap.

## Showcase (visual runs)

Headless runs can't render — `game.take_screenshot` does nothing there — so
the visual evidence comes from a windowed client:

    python3 testing/showcase.py                # solo env; add an env stem to change

It reuses the matrix runner's scratch build, adds the `tdoa-showcase`
wrapper testmod (its first-tick call to the harness's `tdoa_harness`
remote interface arms the driver's showcase milestones — mod globals do not
cross mod environments), then opens the pre-created deterministic save in a
windowed singleplayer client on DISPLAY=:0 (`--load-game`; the client runs
the matrix live on the desktop). The driver screenshots at fixed world
coordinates (32 px/tile × zoom; frames cover the matrix column, the anchor
rig strip, the fill and the homeward drone crossing/approaching);
PNGs land in `<scratch>/script-output/tdoa-harness/showcase/` and gwenview
opens on them. The wrapper testmod is dev-only, like the harness itself.