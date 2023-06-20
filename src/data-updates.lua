local collision_mask_util = require("collision-mask-util")

-- inspired by drone-roads
local arci_prefix = "Arci-"

-- fetch the walking speed modifier for the better transport drone road surface
local faster_modifier = 2.0
local better_road = data.raw.tile["transport-drone-road-better"]
if better_road then
    -- log("Found better road")
    local modifier = better_road.walking_speed_modifier
    -- log("Better road walking speed modifier: ".. modifier)
    if modifier then
        faster_modifier = modifier
    end
end
-- log("Setting boosted walking modifier for roads to "..faster_modifier)


if mods["AsphaltPaving"] then
    log("Adding AsphaltPaving compatibility.")

    local transport_system_technology = "transport-system"
    local aslphalt_technology = "Arci-asphalt"


    -- gate transport drones behind asphalt
    if data.raw.technology[transport_system_technology] then
        table.insert(data.raw.technology[aslphalt_technology].prerequisites, transport_system_technology)
    end

    -- set the acri road tiles to being drone road tiles
    for name, value in pairs(data.raw.item) do
        if name:find(arci_prefix, 1, true) == 1 then
            log("Enabling "..name.." as a road surface")
            value.is_road_tile = true
        end
    end
    -- and adjust their speeds
    for name, tile in pairs(data.raw.tile) do
        if name:find(arci_prefix, 1, true) == 1 then
            log("Adjusting "..name.." speed bonus")
            local old_wsm = tile.walking_speed_modifier
            local wsm = math.max(old_wsm, faster_modifier)
            log("Old walking speed: "..old_wsm.." updated to "..wsm)
            tile.walking_speed_modifier = wsm
        end
    end
            

    -- for space exploration enable the asphalt tiles in space
    if mods["space-exploration"] then
        log("Adding space exploration compatibility for asphalt paving.")

        -- set the acri road tiles to being drone road tiles
        for name, value in pairs(data.raw.item) do
            if name:find(arci_prefix, 1, true) == 1 then
                table.insert(value.place_as_tile.condition, spaceship_collision_layer)
            end
        end
    end
end

-- for py
if mods["pyindustry"] then
    log("Adding pyindustry compatibility.")
    -- set py-aslphalt road tiles to being drone road tiles
    for name, value in pairs(data.raw.item) do
        if name:find("py-asphalt", 1, true) == 1 then
            log("Enabling py-asphalt as a road surface")
            value.is_road_tile = true
        end
    end
end

if mods["railloader"] then
    log("Adding railloader compatiblity.")
    -- All things with a collision mask containing "item-layer" will be marked by transport drones
    -- as being a non-road entity.
    -- Bulk Rail Loader uses composite entities.
    -- The initially placed item is a pump, which has the "item_layer" set to true.
    -- So we need to unset this collision mask on the pump used by BRL.
    
    local brl
    local mask

    brl = data.raw.pump["railloader-placement-proxy"]
    mask = collision_mask_util.get_mask(brl)
    collision_mask_util.remove_layer(
        mask, "item-layer")
    brl.collision_mask = mask
        
    brl = data.raw.pump["railunloader-placement-proxy"]
    mask = collision_mask_util.get_mask(brl)
    collision_mask_util.remove_layer(
        mask, "item-layer")
    brl.collision_mask = mask
end