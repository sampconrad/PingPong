---------------------------------------------------------------------------------------
-- PingPong/Map/MapProvider.lua — MAP — ping clicks and ping placement
--
-- What it does: turns a double-left-click or Alt+left-click on the world map into a ping, and
--   draws pings on whatever map is shown, holding ones that can't be drawn yet.
-- Architecture: a MapCanvas data provider. The first click of a double click passes through so
--   Blizzard navigates as usual. The second is swallowed and pings the first click's map and
--   spot, so a double click on a continent drills in once and marks the spot clicked. Alt+click
--   is swallowed and pings at once, so the map stays where it is. Blizzard runs click handlers
--   through securecallfunction, so this one can't taint navigation.
-- Does not: send messages (Comms.lua) or build the visuals (PingFrame.lua, Hint.lua).
-- Related: Comms.lua, PingFrame.lua, Hint.lua, tests/spec_pingpong.lua.
---------------------------------------------------------------------------------------
local _, PingPong = ...

local Map = {}
PingPong.Map = Map

local IsSecret = PingPong.IsSecret
local PingFrame = PingPong.PingFrame

local CLICK_HANDLER_PRIORITY = 100

local held = {}
local provider
local lastClick

-- Returns the first click when this one completes a double click, otherwise nil.
function Map.RegisterClick(mapID, x, y, now, cursorX, cursorY)
  local first = lastClick
  if
    first
    and now - first.time <= PingPong.DOUBLE_CLICK_WINDOW
    and math.abs(cursorX - first.cursorX) <= PingPong.DOUBLE_CLICK_TOLERANCE
    and math.abs(cursorY - first.cursorY) <= PingPong.DOUBLE_CLICK_TOLERANCE
  then
    lastClick = nil
    return first
  end
  lastClick = { mapID = mapID, x = x, y = y, time = now, cursorX = cursorX, cursorY = cursorY }
  return nil
end

-- Where a ping lands on shownMapID as normalized x, y, or nil when it isn't on that map.
function Map.Resolve(mapID, x, y, shownMapID)
  if mapID == shownMapID then
    return x, y
  end
  local continentID, worldPosition = _G.C_Map.GetWorldPosFromMapPos(mapID, _G.CreateVector2D(x, y))
  if IsSecret(continentID) or not continentID or not worldPosition then
    return nil
  end
  local _, position = _G.C_Map.GetMapPosFromWorldPos(continentID, worldPosition, shownMapID)
  if not position then
    return nil
  end
  local shownX, shownY = position:GetXY()
  if IsSecret(shownX) or IsSecret(shownY) or not shownX or not shownY then
    return nil
  end
  if shownX < 0 or shownX > 1 or shownY < 0 or shownY > 1 then
    return nil
  end
  return shownX, shownY
end

local function ShownMap()
  local map = provider and provider:GetMap()
  if map and map:IsShown() then
    return map
  end
  return nil
end

local function DrawOn(map, ping)
  local x, y = Map.Resolve(ping.mapID, ping.x, ping.y, map:GetMapID())
  if not x then
    return false
  end
  PingFrame.Play(map:GetCanvas(), map:GetCanvasScale(), x, y)
  return true
end

local function DrawHeld(map)
  local now = _G.GetTime()
  for index = #held, 1, -1 do
    local ping = held[index]
    if now >= ping.expires or DrawOn(map, ping) then
      table.remove(held, index)
    end
  end
end

-- Draws the ping now if it falls on the shown map, otherwise holds it. Returns true if drawn.
function Map.Add(mapID, x, y)
  local ping = { mapID = mapID, x = x, y = y, expires = _G.GetTime() + PingPong.HOLD_SECONDS }
  local map = ShownMap()
  if map and DrawOn(map, ping) then
    return true
  end
  held[#held + 1] = ping
  if #held > PingPong.MAX_HELD then
    table.remove(held, 1)
  end
  return false
end

function Map.IsOpen()
  return ShownMap() ~= nil
end

function Map.HandleCanvasClick(map, button, x, y)
  if button ~= "LeftButton" then
    return false
  end
  if _G.IsAltKeyDown() then
    lastClick = nil
    PingPong.Comms.SendPing(map:GetMapID(), x, y)
    return true
  end
  local cursorX, cursorY = _G.GetCursorPosition()
  local first = Map.RegisterClick(map:GetMapID(), x, y, _G.GetTime(), cursorX, cursorY)
  if not first then
    return false
  end
  PingPong.Comms.SendPing(first.mapID, first.x, first.y)
  return true
end

local function Relayout(self)
  local map = self:GetMap()
  if map then
    PingFrame.LayoutAll(map:GetCanvas(), map:GetCanvasScale())
  end
end

-- Built on demand: Blizzard's map code may load after this file.
local function CreateProvider()
  local Base = _G.MapCanvasDataProviderMixin
  local Provider = _G.CreateFromMixins(Base)

  function Provider:OnAdded(map)
    Base.OnAdded(self, map)
    map:AddCanvasClickHandler(Map.HandleCanvasClick, CLICK_HANDLER_PRIORITY)
    PingPong.Hint.Attach(map)
  end

  function Provider:RefreshAllData()
    local map = ShownMap()
    if map then
      DrawHeld(map)
    end
  end

  function Provider:OnMapChanged()
    PingFrame.StopAll()
    self:RefreshAllData()
  end

  function Provider:OnHide()
    PingFrame.StopAll()
  end

  Provider.OnCanvasScaleChanged = Relayout
  Provider.OnCanvasSizeChanged = Relayout
  return Provider
end

local function Install()
  local map = _G.WorldMapFrame
  if not (map and map.AddDataProvider and _G.MapCanvasDataProviderMixin) then
    return false
  end
  provider = CreateProvider()
  map:AddDataProvider(provider)
  return true
end

if not Install() then
  -- The world map is not loaded yet: wait for it.
  local frame = _G.CreateFrame("Frame")
  frame:RegisterEvent("PLAYER_LOGIN")
  frame:RegisterEvent("ADDON_LOADED")
  frame:SetScript("OnEvent", function(self)
    if Install() then
      self:UnregisterAllEvents()
    end
  end)
end
