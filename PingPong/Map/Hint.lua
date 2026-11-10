---------------------------------------------------------------------------------------
-- PingPong/Map/Hint.lua — VISUAL — the Alt + Left Click hint on the world map
--
-- What it does: shows the addon's icon to the right of the map's tracking pin button, on the
--   panel art Blizzard's menus use. Hovering it slides out a wider panel with the Alt key and
--   left click art and a short text. While collapsed, a glowing copy of the icon grows and
--   fades every few seconds to draw the eye. It can also slide out by itself to show a short
--   message next to the icon for a few seconds.
-- Architecture: a plain frame parented to the world map so it shows and hides with it. Only
--   mouse motion is enabled, so clicks still reach the map. The art is one stretched texture
--   whose border flickers if it is resized every frame, and two panels showing at once double
--   its shadow. So the wide panel and details keep a fixed size inside a clipping frame whose
--   width animates, and it replaces the narrow panel with exactly one shown. Retail keeps the
--   button in an unnamed local, so it is found in the map's overlay list by its mixin. If a
--   game rule removed the button, the hint starts from the map's top right corner instead.
-- Does not: handle clicks (MapProvider.lua).
-- Related: MapProvider.lua, tests/spec_pingpong.lua.
---------------------------------------------------------------------------------------
local _, PingPong = ...

local Hint = {}
PingPong.Hint = Hint

local ART = "Interface\\AddOns\\PingPong\\Assets\\"
local TEXT = "on the map to ping a location for your group"
local ROW_HEIGHT = 32 -- the pin button's height
local ICON_SIZE = 18
local LOGO_GAP = 5
-- Small or negative because the mouse art has wide transparent sides.
local CLICK_GAP = -3
local TEXT_GAP = 1
local BUTTON_GAP = 4
local CORNER_INSET = 8
local CONTENT_INSET = 5
local PANEL_ATLAS = "common-dropdown-bg" -- Blizzard's context menu panel
local PANEL_ALPHA = 0.925
-- How far the art reaches past the row, measured in game. The visible panel sits high in the
-- texture and its shadow differs per side, so these center it on the row and even the padding.
local PANEL_OUTSET_LEFT = 7
local PANEL_OUTSET_RIGHT = 11
local PANEL_OUTSET_TOP = 1
local PANEL_OUTSET_BOTTOM = 5
local COLLAPSED_WIDTH = CONTENT_INSET + ICON_SIZE
local HOVER_PADDING_RIGHT = PANEL_OUTSET_RIGHT -- the frame ends before the panel does
local EXPAND_SECONDS = 0.15
local MESSAGE_SECONDS = 3
local PULSE_PEAK_ALPHA = 0.9
local PULSE_END_SCALE = 1.6 -- still inside the collapsed panel
local PULSE_SECONDS = 0.8
local PULSE_FADE_IN_SECONDS = 0.25
local PULSE_PAUSE_SECONDS = 4

-- One animation step: moves progress toward target (0 collapsed, 1 expanded).
function Hint.Advance(progress, target, elapsed)
  local step = elapsed / EXPAND_SECONDS
  if target > progress then
    return math.min(target, progress + step)
  end
  return math.max(target, progress - step)
end

function Hint.FindPinButton(map)
  local mixin = _G.WorldMapTrackingPinButtonMixin
  if not mixin or not map.overlayFrames then
    return nil
  end
  for _, frame in ipairs(map.overlayFrames) do
    if frame.Refresh == mixin.Refresh then
      return frame
    end
  end
  return nil
end

local function AddIcon(frame, file)
  local texture = frame:CreateTexture(nil, "ARTWORK")
  texture:SetTexture(ART .. file)
  texture:SetSize(ICON_SIZE, ICON_SIZE)
  return texture
end

local function PlaceRightOf(region, neighbor, gap)
  region:SetPoint("LEFT", neighbor, "RIGHT", gap, 0)
end

local function PanelWidth(rowWidth)
  return PANEL_OUTSET_LEFT + rowWidth + PANEL_OUTSET_RIGHT
end

local function AnchorToPanelArea(region, frame)
  region:SetPoint("TOPLEFT", frame, "TOPLEFT", -PANEL_OUTSET_LEFT, PANEL_OUTSET_TOP)
  region:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -PANEL_OUTSET_LEFT, -PANEL_OUTSET_BOTTOM)
end

local function AddPanel(parent, frame)
  local panel = parent:CreateTexture(nil, "BACKGROUND")
  panel:SetAtlas(PANEL_ATLAS)
  panel:SetAlpha(PANEL_ALPHA)
  AnchorToPanelArea(panel, frame)
  return panel
end

-- The clipping frame, and inside it the frame that holds what the slide reveals.
local function AddReveal(frame)
  local clip = _G.CreateFrame("Frame", nil, frame)
  clip:SetClipsChildren(true)
  AnchorToPanelArea(clip, frame)

  local content = _G.CreateFrame("Frame", nil, clip)
  content:SetPoint("TOPLEFT", frame, "TOPLEFT")
  content:SetSize(1, 1)
  return clip, content
end

-- A looping additive copy of the logo, over it. The resting alpha is 0, so it only shows while
-- playing. It fades in while it grows, because appearing at full brightness looks like a jolt.
local function AddPulse(parent, logo)
  local glow = AddIcon(parent, "logo")
  glow:SetDrawLayer("ARTWORK", 1)
  glow:SetBlendMode("ADD")
  glow:SetPoint("CENTER", logo, "CENTER")
  glow:SetAlpha(0)

  local group = glow:CreateAnimationGroup()
  group:SetLooping("REPEAT")

  local grow = group:CreateAnimation("Scale")
  grow:SetScaleFrom(1, 1)
  grow:SetScaleTo(PULSE_END_SCALE, PULSE_END_SCALE)
  grow:SetDuration(PULSE_SECONDS)
  grow:SetSmoothing("IN_OUT")

  local fadeIn = group:CreateAnimation("Alpha")
  fadeIn:SetFromAlpha(0)
  fadeIn:SetToAlpha(PULSE_PEAK_ALPHA)
  fadeIn:SetDuration(PULSE_FADE_IN_SECONDS)
  fadeIn:SetSmoothing("IN_OUT")

  local fadeOut = group:CreateAnimation("Alpha")
  fadeOut:SetFromAlpha(PULSE_PEAK_ALPHA)
  fadeOut:SetToAlpha(0)
  fadeOut:SetStartDelay(PULSE_FADE_IN_SECONDS)
  fadeOut:SetDuration(PULSE_SECONDS - PULSE_FADE_IN_SECONDS)
  fadeOut:SetEndDelay(PULSE_PAUSE_SECONDS)
  return group
end

local function BuildRow(frame)
  local clip, content = AddReveal(frame)

  -- Above the clipping frame and its content, so the wide panel doesn't cover the logo.
  local logoLayer = _G.CreateFrame("Frame", nil, frame)
  logoLayer:SetAllPoints(frame)
  logoLayer:SetFrameLevel(clip:GetFrameLevel() + 2)

  local logo = AddIcon(logoLayer, "logo")
  local alt = AddIcon(content, "key-alt")
  local click = AddIcon(content, "npe_leftclick")
  local label = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  label:SetText(TEXT)
  local message = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  message:Hide()

  logo:SetPoint("LEFT", frame, "LEFT", CONTENT_INSET, 0)
  PlaceRightOf(alt, logo, LOGO_GAP)
  PlaceRightOf(click, alt, CLICK_GAP)
  PlaceRightOf(label, click, TEXT_GAP)
  PlaceRightOf(message, logo, LOGO_GAP)

  local narrowPanel = AddPanel(frame, frame)
  narrowPanel:SetWidth(PanelWidth(COLLAPSED_WIDTH))

  return {
    clip = clip,
    details = { alt, click, label },
    label = label,
    message = message,
    narrowPanel = narrowPanel,
    pulse = AddPulse(logoLayer, logo),
    widePanel = AddPanel(content, frame),
  }
end

local function ExpandedWidth(label)
  local icons = LOGO_GAP + ICON_SIZE + CLICK_GAP + ICON_SIZE + TEXT_GAP
  return COLLAPSED_WIDTH + icons + label:GetStringWidth()
end

-- Picks what the slide reveals: the shortcut or the message. Returns the width it needs.
local function ShowContent(row, isMessage)
  for _, region in ipairs(row.details) do
    region:SetAlpha(isMessage and 0 or 1)
  end
  if isMessage then
    row.message:Show()
    return COLLAPSED_WIDTH + LOGO_GAP + row.message:GetStringWidth()
  end
  row.message:Hide()
  return ExpandedWidth(row.label)
end

local function AddHover(frame, row)
  local progress, target, expandedWidth = 0, 0, COLLAPSED_WIDTH
  local hovered, messageLeft = false, 0
  local Retarget

  local function Apply()
    -- The reveal shows from the start of expanding until it has fully slid back.
    local sliding = target == 1 or progress > 0
    row.narrowPanel:SetShown(not sliding)
    row.clip:SetShown(sliding)
    row.clip:SetWidth(PanelWidth(COLLAPSED_WIDTH + (expandedWidth - COLLAPSED_WIDTH) * progress))
  end

  local function OnUpdate(_, elapsed)
    progress = Hint.Advance(progress, target, elapsed)
    Apply()
    if messageLeft > 0 then
      messageLeft = messageLeft - elapsed
      if messageLeft <= 0 then
        messageLeft = 0
        Retarget()
      end
    elseif progress == target then
      frame:SetScript("OnUpdate", nil)
      if progress == 0 then
        row.pulse:Play()
      end
    end
  end

  local function AnimateTo(value)
    target = value
    Apply()
    frame:SetScript("OnUpdate", OnUpdate)
  end

  -- Collapsing leaves the content alone, so a message doesn't change as it slides back.
  Retarget = function()
    local showMessage = messageLeft > 0
    if showMessage or hovered then
      row.pulse:Stop()
      expandedWidth = ShowContent(row, showMessage)
      row.widePanel:SetWidth(PanelWidth(expandedWidth))
      frame:SetWidth(expandedWidth)
      AnimateTo(1)
    else
      frame:SetWidth(COLLAPSED_WIDTH)
      AnimateTo(0)
    end
  end

  function Hint.ShowMessage(text)
    row.message:SetText(text)
    messageLeft = MESSAGE_SECONDS
    Retarget()
  end

  frame:SetMouseMotionEnabled(true)
  frame:SetHitRectInsets(0, -HOVER_PADDING_RIGHT, 0, 0)
  frame:SetScript("OnShow", function()
    if progress == 0 and target == 0 then
      row.pulse:Play()
    end
  end)
  -- A message doesn't outlive the map: it would otherwise slide back when the map reopens.
  frame:SetScript("OnHide", function()
    if messageLeft > 0 then
      messageLeft, progress, target, hovered = 0, 0, 0, false
      frame:SetWidth(COLLAPSED_WIDTH)
      frame:SetScript("OnUpdate", nil)
      Apply()
    end
  end)
  frame:SetScript("OnEnter", function()
    hovered = true
    Retarget()
  end)
  frame:SetScript("OnLeave", function()
    hovered = false
    Retarget()
  end)
  Apply()
  row.pulse:Play()
end

function Hint.Attach(map)
  local frame = _G.CreateFrame("Frame", nil, map)
  frame:SetFrameStrata("HIGH")
  frame:SetSize(COLLAPSED_WIDTH, ROW_HEIGHT)
  local button = Hint.FindPinButton(map)
  if button then
    frame:SetPoint("LEFT", button, "RIGHT", BUTTON_GAP, 0)
  else
    frame:SetPoint("TOPLEFT", map:GetCanvasContainer(), "TOPRIGHT", BUTTON_GAP, -CORNER_INSET)
  end
  AddHover(frame, BuildRow(frame))
end
