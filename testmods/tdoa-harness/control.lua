-- tdoa-harness — depot delivery matrix driver.
--
-- ONE deterministic map (seed pinned by the runner's --map-gen-settings), one
-- timeline anchored at the BUILD tick (game tick 100), relative ticks after
-- that. All rig geometry is 2-wide roads.
--
--   rel 0      per case in cases.lua: clean a rig box, lay two 2-wide road
--              segments split by an unfilled 2x2 gap, place depot trio
--              (fuel + request west / supply east), stock by script (drones
--              in crafter_input, petroleum-gas in the fuel depot, cargo in
--              the supply depot), set the request via its request-<cargo>
--              recipe (all technologies researched in on_init).
--   rel ~100   the fuel depot's push-model drone fuels the request depot —
--              the harness self-check: a rig without fuel delivery is
--              harness-invalid, not a case failure.
--   rel FILL   the gap is filled with the case's tile via raised set_tiles
--              (Transport_Drones watches script_raised_set_tiles and add_node
--              MERGES the two road networks — the same idiom as upstream's
--              own script/self_test.lua check_road_network_split). Empty-gap
--              cases skip this.
--   rel FILL.. the request depot dispatches its drone across the gap,
--              collects at the supply depot, returns; drone despawns.
--              Observable: cargo in the request depot's output inventory.
--   rel DEADLINE  every case resolves:
--              expect road    pass iff fuel delivered AND drone dispatched
--                             AND >=1 cargo delivered
--              expect blocked pass iff fuel delivered AND no dispatch AND
--                             no cargo
--
-- All state persists through storage.scalars only (first-observed-wins
-- writes + world re-derivation of entity refs per session) — arbitrary Lua
-- globals and local tables do NOT survive the create->benchmark save/load
-- (bridged only, as upstream does for its own script_data).
--
-- Results land in script-output/tdoa-harness/results.json; the standalone
-- runner (testing/run-scenario.py) maps them onto exit codes.
--
-- Dev-only: builds rigs on any map this testmod is enabled in (runs are
-- scratch instances assembled by the runner) — never enable it in a real
-- game.

local CASES = require("cases")

local ROAD_ITEM = "transport-drone-road"
local ROAD_LIST_ITEM = "road-tile-list"
local DRONE_ITEM = "transport-drone"
local FUEL_FLUID = "petroleum-gas"
local DRONES_PER_DEPOT = 2
local CARGO_STOCK = 4000
local FUEL_STOCK = 100000

-- the delivered item: primary + fallbacks, first whose request-<name>
-- recipe exists (created for every non-hidden item by Transport_Drones)
local CARGO_CANDIDATES = { "small-lamp", "medium-electric-pole", "iron-plate" }

local BUILD_TICK = 100
local FILL_REL = 600
local DEADLINE_REL = 5000
local POLL_CADENCE = 4
local RIG_PITCH = 24

-- rig geometry, relative to the rig origin (0, oy) — roads are 2 tiles wide;
-- the gap is the strip's 2 columns for 2 rows (spans both lanes)
local X_MIN, X_MAX = -36, 36
local GAP_X = { 0, 1 }
local LANE_TOP, LANE_BOTTOM = 0, 1
local W_DEPOT = -33
local E_DEPOT = 33
local STUB_Y0, STUB_Y1 = -3, 4

local script_data = storage.tdoa_harness or
{
  base = nil, cargo = nil, error = nil,
  errors = {},
  fuel_tick = {}, dispatch_tick = {}, lamp_tick = {}, lamp_count = {},
  supply_count = {}, supply_drain_tick = {},
  filled = {}, verdict = {}, reason = {},
  results_written = false, road_set = nil,

  -- showcase mode (tdoa-showcase wrapper mod / testing/showcase.py):
  -- milestone screenshots at fixed world coordinates. Shot jobs are PLAIN
  -- DATA records (function closures do not survive the save) fired in order.
  showcase = false, shot_next = 1, shots_requested = 0,
  shots_taken = {}, shots_pending = {},
  shots_transit = false, shots_fuel = false, showcase_anchor = nil,
}

-- JSON out: all records are flat (string keys, string/number/boolean values).
local function json_encode(v)
  local t = type(v)
  if t == "nil" then return "null" end
  if t == "number" then
    if v == math.floor(v) then return string.format("%.0f", v) end
    return string.format("%.3f", v)
  end
  if t == "boolean" then return tostring(v) end
  if t == "string" then
    return '"' .. v:gsub("[%c\"\\]", function(c)
      if c == "\"" then return "\\\"" end
      if c == "\\" then return "\\\\" end
      if c == "\n" then return "\\n" end
      if c == "\t" then return "\\t" end
      return string.format("\\x%02x", c:byte())
    end) .. '"'
  end
  if t == "table" then
    local is_array = (#v > 0)
    local parts = {}
    if is_array then
      for _, item in ipairs(v) do parts[#parts + 1] = json_encode(item) end
      return "[" .. table.concat(parts, ",") .. "]"
    end
    for k, item in pairs(v) do
      parts[#parts + 1] = json_encode(tostring(k)) .. ":" .. json_encode(item)
    end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return "null"
end

local function road_set_read()
  if script_data.road_set then return script_data.road_set end
  local set = {}
  local list_proto = prototypes.item[ROAD_LIST_ITEM]
  if list_proto and list_proto.get_tile_filters then
    for _, tile_proto in pairs(list_proto.get_tile_filters(defines.selection_mode.select) or {}) do
      set[tile_proto.name] = true
    end
  end
  script_data.road_set = set
  return set
end

-- expand the (prefix) cases; returns the flat rig list ordered deterministically
local function resolve_cases()
  local road_set = road_set_read()
  local rigs = {}
  local function is_road_member(tile_name)
    return road_set[tile_name] == true
  end

  for _, case in ipairs(CASES) do
    local fill = case.fill
    if not fill then
      rigs[#rigs + 1] = { key = case.key, expect = case.expect, note = case.note, fill_tile = nil, member = false }
    elseif fill.tile then
      if prototypes.tile[fill.tile] then
        rigs[#rigs + 1] = { key = case.key, expect = case.expect, note = case.note,
          fill_tile = fill.tile, member = is_road_member(fill.tile) }
      else
        rigs[#rigs + 1] = { key = case.key, expect = case.expect, note = case.note,
          fill_tile = nil, member = false, skip = "tile prototype absent in this env: " .. fill.tile }
      end
    elseif fill.prefix_tiles then
      local names = {}
      for name in pairs(road_set) do
        if name:sub(1, #fill.prefix_tiles) == fill.prefix_tiles then
          names[#names + 1] = name
        end
      end
      table.sort(names)
      if #names == 0 then
        rigs[#rigs + 1] = { key = case.key, expect = case.expect, note = case.note,
          fill_tile = nil, member = false, skip = "no road-set tiles match prefix: " .. fill.prefix_tiles }
      else
        for _, tile in ipairs(names) do
          rigs[#rigs + 1] = { key = fill.prefix_tiles .. tile:sub(#fill.prefix_tiles + 1),
            expect = case.expect, note = case.note, fill_tile = tile, member = true }
        end
      end
    else
      rigs[#rigs + 1] = { key = case.key, expect = "blocked", note = "malformed case (no fill spec), treated as empty",
        fill_tile = nil, member = false, skip = "malformed fill" }
    end
  end
  return rigs
end

local function build_road_tiles(oy)
  local tiles = {}
  local function add(x, y) tiles[#tiles + 1] = { name = ROAD_ITEM, position = { x, oy + y } } end
  for x = X_MIN, X_MAX do
    if not (x >= GAP_X[1] and x <= GAP_X[2]) then
      add(x, LANE_TOP)
      add(x, LANE_BOTTOM)
    end
  end
  for _, sx in ipairs({ W_DEPOT - 1, W_DEPOT, E_DEPOT, E_DEPOT + 1 }) do
    for y = STUB_Y0, STUB_Y1 do add(sx, y) end
  end
  return tiles
end

local function purge_rig_area(surface, oy)
  -- the default map carries water, trees, cliffs, resources and enemy life —
  -- the rig box is cleansed so the assertion holds regardless of seed terrain;
  -- wiped repeatedly (oreguard lab purge pattern) so rebuilds start clean too.
  for _ = 1, 3 do
    local box = { { X_MIN - 4, oy + STUB_Y0 - 4 }, { X_MAX + 4, oy + STUB_Y1 + 9 } }
    for _, ent in pairs(surface.find_entities_filtered{ area = box, force = "enemy" }) do
      ent.destroy()
    end
    for _, ent in pairs(surface.find_entities_filtered{ area = box,
      type = { "resource", "tree", "simple-entity", "cliff", "fish", "turret" } }) do
      ent.destroy()
    end
    for _, ent in pairs(surface.find_entities_filtered{ area = box,
      name = { "fuel-depot", "request-depot", "supply-depot" } }) do
      ent.destroy()
    end
  end
end

script.on_init(function()
  game.forces.player.research_all_technologies()
end)

-- mod-state introspection: WORLD-STATE ONLY (the mod's script modules are
-- instance-local: a cross-mod require makes a second, empty copy — Factorio
-- does not canonicalize require paths across mods — so read the world and
-- their remote interface instead, never a required module's tables).
local function mod_state_summary(rig)
  local surface = game.surfaces[1]
  local function descr(ent)
    if not (ent and ent.valid) then return "invalid/missing" end
    local corpse = surface.find_entities_filtered{ name = "transport-caution-corpse",
      position = ent.position, radius = 4 }
    local details = {}
    for _, c in pairs(corpse) do
      details[#details + 1] = "corpse@" .. c.position.x .. "," .. c.position.y ..
        " tile=" .. surface.get_tile(c.position).name
    end
    local out = ent.name .. " fuel=" .. tostring(ent.get_fluid_count(FUEL_FLUID))
    if ent.name == "request-depot" then
      local recipe = ent.get_recipe()
      out = out .. " recipe=" .. (recipe and recipe.name or "NONE") ..
        " drones=" .. (ent.get_inventory(defines.inventory.crafter_input).get_item_count(DRONE_ITEM))
    end
    return out .. " | " .. table.concat(details, ";")
  end
  return "fuel[" .. descr(rig.fuel) .. "] req[" .. descr(rig.request) .. "] sup[" .. descr(rig.supply) .. "]"
end

-- one rig's world-derived handle set, per session
local rigs = nil

local function adopt_rig(surface, rig)
  local oy = rig.oy
  local box = { { X_MIN - 2, oy + STUB_Y0 - 2 }, { X_MAX + 2, oy + STUB_Y1 + 7 } }
  rig.fuel = surface.find_entities_filtered{ name = "fuel-depot", area = box, limit = 1 }[1]
  rig.request = surface.find_entities_filtered{ name = "request-depot", area = box, limit = 1 }[1]
  rig.supply = surface.find_entities_filtered{ name = "supply-depot", area = box, limit = 1 }[1]
  rig.valid = rig.fuel and rig.request and rig.supply
      and rig.fuel.valid and rig.request.valid and rig.supply.valid
  return rig.valid
end

local function build_rig(surface, force, rig, cargo)
  local oy = rig.oy
  purge_rig_area(surface, oy)
  surface.set_tiles(build_road_tiles(oy), true, "abort_on_collision", false, true)

  -- depots register on the road network via their corpse tile (offset from
  -- the entity centre by depot kind/direction — fuel south +3, request north
  -- -2, supply south +2); each corpse tile sits on an existing road tile.
  rig.fuel = surface.create_entity{ name = "fuel-depot", position = { W_DEPOT, oy - 6 },
    direction = defines.direction.south, force = force, raise_built = true }
  rig.request = surface.create_entity{ name = "request-depot", position = { W_DEPOT, oy + 6 },
    direction = defines.direction.north, force = force, raise_built = true }
  rig.supply = surface.create_entity{ name = "supply-depot", position = { E_DEPOT, oy - 6 },
    direction = defines.direction.south, force = force, raise_built = true }
  for _, ent in pairs({ rig.fuel, rig.request, rig.supply }) do
    if not (ent and ent.valid) then
      error("entity build failed: " .. rig.key)
    end
  end

  rig.fuel.insert_fluid{ name = FUEL_FLUID, amount = FUEL_STOCK }
  rig.fuel.get_inventory(defines.inventory.crafter_input).insert{ name = DRONE_ITEM, count = DRONES_PER_DEPOT }
  -- recipe FIRST: set_recipe re-slots the machine's crafting inventory and
  -- clears drone items inserted before it (upstream's self_test order)
  rig.request.set_recipe("request-" .. cargo)
  rig.request.get_inventory(defines.inventory.crafter_input).insert{ name = DRONE_ITEM, count = DRONES_PER_DEPOT }
  rig.supply.insert{ name = cargo, count = CARGO_STOCK }
  rig.valid = true
end

local function fill_gap(rig, surface)
  if not rig.fill_tile then
    script_data.filled[rig.index] = true
    return
  end
  local tiles = {}
  for _, x in ipairs(GAP_X) do
    for _, y in ipairs({ LANE_TOP, LANE_BOTTOM }) do
      tiles[#tiles + 1] = { name = rig.fill_tile, position = { x, rig.oy + y } }
    end
  end
  surface.set_tiles(tiles, true, "abort_on_collision", false, true)
  script_data.filled[rig.index] = true
  log("HARNESS: filled " .. rig.key .. " with " .. rig.fill_tile)
end

local function finish(rig, verdict, reason)
  script_data.verdict[rig.index] = verdict
  script_data.reason[rig.index] = reason
  log("HARNESS: " .. rig.key .. " -> " .. verdict .. (reason ~= "" and (" (" .. reason .. ")") or ""))
end

local function poll_rig(rig)
  if not rig.valid then return end
  local i = rig.index

  if not script_data.fuel_tick[i] and rig.request.get_fluid_count(FUEL_FLUID) > 0 then
    script_data.fuel_tick[i] = game.tick
  end
  local drone_inv = rig.request.get_inventory(defines.inventory.crafter_input)
  local stock = drone_inv and drone_inv.get_item_count(DRONE_ITEM) or (DRONES_PER_DEPOT + 1)
  if stock < DRONES_PER_DEPOT and not script_data.dispatch_tick[i] then
    script_data.dispatch_tick[i] = game.tick
  end
  local output = rig.request.get_output_inventory()
  local lamps = output and output.get_item_count(script_data.cargo) or 0
  if lamps > (script_data.lamp_count[i] or 0) then
    script_data.lamp_count[i] = lamps
    script_data.lamp_tick[i] = game.tick
  end
  local supply_inv = rig.supply.get_output_inventory()
  local supply_count = supply_inv and supply_inv.get_item_count(script_data.cargo) or nil
  if supply_count then
    script_data.supply_count[i] = supply_count
    if supply_count < CARGO_STOCK and not script_data.supply_drain_tick[i] then
      script_data.supply_drain_tick[i] = game.tick
    end
  end
end

-- ---------------------------------------------------------------------------
-- showcase mode: milestone screenshots. Enabled via this harness's remote
-- interface by the tdoa-showcase wrapper mod — mod globals do NOT cross mod
-- environments (each control.lua gets its own env; only storage / remote
-- cross). All frames are in-game ABSOLUTE coordinates; zoom z renders
-- (32 * z) px per tile. Headless sessions ignore take_screenshot entirely
-- (engine: "if running headless, this function will do nothing") — showcase
-- runs must be the windowed client (testing/showcase.py).
-- ---------------------------------------------------------------------------

local function seq_label(name)
  local label = string.format("%02d-%s", script_data.shot_next, name)
  script_data.shot_next = script_data.shot_next + 1
  return label
end

local function schedule_shot(when, frame)
  frame.when = when
  frame.label = seq_label(frame.label)
  script_data.shots_pending[#script_data.shots_pending + 1] = frame
end

local function do_shot(frame)
  local path = "tdoa-harness/showcase/" .. frame.label .. ".png"
  script_data.shots_requested = script_data.shots_requested + 1
  local ok, res = pcall(function()
    game.take_screenshot{
      position = { (frame.x0 + frame.x1) / 2, (frame.y0 + frame.y1) / 2 },
      resolution = { x = math.ceil((frame.x1 - frame.x0 + 1) * 32 * frame.zoom) + 1,
                     y = math.ceil((frame.y1 - frame.y0 + 1) * 32 * frame.zoom) + 1 },
      zoom = frame.zoom, surface = 1, path = path,
      show_entity_info = true, show_gui = false,
      hide_fog = true, hide_clouds = true, daytime = 0,
      force_render = true, anti_alias = true,
    }
  end)
  if ok then
    script_data.shots_taken[#script_data.shots_taken + 1] = path
  else
    path = "FAILED " .. path .. ": " .. tostring(res)
    script_data.shots_taken[#script_data.shots_taken + 1] = path
  end
  log("HARNESS: screenshot " .. path)
end

-- frame helpers: rig strip = full road length; gap close = the 2x2 gap area
local function rig_frame(rig, label, zoom)
  return { label = label, x0 = X_MIN - 6, x1 = X_MAX + 6,
    y0 = rig.oy + STUB_Y0 - 8, y1 = rig.oy + STUB_Y1 + 10, zoom = zoom or 0.75 }
end

local function gap_frame(rig, label, zoom)
  return { label = label, x0 = -20, x1 = 22,
    y0 = rig.oy + LANE_TOP - 11, y1 = rig.oy + LANE_TOP + 11, zoom = zoom or 1 }
end

local function wide_frame(rigs_list, label)
  local n = #rigs_list
  return { label = label, x0 = X_MIN - 6, x1 = X_MAX + 6,
    y0 = RIG_PITCH + STUB_Y0 - 10, y1 = n * RIG_PITCH + STUB_Y1 + 10,
    zoom = math.min(0.55,
      1600 / ((X_MAX - X_MIN + 13) * 32),
      3600 / ((n * RIG_PITCH + 40) * 32)) }
end

-- fires due shot jobs; once the anchor rig's drone has collected at the
-- supply (drain_tick) it schedules the homeward burst — by the observed
-- fill->collect flight rate (~0.07 tiles/tick) the drone crosses the gap
-- ~drain+346..466 and approaches the request depot ~drain+800..860
local function showcase_tick()
  if not script_data.showcase or script_data.results_written then return end
  local pending = script_data.shots_pending
  if #pending > 0 then
    local now = game.tick
    local rest = {}
    for _, frame in ipairs(pending) do
      if frame.when <= now then do_shot(frame) else rest[#rest + 1] = frame end
    end
    script_data.shots_pending = rest
  end
  local anchor = rigs and script_data.showcase_anchor and rigs[script_data.showcase_anchor]
  if not anchor then return end
  local drain = script_data.supply_drain_tick[anchor.index]
  if drain and not script_data.shots_transit then
    script_data.shots_transit = true
    local k = anchor.key
    schedule_shot(drain + 6, { label = "pick-" .. k, x0 = 10, x1 = 42,
      y0 = anchor.oy + LANE_TOP - 11, y1 = anchor.oy + LANE_TOP + 11, zoom = 1 })
    for _, d in ipairs({ 346, 386, 426, 466 }) do
      schedule_shot(drain + d, rig_frame(anchor, "transit-" .. d .. "-" .. k, 1))
    end
    for _, d in ipairs({ 800, 830, 860 }) do
      schedule_shot(drain + d, { label = "arrival-" .. d .. "-" .. k,
        x0 = -45, x1 = 2, y0 = anchor.oy + LANE_TOP - 11,
        y1 = anchor.oy + LANE_TOP + 11, zoom = 1 })
    end
  end
  local fuel = script_data.fuel_tick[anchor.index]
  if fuel and not script_data.shots_fuel then
    script_data.shots_fuel = true
    schedule_shot(fuel + 40, rig_frame(anchor, "fuel-truck-" .. anchor.key, 0.75))
  end
end

remote.add_interface("tdoa_harness", {
  enable_showcase = function()
    script_data.showcase = true
    script_data.shots_pending = script_data.shots_pending or {}
    script_data.shot_next = script_data.shot_next or 1
    log("HARNESS: showcase enabled via remote interface")
  end,
})

script.on_event(defines.events.on_tick, function(event)
  if script_data.results_written then return end
  local tick = event.tick

  -- build phase: fixed tick; retried on later ticks if it failed
  if not script_data.base and tick >= BUILD_TICK then
    local surface = game.surfaces[1]
    local force = game.forces.player
    local cargo = nil
    for _, candidate in ipairs(CARGO_CANDIDATES) do
      if prototypes.recipe["request-" .. candidate] then cargo = candidate break end
    end
    if not cargo then
      log("HARNESS: no request-<cargo> recipe found among candidates; aborting")
      script_data.base = true   -- dead-end marker: never settles, loud results
      for i = 1, #resolve_cases() do script_data.verdict[i] = "harness-invalid" end
      -- write results from a minimal state
      script_data.cargo = "?"
      script_data.base_tick = nil
      write_results()
      return
    end
    script_data.cargo = cargo

    local rigs_list = resolve_cases()
    for i, rig in ipairs(rigs_list) do
      rig.index = i
      rig.oy = i * RIG_PITCH
      surface.request_to_generate_chunks({ 0, rig.oy }, 4)
    end
    surface.force_generate_chunk_requests()

    local ok_build = true
    for _, rig in ipairs(rigs_list) do
      if not rig.skip then
        local ok, err = pcall(build_rig, surface, force, rig, cargo)
        if not ok then
          ok_build = false
          script_data.error = tostring(err)
          log("HARNESS: build error in rig " .. rig.key .. ": " .. script_data.error)
          break
        end
      end
    end
    if ok_build then
      script_data.base = tick
      script_data.errors = {}
      script_data.error = nil
      log("HARNESS: build complete at tick " .. tick .. " (cargo " .. cargo .. "); timeline anchored")
      if script_data.showcase then
        schedule_shot(tick + 6, wide_frame(rigs_list, "build-wide"))
        for _, rig in ipairs(rigs_list) do
          if not rig.skip and rig.expect == "road" then
            script_data.showcase_anchor = rig.index
            schedule_shot(tick + 8, rig_frame(rig, "build-" .. rig.key))
            break
          end
        end
        for _, rig in ipairs(rigs_list) do
          if not rig.skip and rig.expect == "blocked" and rig.fill_tile then
            schedule_shot(tick + 8, rig_frame(rig, "build-" .. rig.key))
            break
          end
        end
      end
      return
    end
    -- failed: wipe what we placed (purge is destructive per rig) and retry next tick
    for i, rig in ipairs(rigs_list) do
      if not rig.skip then purge_rig_area(surface, rig.oy) end
    end
    return
  end

  local base = script_data.base
  if not base or type(base) ~= "number" then return end
  local rel = tick - base

  -- adopt/refresh the rig handles for this session
  if not rigs then
    local surface = game.surfaces[1]
    rigs = resolve_cases()
    for i, rig in ipairs(rigs) do
      rig.index = i
      rig.oy = i * RIG_PITCH
      if not rig.skip then adopt_rig(surface, rig) end
    end
  end

  local surface = game.surfaces[1]

  if rel == FILL_REL then
    for _, rig in ipairs(rigs) do
      if not rig.skip and not script_data.filled[rig.index] then
        local ok, err = pcall(fill_gap, rig, surface)
        if not ok then
          script_data.errors[rig.index] = "fill: " .. tostring(err)
          script_data.verdict[rig.index] = "harness-invalid"
          script_data.reason[rig.index] = script_data.errors[rig.index]
          log("HARNESS: fill error in rig " .. rig.key .. ": " .. script_data.errors[rig.index])
        end
      end
    end
    if script_data.showcase and script_data.showcase_anchor and rigs[script_data.showcase_anchor] then
      local anchor = rigs[script_data.showcase_anchor]
      schedule_shot(base + FILL_REL + 14,
        gap_frame(anchor, "fill-" .. anchor.key, 1.5))
    end
  elseif rel > FILL_REL and rel % POLL_CADENCE == 0 then
    for _, rig in ipairs(rigs) do
      if not rig.skip and not script_data.verdict[rig.index] then
        local ok, err = pcall(poll_rig, rig)
        if not ok then
          log("HARNESS: poll error in rig " .. rig.key .. ": " .. tostring(err))
          script_data.verdict[rig.index] = "harness-invalid"
        end
      end
    end
  end

  -- road case: case completes early — REAL delivery = the supply drained
  if rel > FILL_REL and rel % POLL_CADENCE == 0 then
    for _, rig in ipairs(rigs) do
      if not rig.skip and script_data.supply_drain_tick[rig.index] and not script_data.verdict[rig.index] then
        if script_data.fuel_tick[rig.index] then
          finish(rig, "pass", "supply drained at " .. script_data.supply_drain_tick[rig.index] ..
            ", request holds " .. (script_data.lamp_count[rig.index] or 0) .. " cargo")
        else
          finish(rig, "harness-invalid", "delivered but no fuel delivery first — rig wiring broken")
        end
      end
    end
  end

  -- deadline: resolve every open case
  if rel == DEADLINE_REL then
    for _, rig in ipairs(rigs) do
      local i = rig.index
      if not script_data.verdict[i] then
        if rig.skip then
          finish(rig, "skipped", rig.skip)
        elseif script_data.errors[i] then
          finish(rig, "harness-invalid", script_data.errors[i])
        elseif not script_data.fuel_tick[i] then
          finish(rig, "harness-invalid", "no fuel delivery — rig network/depot wiring broken")
        elseif rig.expect == "road" then
          if script_data.supply_drain_tick[i] then
            finish(rig, "fail", "supply drained but verdict not recorded — poll raced the deadline")
          elseif script_data.dispatch_tick[i] then
            finish(rig, "fail", "dispatched but no supply drain by deadline — not pathing the test tile")
          else
            finish(rig, "fail", "no dispatch by deadline — tile did not reconnect the network" ..
              (rig.member == false and " (tile not in the mod's road set)" or ""))
          end
        else -- expect blocked
          if rig.member then
            finish(rig, "fail", "tile IS in the mod's road set — expected blocked")
          elseif script_data.supply_drain_tick[i] then
            finish(rig, "fail", "unexpected supply drain across a blocked fill")
          else
            finish(rig, "pass", (rig.fill_tile == nil and "gap never filled; " or "tile not in road set; ") ..
              "supply intact; request output ignored (recipe output is engine-managed)")
          end
        end
      end
    end
    if script_data.showcase then
      do_shot(wide_frame(rigs, "end-wide"))
      if script_data.showcase_anchor then
        do_shot(rig_frame(rigs[script_data.showcase_anchor],
          "end-" .. rigs[script_data.showcase_anchor].key))
      end
    end
    write_results()
  end

  showcase_tick()
end)

function write_results()
  if script_data.results_written then return end
  script_data.results_written = true
  local out = {
    harness = "tdoa-harness",
    tick = game.tick,
    overall = "pass",
    mods = {
      ["Transport-Drones-On-Asphalt"] = script.active_mods["Transport-Drones-On-Asphalt"],
      Transport_Drones = script.active_mods["Transport_Drones"],
      AsphaltRoadsPatched = script.active_mods["AsphaltRoadsPatched"],
      pyindustry = script.active_mods["pyindustry"],
    },
    cases = {},
  }
  local any_bad = false
  local rigs_list = resolve_cases()
  for i, rig in ipairs(rigs_list) do
    local rec = {
      key = rig.key,
      expect = rig.expect,
      fill = rig.fill_tile,
      in_road_set = rig.member,
      filled = script_data.filled[i] == true,
      fuel_tick = script_data.fuel_tick[i],
      dispatch_tick = script_data.dispatch_tick[i],
      lamp_tick = script_data.lamp_tick[i],
      lamp_count = script_data.lamp_count[i] or 0,
      drone_stock = DRONES_PER_DEPOT,
      supply_count = script_data.supply_count[i],
      supply_drain_tick = script_data.supply_drain_tick[i],
      verdict = script_data.verdict[i] or "harness-invalid",
      reason = script_data.reason[i] or "never settled",
      note = rig.note,
    }
    if rec.verdict == "fail" or rec.verdict == "harness-invalid" then any_bad = true end
    out.cases[#out.cases + 1] = rec
  end
  if script_data.showcase then out.showcase_shots = script_data.shots_taken end
  out.overall = any_bad and "fail" or "pass"
  helpers.write_file("tdoa-harness/results.json", json_encode(out) .. "\n")
  log("HARNESS: results written (" .. out.overall .. ", " .. #out.cases .. " cases)")
end