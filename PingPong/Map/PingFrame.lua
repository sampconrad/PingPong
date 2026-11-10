---------------------------------------------------------------------------------------
-- PingPong/Map/PingFrame.lua — VISUAL — the animated ping drawn on the world map
--
-- What it does: plays Blizzard's minimap ping art at a normalized spot on the map canvas.
-- Architecture: a small pool of plain frames parented to the canvas. The fade and scale copy
--   Blizzard's group member ping (0.25s, 0.65 / canvas scale), shown longer. These are not map
--   pins on purpose: AcquirePin makes a protected call that addon code can't make in combat.
-- Does not: decide what to draw or when (MapProvider.lua).
-- Related: MapProvider.lua.
---------------------------------------------------------------------------------------
local _, PingPong = ...

local PingFrame = {}
PingPong.PingFrame = PingFrame

local ART = "Interface\\minimap\\UI-Minimap-Ping-"
local BASE_SCALE = 0.65
local HOLD_TIME = 4.25
local FADE_TIME = 0.25
local ROTATE_TIME = 2
local EXPAND_TIME = 0.8
local EXPAND_SIZE = 50 -- Blizzard's MapPinPingTemplate
local EXPAND_START_SCALE = 0.01 -- effectively a point, so the circle grows from the very center
local EXPAND_END_SCALE = 1.2
local FRAME_LEVEL_ABOVE_PINS = 5000

local free = {}
local active = {}

local function AddTexture(frame, name, size, layer)
  local texture = frame:CreateTexture(nil, layer)
  texture:SetTexture(ART .. name)
  texture:SetSize(size, size)
  texture:SetPoint("CENTER")
  return texture
end

local function Release(frame)
  frame.driver:Stop()
  frame.rotate:Stop()
  frame.expand:Stop()
  frame:Hide()
  for index, candidate in ipairs(active) do
    if candidate == frame then
      table.remove(active, index)
      break
    end
  end
  free[#free + 1] = frame
end

local function CreateRotate(texture)
  local group = texture:CreateAnimationGroup()
  group:SetLooping("REPEAT")
  local spin = group:CreateAnimation("Rotation")
  spin:SetDegrees(-360)
  spin:SetDuration(ROTATE_TIME)
  return group
end

local function CreateExpand(texture)
  local group = texture:CreateAnimationGroup()
  group:SetLooping("REPEAT")
  local grow = group:CreateAnimation("Scale")
  grow:SetScaleFrom(EXPAND_START_SCALE, EXPAND_START_SCALE)
  grow:SetScaleTo(EXPAND_END_SCALE, EXPAND_END_SCALE)
  grow:SetDuration(EXPAND_TIME)
  return group
end

local function CreateDriver(frame)
  local group = frame:CreateAnimationGroup()
  local fade = group:CreateAnimation("Alpha")
  fade:SetFromAlpha(1)
  fade:SetToAlpha(0)
  fade:SetStartDelay(HOLD_TIME)
  fade:SetDuration(FADE_TIME)
  group:SetScript("OnFinished", function()
    Release(frame)
  end)
  return group
end

local function Create(canvas)
  local frame = _G.CreateFrame("Frame", nil, canvas)
  frame:SetSize(70, 70)
  frame:SetFrameLevel(canvas:GetFrameLevel() + FRAME_LEVEL_ABOVE_PINS)
  frame:Hide()
  AddTexture(frame, "Center", 32, "ARTWORK")
  frame.rotate = CreateRotate(AddTexture(frame, "Rotate", 70, "OVERLAY"))
  frame.expand = CreateExpand(AddTexture(frame, "Expand", EXPAND_SIZE, "BACKGROUND"))
  frame.driver = CreateDriver(frame)
  return frame
end

local function Layout(frame, canvas, canvasScale)
  local scale = BASE_SCALE / canvasScale
  frame:SetScale(scale)
  frame:ClearAllPoints()
  frame:SetPoint(
    "CENTER",
    canvas,
    "TOPLEFT",
    canvas:GetWidth() * frame.mapX / scale,
    -canvas:GetHeight() * frame.mapY / scale
  )
end

function PingFrame.Play(canvas, canvasScale, x, y)
  local frame = table.remove(free) or Create(canvas)
  frame.mapX, frame.mapY = x, y
  Layout(frame, canvas, canvasScale)
  active[#active + 1] = frame
  frame:Show()
  frame.driver:Play()
  frame.rotate:Play()
  frame.expand:Play()
end

-- The canvas zoomed or resized: keep running pings on their spot.
function PingFrame.LayoutAll(canvas, canvasScale)
  for _, frame in ipairs(active) do
    Layout(frame, canvas, canvasScale)
  end
end

function PingFrame.StopAll()
  for index = #active, 1, -1 do
    Release(active[index])
  end
end
