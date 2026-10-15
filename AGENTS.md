# transport-drones-on-asphalt — agent notes

**Transport Drones on Asphalt**: lets Transport Drone trucks drive on road
tiles from other mods (Asphalt Roads, Space Exploration, PyIndustry; gates
transport-system tech behind asphalt tech; boosts asphalt walking speeds;
Bulk Rail Loader crossing support). Author drdozer — maintained-fork
companion of `Transport_Drones_Drdozer_Fork`. v0.1.7.
**Declared fv "2.0" — does NOT load on the 2.1 dlc install** (mod + hard dep
both fv 2.0; see superproject `issues/transport-drones-not-2.1.md`; the
optional partner `AsphaltRoadsPatched` is already fv 2.1).

All-mods procedures: superproject `AGENTS.md` + `docs/`. This file holds only
mod-specifics. Session history: `docs/journal.md`.

## Layout

**`src/` deployable — leave as-is** (devctl builds it; do NOT churn to
`mod/`). `src/` = info.json, data-updates.lua (~98 lines, the whole mod),
changelog.txt, thumbnail.png. **No data.lua, no control.lua, no locale/**
(runtime log strings are plain English — acceptable for logs).
Root: `build/` (legacy scripts), `README.md`, `docs/BUILDING.md`.
Not live-linked in the dlc install (deliberate until the 2.1 retarget).

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
3. **`!` prefix = conflict, not dependency**: `! Transport_Drones_Meglinge_Fork
   >= 1.0.26` means the Meglinge fork must NOT be present. Don't "fix" it
   into a `?`.
4. **Hard dep is the fork, not upstream**: `Transport_Drones_Drdozer_Fork
   >= 1.0.27` (2.0-era maintained fork, source in
   `managed/Transport_Drones_Drdozer_Fork`, clone-only). Any retarget moves
   the fork's fv first — see the issue file's direction steps.
5. **build/ scripts are legacy, superseded by devctl**: `build/build.sh`
   (jq+zip packer, predates devctl) and `build/deploy.sh` (copies the zip
   into the live mods dir — against the current invariant; don't use it).
   Kept for provenance; `devctl mods build` + `devctl mods link` replace
   both. `docs/BUILDING.md` documents their deps (bash, jq, zip).

## Dependencies

`base >= 1.1`, `Transport_Drones_Drdozer_Fork >= 1.0.27` (hard),
`! Transport_Drones_Meglinge_Fork >= 1.0.26` (conflict),
`? AsphaltRoadsPatched >= 1.4.7` (1.5.0 zip in dlc install is fv 2.1),
`? pyindustry >= 1.5.4`, `? space-exploration >= 0.6.82`,
`? railloader >= 1.1.6`. No py code branches beyond pyindustry asphalt tiles.

## Verification quick recipe

- Hermetic load probes: superproject `docs/testing.md` §3; rig pattern
  `.cache/transport-drones-port/` (dlc + vanilla scratch; symlink
  `src/` as `Transport-Drones-On-Asphalt` + the fork's zip symlink for the
  hard dep — portal mods are NOT auto-enabled, see data-lifecycle).
- Expected dlc (2.1.21) result until retargeted: fv-gate rejection naming
  both the mod and the fork — that is the *correct* gate outcome (exact
  text in the issue file).
- `devctl mods build transport-drones-on-asphalt` works on the src/ layout
  (zip 1.4MB incl. thumbnail; game content only).

## Docs index

- `README.md` — human-facing feature list
- `docs/BUILDING.md` — legacy build-script deps (bash/jq/zip)
- `src/changelog.txt` — release history (0.1.0 → 0.1.7)
- `docs/journal.md` — session work log
- Superproject `issues/transport-drones-not-2.1.md`,
  `issues/live-dir-stray-transport-drones-0.1.6.md` — open problems
