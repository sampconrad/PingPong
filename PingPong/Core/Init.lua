---------------------------------------------------------------------------------------
-- PingPong/Core/Init.lua — CORE — namespace, constants and the secret-value guard
--
-- What it does: fills the addon table every file shares with the tuning numbers.
-- Architecture: loaded first. Other files read these constants at load or call time.
-- Does not: touch frames, events or saved data (the addon has none).
-- Related: Comms.lua, MapProvider.lua, PingFrame.lua.
---------------------------------------------------------------------------------------
local _, PingPong = ...

PingPong.PREFIX = "PingPong"

PingPong.DOUBLE_CLICK_WINDOW = 0.3 -- seconds between the two clicks
PingPong.DOUBLE_CLICK_TOLERANCE = 12 -- screen pixels the cursor may drift between them
PingPong.SEND_COOLDOWN = 1 -- addon messages refill at one per second per prefix
PingPong.SENDER_COOLDOWN = 0.5 -- fewest seconds between accepted pings from one player
PingPong.BURST_PINGS = 4 -- accepted pings from one player allowed within BURST_SECONDS
PingPong.BURST_SECONDS = 8
PingPong.BURST_MUTE_SECONDS = 10 -- how long a player who goes over that is ignored
PingPong.HOLD_SECONDS = 10 -- how long an unseen ping waits for the map to show it
PingPong.MAX_HELD = 8

-- Instances can make unit names and similar values secret: comparing one raises an error.
-- Forever builds may lack the function, and then nothing is secret.
function PingPong.IsSecret(value)
  local isSecret = _G.issecretvalue
  return isSecret ~= nil and isSecret(value) == true
end
