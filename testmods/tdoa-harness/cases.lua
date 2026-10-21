-- tdoa-harness — the parameterised case table.
--
-- Adding a test tile is one row here. The harness builds one depot rig per
-- case (parallel rigs at fixed offsets on one deterministic map) and asserts
-- the road-integration behaviour through real drone deliveries. Cases are
-- keyed by TILE prototype (the runtime API exposes tiles, not items' data
-- stage place_as_tile).
--
-- Case fields:
--   key        unique case name (shows up in results.json and the runner)
--   fill       how the 2x2 gap is filled at fill tick:
--                { tile = "<tile prototype>" }      place this tile directly;
--                                                   skipped ("skipped") when
--                                                   the tile prototype does
--                                                   not exist in the env (the
--                                                   partner mod is absent)
--                { prefix_tiles = "<prefix>" }      expand to ONE RIG PER ROAD
--                                                   TILE in the mod's road set
--                                                   whose name starts with
--                                                   prefix (empty → skipped);
--                                                   zero hand-maintenance of
--                                                   generated variants
--                { enumerate_road_set = true }      a rig for EVERY tile in
--                                                   the mod's road set, minus
--                                                   the tiles covered by
--                                                   other rows
--                nil                                leave the gap empty
--   expect     "road"    — the requester must dispatch, collect from the
--                          supply depot across the gap and deliver by the
--                          deadline (assertion: the SUPPLY loses cargo —
--                          the request's own output inventory is engine-
--                          managed and not a pathing witness).
--              "blocked" — no dispatch, no delivery by the deadline.
--   note       free text, copied verbatim into results.json.
--
-- Env matrix (docs/harness.md): a case whose tile doesn't exist in an env is
-- reported "skipped", not failed — the env spec selects the combination.

return
{
  -- ---- controls (Transport_Drones only; must hold in every env) ------------
  {
    key = "null-road",
    fill = { tile = "transport-drone-road" },
    expect = "road",
    note = "positive control: upstream's own road reconnects the gap",
  },
  {
    key = "empty-gap",
    fill = nil,
    expect = "blocked",
    note = "never filled: two road segments stay disconnected",
  },

  -- ---- asphalt-roads (Arci-) integration: base + generated variants --------
  {
    key = "arci-base",
    fill = { tile = "Arci-asphalt" },
    expect = "road",
    note = "ARP base tile (item Arci-asphalt places exactly this tile name)",
  },
  {
    key = "arci-generated",
    fill = { prefix_tiles = "Arci-" },
    expect = "road",
    note = "one rig per generated Arci-* tile in the mod's road set (full matrix, enumerated at runtime); the base tile is covered again here in addition to its dedicated rig above",
  },

  -- ---- pyindustry integration ---------------------------------------------
  {
    key = "py-asphalt",
    fill = { tile = "py-asphalt" },
    expect = "road",
    note = "pyindustry 3.1.6's single py-asphalt tile (no walking boost, no tech gate on this branch — behaviour asymmetry pending maintainer)",
  },

  -- ---- negatives (base tiles; must never reconnect) ------------------------
  {
    key = "neg-landfill",
    fill = { tile = "landfill" },
    expect = "blocked",
    note = "base landfill",
  },
  {
    key = "neg-concrete",
    fill = { tile = "concrete" },
    expect = "blocked",
    note = "base concrete",
  },
  {
    key = "neg-stone-path",
    fill = { tile = "stone-path" },
    expect = "blocked",
    note = "base stone-path (the 2.0 renames of the 1.1 stone-brick path)",
  },
}