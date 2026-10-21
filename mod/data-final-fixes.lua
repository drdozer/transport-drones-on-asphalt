-- Data-final-fixes normalisation for the water-ford cobble ladder.
--
-- This stage deliberately runs LAST for the pieces it touches: tdoa depends
-- on Transport_Drones (hard) and water-ford (optional), and final-fixes files
-- execute in that same order (Transport_Drones -> water-ford -> tdoa), so it
-- sees the combined effect of Transport_Drones' road processing and
-- water-ford's collision-layer stamps and normalises afterwards.
--
-- Consequences of Transport_Drones' road processing being normalised here:
--
-- 1. process_road_item (Transport_Drones data-final-fixes) overwrites road
--    ITEMS' place_as_tile with its own non-inverted condition
--    {layers = {water_tile = true}} — a rule that means "may not be placed
--    on water" (cf. the wooden-flooring/land items' pattern). For base tiles
--    that is the roads' own choice; for the cobblestone FORD it would invert
--    the item's very purpose (the ford exists to bridge water: its rule is
--    the inverted {water_tile} condition = water-only, the same proven
--    pattern as the wooden ford item). Restore the ford's water-only rule.
--    The land partner (cobblestone-path) already carries exactly Transport_
--    Drones' rewritten rule — no action.
-- 2. The drone road network's LOAD-PATH rebuild (Transport_Drones
--    script/road_network.lua get_tiles) admits a tile as a road node only
--    when its runtime tile mask matches the transport-drone-road mask
--    EXACTLY (same layers, same size). water-ford's data-final-fixes stamps
--    the cobblestone ford tile with its pedestrian/vehicle layers AFTER
--    Transport_Drones' rewrite, leaving a mask like
--    {transport_drone_road, water-ford, water-ford-pedestrian}: the tile
--    connects through the raised-set-tiles path (proxy_tile.lua reads only
--    the road-tile-list) but is silently DROPPED from the network after
--    every save/load. Normalise the cobble ford tile's mask to the road
--    layer exactly. The ford-smoke runner exercises precisely this (create
--    -> benchmark is a save/load cycle).
--
-- Order-sensitivity note (durable): Transport_Drones' drone-collision
-- collection (all-used-tile-layers minus the road layer) also runs BEFORE
-- water-ford's stamps, so the ford-only layers never enter the drone mask —
-- the stamps stay drone-inert in the shipped order (Transport_Drones ->
-- water-ford -> tdoa, name order among independent chains).
--
-- Everything here is guarded: absent water-ford (or an absent cobble item)
-- is a no-op, so this file is inert in every env without water-ford.

local road_layer = "transport_drone_road"

local ford_item = data.raw.item["cobblestone-ford"]
if ford_item and ford_item.is_road_tile then
    -- (1) restore the water-bridging placement rule
    if ford_item.place_as_tile then
        ford_item.place_as_tile.condition = { layers = { water_tile = true } }
        ford_item.place_as_tile.invert = true
    end
    -- (2) the road-exact mask the load-path rebuild requires
    local ford_tile = data.raw.tile["cobblestone-ford"]
    if ford_tile then
        ford_tile.collision_mask = { layers = { [road_layer] = true } }
    end
end