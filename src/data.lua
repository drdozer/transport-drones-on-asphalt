-- inspired by drone-roads



-- gate transport drones behind asphalt
local transport_system_technology = "transport-system"
local aslphalt_technology = "Arci-asphalt"
if data.raw.technology[transport_system_technology] then
    table.insert(data.raw.technology[aslphalt_technology].prerequisites, transport_system_technology)
end



-- set the acri road tiles to being drone road tiles
local arci_prefix = "Arci-"
for name, value in pairs(data.raw.item) do
    print(name)
    if name:find(arci_prefix, 1, true) == 1 then
        value.is_road_tile = true
    end
end