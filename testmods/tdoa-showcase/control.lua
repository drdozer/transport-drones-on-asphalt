-- tdoa-showcase — wrapper that turns on the depot-matrix driver's screenshot
-- milestones. Mod globals do NOT cross mod environments, so the flag travels
-- through the harness's remote interface (the sanctioned channel beside
-- storage); retried on the first ticks in case of load-order surprises.
--
-- Enabled only by testing/showcase.py against scratch instances; never enable
-- this testmod in a real game (it only mutates the harness driver's state).
script.on_event(defines.events.on_tick, function()
  if storage.tdoa_showcase_armed then return end
  if remote.interfaces["tdoa_harness"] then
    remote.call("tdoa_harness", "enable_showcase")
    storage.tdoa_showcase_armed = true
    log("HARNESS-SHOWCASE: wrapper armed the driver's showcases")
  elseif game.tick > 200 then
    log("HARNESS-SHOWCASE: tdoa_harness remote interface never appeared")
    storage.tdoa_showcase_armed = true
  end
end)