-- inspired by drone-roads
local arci_prefix = "Arci-"

if mods["AsphaltPaving"] then
    local transport_system_technology = "transport-system"
    local aslphalt_technology = "Arci-asphalt"


    -- gate transport drones behind asphalt
    if data.raw.technology[transport_system_technology] then
        table.insert(data.raw.technology[aslphalt_technology].prerequisites, transport_system_technology)
    end

    -- set the acri road tiles to being drone road tiles
    for name, value in pairs(data.raw.item) do
        if name:find(arci_prefix, 1, true) == 1 then
            value.is_road_tile = true
        end
    end

    -- for space exploration enable the asphalt tiles in space
    if mods["space-exploration"] then
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
    -- set py-aslphalt road tiles to being drone road tiles
    for name, value in pairs(data.raw.item) do
        if name:find("py-asphalt", 1, true) == 1 then
            value.is_road_tile = true
        end
    end
end