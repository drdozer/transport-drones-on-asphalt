# Transport Drones on Asphalt

Let **Transport Drones** drive on road surfaces from other mods: the full
**Asphalt Roads** tile set, **PyIndustry**'s `py-asphalt`, and **water-ford**'s
cobblestone ford and cobblestone path — all become drivable transport-drone
roads, the same surfaces your construction drones already love.

## What it does

Transport Drones only path across its own road tiles. This mod re-registers a
compatible surface's tile items as transport-drone roads (`is_road_tile`), so
drones cross them — with their connectivity graph, depot network and
request/supply flows intact — while you build your roads out of the surface
mod's own items.

## Supported surfaces

| Partner mod | Tiles | Walking speed |
|---|---|---|
| Asphalt Roads (or AsphaltRoadsPatched ≥ 1.5.0) | the full generated `Arci-` set (66 tiles incl. directional variants) | boosted to the better-transport-drone-road modifier |
| PyIndustry ≥ 3.1.6 | `py-asphalt` | as shipped |
| water-ford ≥ 1.1.0 | `cobblestone-ford`, `cobblestone-path` | as shipped (the ford keeps its slow water-crossing pace) |

- Walking speeds beyond the table are left to the surface mods; this mod only
  makes tiles drivable + pathable for transport drones.
- water-ford's **wooden crossing stays player-only by design** — drones are
  blocked on the wooden deck; this mod never registers the wooden variants.
- The cobblestone ford keeps its place-on-water-only item rule (restored after
  Transport Drones' road processing, which would otherwise force its own
  placement condition onto every road item).

## Requirements

- Factorio **2.1** (Space Age optional)
- **Transport Drones ≥ 2.1.4** (the official 2.1 line — this mod no longer
  ships or supports a Transport Drones fork)
- Each surface partner only when you actually run it (every integration is
  optional)

## How it is tested

The repo ships a depot-matrix scenario harness (`testmods/tdoa-harness` +
`testing/run-scenario.py`): parallel depot rigs on a seed-pinned map, every
supported tile gets its own rig, a 2×2 gap is filled with the tile, and the
assertion is a REAL drone delivery across the gap. The gallery images are
rendered by the harness's screenshot milestones — what you see is the test
itself running.

## Credits

- *Transport Drones* by Klonan (upstream, 2.1).
- *Asphalt Roads* by Arci (AsphaltRoadsPatched 1.5+ fork used for Factorio 2.1).
- Original road-paving integration by drdozer; updated for Factorio 2.1.