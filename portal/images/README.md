Portal gallery images land here; numeric prefix = display order, png/jpg.
Uploaded via the portal images API (docs/portal-publishing.md; page sync
from this folder in numeric-prefix order). This README documents the
convention and provenance — it is not itself an image.

Provenance: every image here is rendered from the mod's own test harness
(`testing/showcase.py` → the depot-matrix scenario's screenshot milestones,
game.take_screenshot at absolute world coordinates; see docs/harness.md):
real in-game content from the test rigs, not mock-ups. Regenerate with
`python3 testing/showcase.py [solo|ford-smoke]` after visual changes.

- 01-matrix.png — the depot matrix (solo env): every test rig = a 2-wide
  road strip split by an unfilled 2×2 gap, fuel+request west, supply east.
- 02-road-fill.png — the gap being filled with the transport-drone road
  (raised set_tiles), the harness's reconnection idiom.
- 03-drone-crossing.png — a transport drone homeward-bound over the road,
  collected cargo in tow, mid-transit across the gap.
- 04-delivered.png — post-delivery: the supply depot drained, the cargo
  driven across the reconnect road.
- 05-water-ford.png — the water-ford cell (ford-smoke env): cobblestone
  ford / cobblestone path rows (drone-crossable by integration) and the
  wooden ford row (blocked by design) in the same matrix.