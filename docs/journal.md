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
