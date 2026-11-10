---------------------------------------------------------------------------------------
-- PingPong/Core/Comms.lua — COMMS — sending and receiving pings between group members
--
-- What it does: shows the local ping and sends it to the group, and turns incoming messages
--   into pings with the minimap's sound, plus a chat line when the ping can't be seen yet. The
--   zone in that line is a link that opens the map there.
-- Architecture: addon messages on the group's channel. Blizzard blocks them during an active
--   encounter, Mythic+ key or PvP match: the sender still sees the ping and gets a short error.
--   The link uses C_Map.OpenWorldMap, which doesn't taint the map but is blocked in combat.
--   Receivers enforce the spam limits, so a modified client can't get past them. The sender
--   applies the same burst limit to itself, so its own pings stop when everyone else's do.
-- Does not: draw (MapProvider.lua, PingFrame.lua) or parse the format itself (Codec.lua).
-- Related: Codec.lua, MapProvider.lua, tests/spec_pingpong.lua.
---------------------------------------------------------------------------------------
local _, PingPong = ...

local Comms = {}
PingPong.Comms = Comms

local Codec = PingPong.Codec
local Map = PingPong.Map
local IsSecret = PingPong.IsSecret

local GROUP_CHANNELS = { PARTY = true, RAID = true, INSTANCE_CHAT = true }
local LOCKDOWN_TEXT = "PingPong: pings can't be shared right now."
local COMBAT_TEXT = "PingPong: the map can't be opened from chat during combat."
local BURST_TEXT = "Too many pings, wait a few seconds"

local LINK_PREFIX = "addon:" .. PingPong.PREFIX .. ":"
local LINK_FORMAT = "|cff71d5ff|H" .. LINK_PREFIX .. "%d|h[%s]|h|r"
local LINK_PATTERN = "^" .. LINK_PREFIX .. "(%d+)$"

local ECHO_SECONDS = 10
local TEST_SENDER = "Test-Realm"

local lastSend
local lastBySender = {}
local burstBySender = {}
local pendingEchoes = {} -- [message text] = time the echo stops being expected

local function NewBurst()
  return { mutedUntil = 0, recent = {} }
end

local ownBurst = NewBurst()

-- Counts one ping against a player's burst and says whether it goes through. Going over the
-- limit ignores that player for a while, and pings during that time don't extend it.
local function PassesBurstLimit(burst, now)
  if now < burst.mutedUntil then
    return false
  end
  local recent = burst.recent
  while recent[1] and now - recent[1] >= PingPong.BURST_SECONDS do
    table.remove(recent, 1)
  end
  if #recent >= PingPong.BURST_PINGS then
    burst.mutedUntil = now + PingPong.BURST_MUTE_SECONDS
    burst.recent = {}
    return false
  end
  recent[#recent + 1] = now
  return true
end

local function PlayPingSound()
  _G.PlaySound(_G.SOUNDKIT.MAP_PING)
end

local function GroupChannel()
  if _G.IsInGroup(_G.LE_PARTY_CATEGORY_INSTANCE) then
    return "INSTANCE_CHAT"
  end
  if _G.IsInRaid() then
    return "RAID"
  end
  if _G.IsInGroup() then
    return "PARTY"
  end
  return nil
end

local function ShowLockdownError()
  _G.UIErrorsFrame:AddMessage(LOCKDOWN_TEXT, 1, 0.82, 0)
end

local function InLockdown()
  local inLockdown = _G.C_ChatInfo.InChatMessagingLockdown
  return inLockdown ~= nil and inLockdown() == true
end

local function Broadcast(mapID, x, y)
  local channel = GroupChannel()
  local text = channel and Codec.Encode(mapID, x, y)
  if not text then
    return
  end
  if InLockdown() then
    ShowLockdownError()
    return
  end
  local result = _G.C_ChatInfo.SendAddonMessage(PingPong.PREFIX, text, channel)
  local results = _G.Enum and _G.Enum.SendAddonMessageResult
  if results and result == results.AddOnMessageLockdown then
    ShowLockdownError()
    return
  end
  pendingEchoes[text] = _G.GetTime() + ECHO_SECONDS
end

function Comms.SendPing(mapID, x, y)
  local now = _G.GetTime()
  if lastSend and now - lastSend < PingPong.SEND_COOLDOWN then
    return
  end
  lastSend = now
  if not PassesBurstLimit(ownBurst, now) then
    PingPong.Hint.ShowMessage(BURST_TEXT)
    return
  end
  Map.Add(mapID, x, y)
  PlayPingSound()
  Broadcast(mapID, x, y)
end

-- Addon messages come back to their sender. They are matched by text because the player's own
-- name can be secret in instances.
local function ConsumeOwnEcho(text)
  local expires = pendingEchoes[text]
  if not expires then
    return false
  end
  pendingEchoes[text] = nil
  return _G.GetTime() < expires
end

local function PassesRateLimit(sender)
  local now = _G.GetTime()
  local last = lastBySender[sender]
  if last and now - last < PingPong.SENDER_COOLDOWN then
    return false
  end
  lastBySender[sender] = now
  burstBySender[sender] = burstBySender[sender] or NewBurst()
  return PassesBurstLimit(burstBySender[sender], now)
end

local function PrintUnseenPing(sender, mapID, shownName)
  local info = _G.C_Map.GetMapInfo(mapID)
  local name = shownName or _G.Ambiguate(sender, "short")
  local zone = info and info.name and LINK_FORMAT:format(mapID, info.name)
  local line = zone and ("%s pinged the map in %s."):format(name, zone)
    or ("%s pinged the map."):format(name)
  _G.DEFAULT_CHAT_FRAME:AddMessage("|cffffd200PingPong:|r " .. line)
end

function Comms.HandleLinkClick(link)
  local mapID = type(link) == "string" and tonumber(link:match(LINK_PATTERN))
  if not mapID then
    return
  end
  if _G.InCombatLockdown() then
    _G.UIErrorsFrame:AddMessage(COMBAT_TEXT, 1, 0.82, 0)
    return
  end
  _G.C_Map.OpenWorldMap(mapID)
end

-- shownName is only for the solo test: it replaces the sender's name in the chat line.
function Comms.HandleMessage(prefix, text, channel, sender, shownName)
  if IsSecret(prefix) or IsSecret(text) or IsSecret(channel) or IsSecret(sender) then
    return
  end
  if prefix ~= PingPong.PREFIX or not GROUP_CHANNELS[channel] or type(sender) ~= "string" then
    return
  end
  if ConsumeOwnEcho(text) then
    return
  end
  local mapID, x, y = Codec.Decode(text)
  if not mapID or not PassesRateLimit(sender) then
    return
  end
  local drawn = Map.Add(mapID, x, y)
  PlayPingSound()
  if not drawn then
    PrintUnseenPing(sender, mapID, shownName)
  end
end

-- UnitName's second value is the surname on Forever. On Retail it's the realm, which is nil for
-- the player's own character.
local function FullPlayerName()
  local name, surname = _G.UnitName("player")
  if IsSecret(surname) or not surname or surname == "" then
    return name
  end
  return name .. " " .. surname
end

-- The player's name in their class color. Secret or unknown class data leaves it plain.
local function ClassColoredPlayerName()
  local name = FullPlayerName()
  local _, classFile = _G.UnitClass("player")
  local color = not IsSecret(classFile) and classFile and _G.RAID_CLASS_COLORS[classFile]
  if not color then
    return name
  end
  return ("|c%s%s|r"):format(color.colorStr, name)
end

-- Solo testing: /run PingPongTest(mapID, x, y) fakes a ping from another player through the real
-- receive path, shown under your own name. Every argument is optional: the default is the center
-- of your current map.
function _G.PingPongTest(mapID, x, y)
  local text = Codec.Encode(mapID or _G.C_Map.GetBestMapForUnit("player"), x or 0.5, y or 0.5)
  if not text then
    print("PingPong: that isn't a valid test ping (x and y go from 0 to 1).")
    return
  end
  Comms.HandleMessage(PingPong.PREFIX, text, "PARTY", TEST_SENDER, ClassColoredPlayerName())
end

_G.C_ChatInfo.RegisterAddonMessagePrefix(PingPong.PREFIX)

local frame = _G.CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:SetScript("OnEvent", function(_, _, prefix, text, channel, sender)
  Comms.HandleMessage(prefix, text, channel, sender)
end)

_G.EventRegistry:RegisterCallback("SetItemRef", function(_, link)
  Comms.HandleLinkClick(link)
end, Comms)
