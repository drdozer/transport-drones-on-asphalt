# transport-drones-on-asphalt — agent notes

**Transport Drones on Asphalt**: lets Transport Drone trucks drive on road
tiles from other mods (Asphalt Roads, Space Exploration, PyIndustry; gates
transport-system tech behind asphalt tech; boosts asphalt walking speeds;
Bulk Rail Loader crossing support). Author drdozer. v0.2.0, fv "2.1" —
retargeted 2026-10-21 to the official portal Transport_Drones 2.1 line
(Path B; fork retired — see superproject
`inbox/retarget-transport-drones-on-asphalt-to-2.1.md`). Live-linked on the
2.1 dlc install.

All-mods procedures: superproject `AGENTS.md` + `docs/`. This file holds only
mod-specifics. Session history: `docs/journal.md`.

## Layout

**`src/` deployable — leave as-is** (devctl builds it; do NOT churn to
`mod/`). `src/` = info.json, data-updates.lua (~98 lines, the whole mod),
changelog.txt, thumbnail.png. **No data.lua, no control.lua, no locale/**
(runtime log strings are plain English — acceptable for logs).
Root: `build/` (legacy scripts, provenance only), `envs/retarget-smoke.toml`
(hermetic retarget-gate smoke), `README.md`, `docs/BUILDING.md`.
Live-linked in the dlc install as `Transport-Drones-On-Asphalt` (0.2.0).

## Invariants

1. **Single data-updates stage**: all logic is mod-presence-keyed
   (`mods["AsphaltPaving"] or mods["AsphaltRoadsPatched"]`, SE/pyindustry/
   railloader branches) — no runtime component, so a load smoke IS a
   meaningful gate (nothing happens after data stage). Keep new integrations
   in this file, presence-gated the same way.
2. **Name mismatch is load-bearing**: info.json `name` is
   `Transport-Drones-On-Asphalt` (CamelCase) while the repo folder is
   `transport-drones-on-asphalt`. devctl handles it (derives everything from
   info.json), but **scratch-rig symlinks and manual zips must use the
   CamelCase name** or the game won't see the mod. Zips are
   `Transport-Drones-On-Asphalt_<version>.zip`.
3. **Hard dep is the official portal line**: `Transport_Drones >= 2.1.4`
(fv-2.1 head, Klonan; zip from `devctl mods fetch` — anonymous portal fetch
is Cloudflare-blocked). The drdozer fork is RETIRED (repo archived
2026-10-16, submodule removed; meglinge line dead on 2.1) — do not
reintroduce fork deps; the Meglinge-fork conflict line is likewise gone.
4. **build/ scripts are legacy, superseded by devctl**: `build/build.sh`
   (jq+zip packer, predates devctl) and `build/deploy.sh` (copies the zip
   into the live mods dir — against the current invariant; don't use it).
   Kept for provenance; `devctl mods build` + `devctl mods link` replace
   both. `docs/BUILDING.md` documents their deps (bash, jq, zip).

## Dependencies

`base >= 2.1.0`, `Transport_Drones >= 2.1.4` (hard),
`? AsphaltRoadsPatched >= 1.5.0` (the fv-2.1 line — same floor as civtorio;
1.4.x is fv-2.0-only), `? pyindustry >= 1.5.4`, `? space-exploration >= 0.6.82`,
`? railloader >= 1.1.6` (the last three floors are pre-2.1 but satisfiable
by their fv-2.1 lines; verified surfaces: pyindustry 3.1.6, AsphaltRoadsPatched
1.5.0 — see `docs/journal.md`). No py code branches beyond pyindustry asphalt
tiles.

## Verification quick recipe

- Hermetic smoke: `devctl mods check transport-drones-on-asphalt --env
  retarget-smoke` — env spec `envs/retarget-smoke.toml` (tdoa + official
  Transport_Drones 2.1.4 + AsphaltRoadsPatched 1.5.0 via stub; exact set is
  the spec's contract). Branch-fire evidence is in the env's
  `factorio-current.log` ("Adding AsphaltPaving compatibility.",
  "Enabling Arci-...") — the data-stage-only invariant makes the load smoke
  a meaningful gate.
- Hand-rigged scratch probes (`.cache/transport-drones-port/` pattern)
  are superseded by the env spec; keep rigs out.
- `devctl mods build transport-drones-on-asphalt` works on the src/ layout
  (zip ~1.4MB incl. thumbnail; game content only).

## Round-2 scope (pending, maintainer-gated)

Retarget ticket tasks 7-10, deferred by maintainer 2026-10-21: automated
interop test harness (2x2-block route-availability cases, carrier-testmod
pattern), pyindustry scope, AsphaltRoadsPatched tile matrix, water-ford
cobblestone-ford compat (blocked by the water-ford feature ticket until the
maintainer requests it). Do not pull any of this into ordinary work.

## Docs index

- `README.md` — human-facing feature list
- `docs/BUILDING.md` — legacy build-script deps (bash/jq/zip)
- `src/changelog.txt` — release history (0.1.0 → 0.1.7)
- `docs/journal.md` — session work log
- Superproject `inbox/retarget-transport-drones-on-asphalt-to-2.1.md` —
  the open work ticket (round-2 scope lives there),
  `issues/transport-drones-not-2.1.md`,
  `issues/live-dir-stray-transport-drones-0.1.6.md` — resolved, historical
  record
