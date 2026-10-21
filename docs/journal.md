# transport-drones-on-asphalt — journal (session work log)

Chronological log of agent work sessions. Companion docs: `README.md`,
`src/changelog.txt`, superproject `issues/transport-drones-*.md` +
`issues/live-dir-stray-transport-drones-0.1.6.md`.

## Session 2026-10-15 (b) — 2.1-retarget investigation (no port)

Follow-up to the port session, per the retarget ticket
(superproject `inbox/retarget-transport-drones-on-asphalt-to-2.1.md`,
Order 1). Question: is a fv 2.0 → 2.1 retarget trivial? Answer: **no — the
hard dep's content breaks on 2.1, and both fix paths are content changes**.

- Fork content probe (`.cache/retarget-probe/`, dlc 2.1.21; fork symlinked
  from `managed/Transport_Drones_Drdozer_Fork` with fv temporarily bumped to
  2.1, then reverted — probe only, fork left clean): **data-stage crash**
  `data/entities/transport_depot/transport_depot.lua:72: attempt to call
  global 'assembler3pipepictures' (a nil value)`.
- Root cause: 2.0 base shipped `assembler3pipepictures()` as a global
  function (`entity/assemblerpipes.lua:43`); 2.1 base moved it to a module
  table (`require("prototypes.entity.assembler-pictures").assembler3pipepictures`,
  consumed WITHOUT a call — `entities.lua:3279`). `pipecoverspictures()` is
  still a global. Fork has exactly 3 call sites, all in `transport_depot.lua`.
- Portal facts: upstream `Transport_Drones` was **officially ported to 2.1**
  (2.1.0, 2026-08-12; latest 2.1.4, 2026-09-27, actively maintained), and the
  `is_road_tile` extension API this mod depends on dates to upstream 1.0.5
  and persists in the 2.1 line (2.1.3 even tunes the fast-road recipe).
- Paths recorded in the ticket: (A) port the fork (3 known fixes + unknown
  further breaks; changes the fork's maintained-only-2.0 status) vs (B)
  switch this mod's dep to upstream `Transport_Drones >= 2.1.0` (dependency
  migration; needs authenticated portal download of 2.1.4 + pairing probe +
  integration-branch verification). Path B likely obsoletes the fork here.
  Decision needed from the human — no port executed.
- **Decision (later same day)**: retarget work PAUSED — Transport_Drones
  has multiple forks and integrating all of them is the real complexity;
  neither path chosen. Ticket parked in superproject `blocked/` (human-
  instruction resume only). Mod stays fv 2.0, unlinked.
- **Decision 2026-10-16 (superproject)**: UNPARKED — Path B chosen. Dep
  switches to Klonan's official `Transport_Drones >= 2.1.4` (fv 2.1; the
  original author resumed — his `2.1-update` branch is the official port).
  The drdozer fork is retired (GitHub repo archived, submodule removed;
  landscape: superproject `docs/transport-drones-fork-landscape.md`). Work
  resumed under superproject inbox ticket
  `retarget-transport-drones-on-asphalt-to-2.1.md` (fv bump, dep switch,
  `is_road_tile` verification on 2.1.4, retarget gate, 0.2.0 ship).

## Session 2026-10-15 — structural port to superproject standard

Starting point: 0.1.7 at `2141f2a`, `src/` deployable layout, fv "2.0",
hard dep `Transport_Drones_Drdozer_Fork >= 1.0.27` (managed clone), four
optional deps, one conflict (`!` Meglinge fork). Task file asked to
inventory `build/` + a nested `transport-drones-on-asphalt/` dir first.

### Inventory findings

- `src/` deployable: info.json + data-updates.lua (~98 lines, entire mod —
  no data.lua/control.lua/locale) + changelog.txt + thumbnail.png.
- `build/`: legacy `build.sh` (jq+zip packer) + `deploy.sh` (copies zip into
  the live mods dir — predates devctl, violates the live-dir invariant).
  Superseded by `devctl mods build` / `devctl mods link`; kept for
  provenance, documented in AGENTS invariants + `docs/BUILDING.md` (moved
  there from a space-named stray root file).
- **The nested `transport-drones-on-asphalt/` dir from the task note does
  not exist** — full `find` shows no such dir anywhere in the repo. Task
  note stale (possibly removed pre-loop). Nothing to document about its
  contents.
- `README BUILDING.md` — stray 5-line notes file with a literal space in its
  filename → moved to `docs/BUILDING.md`.
- Live dlc dir contains a stray **unzipped** `Transport-Drones-On-Asphalt_0.1.6/`
  folder next to the 0.1.7 zip (folder would shadow the newer zip) →
  superproject issue `issues/live-dir-stray-transport-drones-0.1.6.md`.
- Optional partner `AsphaltRoadsPatched_1.5.0.zip` (dlc install) is **already
  fv 2.1** — the integration surface is 2.1-ready; only the mod + fork
  pairing is not.

### Port (per superproject `docs/mod-porting-workflow.md`)

- **Structural change**: only `README BUILDING.md` → `docs/BUILDING.md`
  (commit `6c91218`). `src/` untouched (per workflow: do not churn), `build/`
  stays at root. The deployable is byte-identical by construction.
- **Verification gate** (fv-2.0 mod → rejection-comparison gate):
  - dlc 2.1.21, pre-move: exit 1 — `Failed to load mod
    "Transport-Drones-On-Asphalt"` naming **both** the mod and
    `Transport_Drones_Drdozer_Fork` as `Incompatible Factorio version
    (current: 2.1, required: 2.0)`. Rig: scratch mods dir with `src/`
    symlinked under the CamelCase name + fork zip symlink (hard portal deps
    need explicit symlinks — data-dir auto-enable covers base/SA only).
  - dlc post-move: rejection text **identical** (sorted-line diff clean).
  - vanilla 2.0.77: exit 1, `Missing required dependency
    Transport_Drones_Drdozer_Fork >= 1.0.27` — fv gate *passed* on 2.0
    (dep zip absent there; not chased per task file).
  - `devctl mods build transport-drones-on-asphalt` — **works on the src/
    layout**: `Transport-Drones-On-Asphalt_0.1.7.zip`, 1.4MB (thumbnail
    included), sha256 `ee504ff0…`, game content only.
  - No relink: not live-linked; stays unlinked until the 2.1 retarget.
- **Knowledge extraction**: AGENTS.md created (lean shape; CamelCase-name
  and `!`-conflict invariants; legacy build/ supersession); this journal
  seeded; two issues filed (`transport-drones-not-2.1.md` with retarget
  direction — fork's fv first; `live-dir-stray-transport-drones-0.1.6.md`).

### Scratch evidence

- `.cache/transport-drones-port/` — dlc scratch (config + mods dir: CamelCase
  symlink → src/, fork zip symlink) and vanilla scratch (config + CamelCase
  symlink only); logs `baseline-dlc-rejection.log`,
  `baseline-vanilla-rejection.log`. Recreate per superproject
  `docs/testing.md` §3 + data-lifecycle's hard-dep symlink note.

### End state

- Mod repo: docs commit `6c91218` + AGENTS/journal commit at HEAD.
- Superproject: pointer bump + 2 issue files; inbox task
  `port-transport-drones-on-asphalt.md` removed after push.
- Next: `inbox/port-civtorio.md` (Order 5, last; generation-based, no
  data.lua/control.lua; inventory-first; fv 2.1).

## 2026-10-21 — 2.1 retarget (Path B) shipped as 0.2.0 (round 1)

- **Structure**: already conforms — `src/` deployable root is a first-class
  devctl layout (mod AGENTS says do NOT churn to `mod/`); devctl builds it;
  docs/AGENTS/journal in place. Only addition: `envs/retarget-smoke.toml`
  (first env spec for this project).
- **info.json 0.2.0**: fv "2.0"→"2.1"; hard dep
  `Transport_Drones_Drdozer_Fork >= 1.0.27` → `Transport_Drones >= 2.1.4`
  (official; fork retired 2026-10-16, Path B); meglinge `!` conflict dropped
  (line retired); `base >= 1.1` → `>= 2.1.0` (matches the dep floor per
  ticket task 1); `? AsphaltRoadsPatched >= 1.4.7` → `>= 1.5.0` — the
  maintainer's instruction: "the fork of asphalt roads currently used in
  civtorio" — civtorio's info.json pins `AsphaltRoadsPatched >= 1.5.0`,
  i.e. the same fork family already targeted, raised to its fv-2.1 line
  (1.4.x is fv-2.0-only). pyindustry/SE/railloader floors left as-is: they
  are minimum-versions, satisfiable by their fv-2.1 series lines; verified
  2.1 surfaces so far are pyindustry 3.1.6 and ARP 1.5.0.
- **No code changes**: all branches are data-stage and presence-gated
  (AGENTS invariant 1); none referenced the fork by name.
- **Smoke (the only testing, per maintainer)**: env spec
  `envs/retarget-smoke.toml` (dlc, game 2.1.23; implicit root + pinned
  `Transport_Drones@2.1.4` cache zip + `AsphaltRoadsPatched@1.5.0` via
  stub-resolved real zip — optional deps only enter via stub,
  docs/test-envs.md v0). `devctl mods check … --env retarget-smoke` →
  **PASS**, rc=0, 0 game-log errors. Branch evidence in the env's
  `factorio-current.log`: "Adding AsphaltPaving compatibility." +
  24× "Enabling Arci-*" (is_road_tile) + 65× "Adjusting Arci-*"
  (walking-speed). Tech-gate insert ran (would be a nil-index error
  otherwise). pyindustry/SE/railloader branches inert (mods absent by spec
  design — round-2 scope).
- **Relink**: `devctl mods link transport-drones-on-asphalt dlc` → live
  (`…/factorio_2_dlc/mods/Transport-Drones-On-Asphalt` → src/). Status
  flagged `zip-shadowed`: superseded 0.1.7 deploy-era zip still in the live
  dir (never portal-published; portal has 0.1.6) — cleared by hand (dist/
  keeps the artifact), matching the 2026-10-20 stray-sweep precedent.
- **Deferred to round 2 (maintainer)**: retarget ticket tasks 7-10 —
  automated interop harness (2×2-block route cases), pyindustry scope,
  ARP tile matrix, water-ford cobblestone compat (task 10 also BLOCKED BY
  `inbox/feature-cobblestone-road-ford.md`; no other mods touched per
  maintainer). Dump-diff (--against) likewise deferred; diff baseline =
  the env's data-raw-dump once round 2 lands.
- **Portal upload**: NOT done — release publishing is the maintainer's
  explicit call (superproject ship-flow rule: never publish without
  approval). 0.2.0 zip built in dist/, ready.

## 2026-10-21 — canonical structure refactor: src/ → mod/

- **Maintainer-directed full refactor** to the canonical own-mod layout
  (matches water-ford / civtorio / oreguard): `git mv src mod`; legacy
  `build/build.sh` + `build/deploy.sh` REMOVED (pre-devctl packer; deploy.sh
  would violate live-dir invariant 3 — flagged in the round-1 report and
  folded into this refactor) + `docs/BUILDING.md` retired (was purely their
  doc). `.gitignore` drops `target/` (legacy output), keeps `dist/`.
- **AGENTS.md**: layout section now `mod/`-canonical ("do NOT reintroduce
  src/" replaces the old do-not-churn note); invariant 4 rewritten: legacy
  tooling removed, build ONLY via `devctl mods build`.
- **Verification** (fresh, not cache-carried): env spec touched (comment
  src/→mod/) → new content-addressed env `retarget-smoke-703902d2`; old env
  pruned as superseded. `devctl mods build --report` from mod/: strict ok,
  zip audit unchanged (2 changed files vs 0.1.7 — info.json/changelog only).
  Smoke re-run: PASS, rc=0, 0 errors, 24× Arci is_road_tile lines —
  identical evidence profile to round 1, now via the mod/ root.
- **Live relink**: devctl detected the broken src/ link post-move and
  repaired: `…/factorio_2_dlc/mods/Transport-Drones-On-Asphalt` → now
  `…/transport-drones-on-asphalt/mod`. Status clean.
- Layout now: `mod/` (deployable), `envs/`, `docs/`, `README.md`,
  `AGENTS.md`, `dist/` (gitignored). Notable absence vs siblings: no
  `portal/` yet — the 0.2.0 upload decision is still the maintainer's;
  add the portal page source when that round happens.

## 2026-10-21 — py optional dep hardened: 0.2.1, py-smoke env

- **Provider verified by zip inspection** (not carried from the earlier
  note): pyindustry 3.1.6 (fv 2.1) ships the `py-asphalt` item+tile pair
  (`prototypes/tiles/py-asphalt.lua`); name/fv confirmed from its info.json.
  The `? pyindustry` optional dep was therefore already pointed at the
  right mod — but its floor `>= 1.5.4` names a version that cannot load on
  fv 2.1 (same defect class as the old ARP floor) → **0.2.1 raises it to
  `>= 3.1.6`**, the verified surface (changelog Bugfixes entry, mirroring
  the 0.1.7 dependency-fix precedent).
- **py-vs-SpaceAge finding (load-level, environment)**: pyindustry's hard
  dep `pypostprocessing` hard-errors "The Space Age mod is not currently
  compatible with Pyanodons" at data stage, and the engine loads owned
  data-dir DLC mods regardless of the env's disabled flags (test-envs
  empirical correction) — so NO py-inclusive load can pass on the dlc
  install. First py-smoke attempt on dlc failed exactly there; not tdoa.
- **envs/py-smoke.toml (new)**: py-inclusive smoke on
  `factorio_2_experimental` (v2.1.21, DLC-less data dir — base+core only,
  satisfying pyindustry's `base >= 2.1.21`). 6 mods: tdoa + TD 2.1.4 +
  ARP 1.5.0 (both branches coexist) + pyindustry 3.1.6 + chased ~ deps
  pypostprocessing 3.1.6 / pyindustrygraphics 3.1.1 (2 zips portal-fetched,
  sha1-ok). **PASS**: "Adding pyindustry compatibility." + "Enabling
  py-asphalt as a road surface" in the env log, 0 errors; dump shows
  py-asphalt item `is_road_tile: true`, tile keeps pyindustry's own wsm 3.25
  (tdoa applies NO py walking boost — the asymmetry the ticket flagged for
  maintainer confirmation in round 2, task 8).
- **retarget-smoke.toml** reverted to the 3-mod dlc gate shape (py removed
  with an explanatory comment) — the standing retarget gate stays green on
  dlc: PASS re-run unchanged (24× Arci, 0 errors).
- **devctl fix (superproject lib/, selftested)**: envspec's dep parser only
  knew `~` as a suffix operator — Factorio's `~ name >= a.b.c` PREFIX form
  (pyindustry ships it) parsed the name with the tilde attached and the
  chase missed pypostprocessing. Fixed: prefix stripped, comparator kept,
  same-minor anchor carried separately (check_constraint applies both);
  bare `~ name` (no bound) is a loud parse error. New selftest block 7a-p;
  battery green; docs/test-envs.md contract text updated.
- Status quo: dist/ has 0.2.1 zip; live link tracks mod/ root (0.2.1);
  portal upload still the maintainer's call.

## 2026-10-21 — round 2: depot-matrix harness (tasks 7-9 green)

- **Design (maintainer-approved)**: the plan from the maintainer — one
  request+fuel depot pair west of a 2×2 gap in a 2-wide transport-drones
  road, supply depot east; the fuel-truck run is the harness self-check; the
  fill reconnects (or must fail to) and the requester's real delivery is the
  verdict; negatives (landfill/concrete/stone-path) plus an unfilled-gap
  control. Roads 2 tiles wide throughout (maintainer). Runner =
  standalone python (water-ford-testmod/run.py shape, exit 0/1/2); cases =
  a parameterised table (cases.lua).
- **Ground truth (upstream 2.1.4 source, zip-extracted)**: roads = tile-node
  connectivity graph (`script/road_network.lua`); drones collide with all
  NON-road tiles (their collision mask = all used tile layers minus
  `transport_drone_road`, `colliding_with_tiles_only`) so a 2×2 gap across
  both lanes = a hard split; `script_raised_set_tiles` hook does add_node /
  remove_node for script-driven fills (the same idiom upstream's own
  `script/self_test.lua` check_road_network_split uses); depots register via
  their corpse tile (offsets per kind/direction: fuel S+3, request N−2,
  supply S+2) and hold drones in `crafter_input`; request = `request-<item>`
  recipe (built for every non-hidden item); dispatch consumes depot fuel
  (burn) + a drone item; delivered goods land in the request's output
  inventory — but that inventory is engine-managed (recipe output/pulse) so
  **the verdict asserts the supply drain** (the only physical witness of
  pathing across the gap). Upstream's own self_test (calibration instance,
  patched copy + harness) delivered for real (50/item delivered by its own
  phases), proving the launch shape (headless --create + --benchmark) is
  sound — their silent failure in the first calibration attempt was MY
  stale-copy mistake (cp into an existing dir), fixed.
- **Lessons (engine/API)**: (1) arbitrary Lua globals are NOT persisted; only
  `storage` (upstream bridges its script_data the same way) — harness uses
  first-observed-wins scalars in storage + per-session world re-derivation.
  (2) `script.on_tick` does not exist — on_tick = an event
  (`defines.events.on_tick`). (3) file IO moved to `helpers`
  (`helpers.write_file` / `table_to_json`). (4) runtime prototypes don't
  expose data-stage fields (`place_as_tile`): cases are TILE-keyed; the
  item→tile mapping only exists in the mod's road-tile-list (read
  `road-tile-list:get_tile_filters(defines.selection_mode.select)`). (5)
  cross-mod `require` is not canonicalized per path: a require of another
  mod's script yields a SECOND, EMPTY module instance (its state lives in
  the original's closures; only `storage` and remote interfaces bridge) —
  introspection goes through the world + the mod's remotes, never a
  required module's locals. (6) `--map-settings` / `--map-gen-settings`
  deserialization demands the full required tree (a partial hand tree fails
  "Key X not found at ROOT[y.path]"): pin only `{"seed": N}` in the gen
  file; the save stores the complete settings and loads fine; the driver
  purges each rig's box (oreguard lab purge pattern) so default-map water /
  trees / enemies can't shape results. (7) `set_recipe` clears the crafting
  inventory: insert drones AFTER the recipe. (8) 2.0 renamed the stone-brick
  path tile → `stone-path`, the lamp item → `small-lamp`.
- **Results (2026-10-21 matrix)**: solo (dlc; TD only): 5 pass + 3 skipped;
  retarget-smoke (dlc; +ARP): 71 pass + 1 skipped (py absence, correct);
  py-smoke (experimental; +pyindustry 3.1.6 +ARP): **72/72 pass** —
  py-asphalt + the FULL 68-tile Arci matrix (every generated directional
  variant, enumerated via road-set prefix expansion; zero hand-maintenance)
  + negatives — every delivered case proven by a real supply drain through
  the filled gap; zero fails, zero harness-invalids. Exit 0 on all three.
- **Deliverables**: `testmods/tdoa-harness/` (info.json, cases.lua,
  control.lua), `testing/run-scenario.py`, `envs/solo.toml`,
  `docs/harness.md` (the design contract + add-a-case rows); AGENTS updated
  (layout + recipe). Task 10 (water-ford cobblestone-ford compat) remains
  maintainer-gated (BLOCKED BY the water-ford feature ticket). The
  py-branch asymmetry (no walking boost / no tech gate) stands recorded for
  the maintainer's call.
