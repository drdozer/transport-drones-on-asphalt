# Enable Various Road Tiles as Transport Drone Roads

**Transport Drones on Asphalt** lets Transport Drone trucks drive on road
surfaces from other mods. Currently supported:

- **Asphalt Roads** — the full generated `Arci-` tile set (66 tiles incl.
  directional variants), walking speed boosted to match the better road.
- **Space Exploration** — asphalt placeability in space.
- **PyIndustry** — the `py-asphalt` surface (≥ 3.1.6 build).
- **water-ford** — the cobblestone **ford** and cobblestone **path** as drone
  roads; the wooden crossing intentionally stays player-only (drones are
  blocked on water-family decks by design; this mod never registers wooden
  variants).

The only required mod is **Transport Drones ≥ 2.1.4** (the official
Factorio 2.1 line). Driving on the road tiles of the other mods is enabled
automatically when that mod is installed — every integration is an
*optional* dependency.

## Verification

Every supported surface is asserted by a real drone delivery in the repo's
depot-matrix harness (parallel depot rigs on a seed-pinned map, a 2×2 gap
filled per tile, the supply depot's drain as the observable) — the gallery
images are rendered by the harness itself. Factorio 2.1, `base >= 2.1.0`.

## Notes

- Walking/tech gates: Asphalt Roads tiles get the boosted walking modifier;
  PyIndustry and water-ford tiles keep their own speeds (no walking-boost
  contract for those yet).
- The cobblestone ford item keeps its **place-on-water-only** rule after
  road registration.