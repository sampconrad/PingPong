---------------------------------------------------------------------------------------
-- PingPong/Core/Codec.lua — COMMS — the addon message format
--
-- What it does: turns a ping into message text and back, rejecting anything malformed.
-- Architecture: pure functions. Format is "1:<uiMapID>:<x>:<y>" with x and y as whole numbers
--   from 0 to 10000. Whole numbers keep the text free of locale decimal separators.
-- Does not: send or receive anything (Comms.lua), or check that the map exists.
-- Related: Comms.lua, tests/spec_codec.lua.
---------------------------------------------------------------------------------------
local _, PingPong = ...

local Codec = {}
PingPong.Codec = Codec

local VERSION = "1"
local SCALE = 10000
local MAX_LENGTH = 32

local function ToWire(value)
  return math.floor(value * SCALE + 0.5)
end

function Codec.Encode(mapID, x, y)
  if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
    return nil
  end
  if mapID < 1 or x < 0 or x > 1 or y < 0 or y > 1 then
    return nil
  end
  return ("%s:%d:%d:%d"):format(VERSION, mapID, ToWire(x), ToWire(y))
end

-- Returns mapID, x, y, or nil when the text is not a valid ping of a version we understand.
function Codec.Decode(text)
  if type(text) ~= "string" or #text > MAX_LENGTH then
    return nil
  end
  local version, mapText, xText, yText = text:match("^(%d+):(%d+):(%d+):(%d+)$")
  if version ~= VERSION then
    return nil
  end
  local mapID, x, y = tonumber(mapText), tonumber(xText), tonumber(yText)
  if mapID < 1 or x > SCALE or y > SCALE then
    return nil
  end
  return mapID, x / SCALE, y / SCALE
end
