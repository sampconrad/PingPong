-- tests/spec_pingpong.lua: double-click detection, ping placement and incoming message rules.

local Stub = require("wowstub")

local function CheckDoubleClick(check, Map)
  local first = Map.RegisterClick(10, 0.2, 0.3, 100, 500, 500)
  check("first click is not a double click", first, nil)
  local double = Map.RegisterClick(20, 0.9, 0.9, 100.2, 505, 495)
  check("second click returns the first map", double and double.mapID, 10)
  check("second click returns the first x", double and double.x, 0.2)
  check("a double click resets", Map.RegisterClick(10, 0, 0, 100.3, 500, 500), nil)

  check("too slow: first", Map.RegisterClick(10, 0, 0, 200, 500, 500), nil)
  check("too slow: second", Map.RegisterClick(10, 0, 0, 200.5, 500, 500), nil)

  check("moved: first", Map.RegisterClick(10, 0, 0, 300, 500, 500), nil)
  check("moved: second", Map.RegisterClick(10, 0, 0, 300.1, 600, 500), nil)
end

local function CheckResolve(check, Map, env)
  env.CreateVector2D = function(x, y)
    return { x = x, y = y }
  end
  local shown = { GetXY = nil }
  env.C_Map = {
    GetWorldPosFromMapPos = function(mapID, position)
      if mapID == 999 then
        return nil, nil
      end
      return 1, position
    end,
    GetMapPosFromWorldPos = function(_, world, mapID)
      if mapID == 998 then
        return mapID, nil
      end
      shown.GetXY = function()
        return world.x * 2, world.y * 2
      end
      return mapID, shown
    end,
  }

  local sameX, sameY = Map.Resolve(5, 0.1, 0.2, 5)
  check("same map x", sameX, 0.1)
  check("same map y", sameY, 0.2)

  local otherX, otherY = Map.Resolve(5, 0.25, 0.4, 6)
  check("translated x", otherX, 0.5)
  check("translated y", otherY, 0.8)

  check("off the shown map", Map.Resolve(5, 0.75, 0.1, 6), nil)
  check("no world position", Map.Resolve(999, 0.1, 0.1, 6), nil)
  check("no position on the shown map", Map.Resolve(5, 0.1, 0.1, 998), nil)

  Stub.secrets[1] = true
  check("secret continent", Map.Resolve(5, 0.1, 0.1, 6), nil)
  Stub.secrets[1] = nil
end

local function CheckMessages(check, PingPong, env)
  local now, added, sounds, lines = 1000, {}, 0, {}
  local drawn = false
  env.GetTime = function()
    return now
  end
  env.PlaySound = function()
    sounds = sounds + 1
  end
  env.Ambiguate = function(name)
    return (name:gsub("%-.*", ""))
  end
  env.DEFAULT_CHAT_FRAME = {
    AddMessage = function(_, line)
      lines[#lines + 1] = line
    end,
  }
  env.C_Map.GetMapInfo = function()
    return { name = "Dornogal" }
  end
  PingPong.Map.Add = function(mapID, x, y)
    added[#added + 1] = { mapID = mapID, x = x, y = y }
    return drawn
  end

  local Handle = PingPong.Comms.HandleMessage
  local TEXT = "1:2248:5000:2500"

  Handle("Other", TEXT, "PARTY", "Friend-Realm")
  check("wrong prefix ignored", #added, 0)
  Handle("PingPong", TEXT, "WHISPER", "Friend-Realm")
  check("wrong channel ignored", #added, 0)
  Handle("PingPong", "nonsense", "PARTY", "Friend-Realm")
  check("bad text ignored", #added, 0)
  check("nothing played yet", sounds, 0)

  Handle("PingPong", TEXT, "PARTY", "Friend-Realm")
  check("valid ping added", #added, 1)
  check("valid ping map", added[1].mapID, 2248)
  check("sound played", sounds, 1)
  check(
    "unseen ping prints a zone link",
    lines[1],
    "|cffffd200PingPong:|r Friend pinged the map in |cff71d5ff|Haddon:PingPong:2248|h[Dornogal]|h|r."
  )

  now = now + 0.1
  Handle("PingPong", TEXT, "RAID", "Friend-Realm")
  check("rate limited", #added, 1)
  Handle("PingPong", TEXT, "RAID", "Second-Realm")
  check("other sender not limited", #added, 2)

  now = now + 1
  drawn = true
  Handle("PingPong", TEXT, "INSTANCE_CHAT", "Friend-Realm")
  check("after the cooldown", #added, 3)
  check("a drawn ping does not print", #lines, 2)

  now = now + 1
  Stub.secrets["Friend-Realm"] = true
  Handle("PingPong", TEXT, "PARTY", "Friend-Realm")
  check("secret sender dropped", #added, 3)
  Stub.secrets["Friend-Realm"] = nil

  local sent = {}
  env.IsInRaid = function()
    return false
  end
  env.C_ChatInfo = {
    InChatMessagingLockdown = function()
      return false
    end,
    SendAddonMessage = function(_, text, channel)
      sent[#sent + 1] = { text = text, channel = channel }
      return 0
    end,
  }
  env.IsInGroup = function(category)
    return category == nil
  end

  PingPong.Comms.SendPing(2248, 0.5, 0.25)
  check("sending draws locally", #added, 4)
  check("sending goes to the party", sent[1] and sent[1].channel, "PARTY")
  check("sending encodes the ping", sent[1] and sent[1].text, TEXT)
  PingPong.Comms.SendPing(2248, 0.5, 0.25)
  check("send cooldown", #sent, 1)

  now = now + 1
  Handle("PingPong", TEXT, "PARTY", "Me-Realm")
  check("own echo ignored", #added, 4)
  Handle("PingPong", TEXT, "PARTY", "Friend-Realm")
  check("same text from someone else is a ping", #added, 5)

  now = now + 1
  env.PingPongTest(2248, 0.25, 0.75)
  check("test ping is received", #added, 6)
  check("test ping map", added[6].mapID, 2248)
  check("test ping x", added[6].x, 0.25)
  check("test ping y", added[6].y, 0.75)

  now = now + 1
  env.C_Map.GetBestMapForUnit = function()
    return 7
  end
  env.PingPongTest()
  check("test ping defaults to the current map", added[7] and added[7].mapID, 7)
  check("test ping defaults to the center", added[7] and added[7].x, 0.5)

  now = now + 1
  env.PingPongTest(7, 2, 0.5)
  check("invalid test ping is rejected", #added, 7)

  now = now + 1
  drawn = false
  env.UnitName = function()
    return "Sam"
  end
  env.UnitClass = function()
    return "Paladin", "PALADIN"
  end
  env.RAID_CLASS_COLORS = { PALADIN = { colorStr = "fff58cba" } }
  local ZONE_END = " pinged the map in |cff71d5ff|Haddon:PingPong:2248|h[Dornogal]|h|r."
  env.PingPongTest(2248, 0.25, 0.75)
  check(
    "test line uses the class colored name",
    lines[#lines],
    "|cffffd200PingPong:|r |cfff58cbaSam|r" .. ZONE_END
  )

  now = now + 1
  Stub.secrets["PALADIN"] = true
  env.PingPongTest(2248, 0.25, 0.75)
  Stub.secrets["PALADIN"] = nil
  check(
    "secret class leaves the name plain",
    lines[#lines],
    "|cffffd200PingPong:|r Sam" .. ZONE_END
  )

  now = now + 30
  env.UnitName = function()
    return "Sam", "Stone"
  end
  env.PingPongTest(2248, 0.25, 0.75)
  check(
    "test line includes a Forever surname",
    lines[#lines],
    "|cffffd200PingPong:|r |cfff58cbaSam Stone|r" .. ZONE_END
  )

  now = now + 1
  Stub.secrets["Stone"] = true
  env.PingPongTest(2248, 0.25, 0.75)
  Stub.secrets["Stone"] = nil
  check(
    "secret surname is left out",
    lines[#lines],
    "|cffffd200PingPong:|r |cfff58cbaSam|r" .. ZONE_END
  )
end

local function CheckBurstLimit(check, PingPong, env)
  local now, added, sent, messages = 9000, 0, 0, 0
  env.GetTime = function()
    return now
  end
  local RealShowMessage = PingPong.Hint.ShowMessage
  PingPong.Hint.ShowMessage = function()
    messages = messages + 1
  end
  env.C_ChatInfo.SendAddonMessage = function()
    sent = sent + 1
    return 0
  end
  PingPong.Map.Add = function()
    added = added + 1
    return true
  end

  local TEXT = "1:2248:5000:2500"
  local function Receive(sender)
    PingPong.Comms.HandleMessage("PingPong", TEXT, "PARTY", sender)
  end

  for _ = 1, PingPong.BURST_PINGS do
    Receive("Spammer-Realm")
    now = now + 1
  end
  check("a burst up to the limit is accepted", added, PingPong.BURST_PINGS)
  Receive("Spammer-Realm")
  check("going over the limit is ignored", added, PingPong.BURST_PINGS)
  now = now + 1
  Receive("Spammer-Realm")
  check("still ignored afterwards", added, PingPong.BURST_PINGS)
  Receive("Friend-Realm")
  check("other players are not affected", added, PingPong.BURST_PINGS + 1)
  now = now + PingPong.BURST_MUTE_SECONDS - 1
  Receive("Spammer-Realm")
  check("pings work again after the wait", added, PingPong.BURST_PINGS + 2)

  now, added = 9500, 0
  local pace = PingPong.BURST_SECONDS / PingPong.BURST_PINGS + 0.1
  for _ = 1, PingPong.BURST_PINGS * 3 do
    Receive("Steady-Realm")
    now = now + pace
  end
  check("a steady pace is never limited", added, PingPong.BURST_PINGS * 3)

  now, added = 10000, 0
  for _ = 1, PingPong.BURST_PINGS do
    PingPong.Comms.SendPing(2248, 0.5, 0.25)
    now = now + 1
  end
  check("own burst is sent", sent, PingPong.BURST_PINGS)
  check("own burst shows no message", messages, 0)
  PingPong.Comms.SendPing(2248, 0.5, 0.25)
  check("own ping over the limit is not sent", sent, PingPong.BURST_PINGS)
  check("own ping over the limit is not drawn", added, PingPong.BURST_PINGS)
  check("own ping over the limit shows a message", messages, 1)
  now = now + PingPong.BURST_MUTE_SECONDS
  PingPong.Comms.SendPing(2248, 0.5, 0.25)
  check("own pings work again after the wait", sent, PingPong.BURST_PINGS + 1)
  PingPong.Hint.ShowMessage = RealShowMessage
end

local function CheckLinkClicks(check, PingPong, env)
  local opened, errors, inCombat = {}, 0, false
  env.C_Map.OpenWorldMap = function(mapID)
    opened[#opened + 1] = mapID
  end
  env.InCombatLockdown = function()
    return inCombat
  end
  env.UIErrorsFrame = {
    AddMessage = function()
      errors = errors + 1
    end,
  }

  local Click = PingPong.Comms.HandleLinkClick
  Click("addon:PingPong:2248")
  check("link opens the zone", opened[1], 2248)

  Click("addon:SomeOtherAddon:2248")
  Click("addon:PingPong:nonsense")
  Click("item:2248")
  Click(nil)
  check("other links are ignored", #opened, 1)
  check("other links show no error", errors, 0)

  inCombat = true
  Click("addon:PingPong:2248")
  check("combat does not open the map", #opened, 1)
  check("combat shows an error", errors, 1)
end

local function CheckCanvasClicks(check, PingPong, env)
  local now, sent, altDown = 5000, {}, false
  env.GetTime = function()
    return now
  end
  env.GetCursorPosition = function()
    return 500, 500
  end
  env.IsAltKeyDown = function()
    return altDown
  end
  PingPong.Comms.SendPing = function(mapID, x, y)
    sent[#sent + 1] = { mapID = mapID, x = x, y = y }
  end
  local map = {
    GetMapID = function()
      return 10
    end,
  }
  local Click = PingPong.Map.HandleCanvasClick

  altDown = true
  check("alt click is swallowed", Click(map, "LeftButton", 0.2, 0.3), true)
  check("alt click pings at once", #sent, 1)
  check("alt click pings the shown map", sent[1] and sent[1].mapID, 10)
  check("alt click pings the spot", sent[1] and sent[1].x, 0.2)
  check("alt right click passes through", Click(map, "RightButton", 0.2, 0.3), false)
  check("alt right click does not ping", #sent, 1)

  altDown = false
  now = now + 1
  check("plain first click passes through", Click(map, "LeftButton", 0.4, 0.5), false)
  check("plain first click does not ping", #sent, 1)
  now = now + 0.1
  altDown = true
  Click(map, "LeftButton", 0.6, 0.7)
  check("alt click during a double click pings", #sent, 2)
  altDown = false
  now = now + 0.1
  check("alt click clears the waiting first click", Click(map, "LeftButton", 0.4, 0.5), false)
  check("no double click after an alt click", #sent, 2)
  now = now + 0.1
  check("plain double click is swallowed", Click(map, "LeftButton", 0.8, 0.9), true)
  check("plain double click pings the first spot", sent[3] and sent[3].x, 0.4)
end

local function CheckHint(check, PingPong, env)
  local Find = PingPong.Hint.FindPinButton
  local function Refresh() end
  local function OtherRefresh() end
  local pinButton = { Refresh = Refresh }

  env.WorldMapTrackingPinButtonMixin = { Refresh = Refresh }
  check("no overlay list", Find({}), nil)
  check(
    "finds the pin button",
    Find({ overlayFrames = { { Refresh = OtherRefresh }, {}, pinButton } }),
    pinButton
  )
  check("no pin button", Find({ overlayFrames = { { Refresh = OtherRefresh } } }), nil)

  env.WorldMapTrackingPinButtonMixin = false
  check("no pin button mixin", Find({ overlayFrames = { pinButton } }), nil)

  PingPong.Hint.Attach(env.WorldMapFrame)
  check("hint builds without a pin button", true, true)

  local Advance = PingPong.Hint.Advance
  check("expanding stops at the end", Advance(0.9, 1, 1), 1)
  check("collapsing stops at the start", Advance(0.1, 0, 1), 0)

  local scripts, width, resizes, panels, widths, frames, clip = {}, nil, 0, {}, {}, {}, nil
  local function ShownPanels()
    local count = 0
    for _, shown in pairs(panels) do
      count = count + (shown and 1 or 0)
    end
    return count
  end
  local NewMock = env.CreateFrame
  local plays, stops = 0, 0
  local function PulseGroup()
    local group = NewMock()
    group.Play = function()
      plays = plays + 1
    end
    group.Stop = function()
      stops = stops + 1
    end
    return group
  end
  local function Region()
    local region = NewMock()
    region.CreateAnimationGroup = PulseGroup
    region.CreateTexture = Region
    region.CreateFontString = Region
    region.GetFrameLevel = function()
      return 1
    end
    region.GetStringWidth = function()
      return 100
    end
    region.SetWidth = function(self, value)
      widths[self] = value
      if self ~= clip then
        resizes = resizes + 1
      end
    end
    region.SetShown = function(self, shown)
      panels[self] = shown
    end
    return region
  end
  local frame = Region()
  frame.SetSize = function(_, value)
    width = value
  end
  frame.SetWidth = function(_, value)
    width = value
    resizes = resizes + 1
  end
  frame.SetScript = function(_, name, script)
    scripts[name] = script
  end
  env.CreateFrame = function()
    local created = #frames == 0 and frame or Region()
    frames[#frames + 1] = created
    return created
  end

  PingPong.Hint.Attach(env.WorldMapFrame)
  clip = frames[2]
  local collapsed, collapsedClip = width, widths[clip]
  check("no animation at rest", scripts.OnUpdate, nil)

  check("one panel when collapsed", ShownPanels(), 1)
  check("pulses while collapsed", plays, 1)
  scripts.OnEnter()
  check("hovering stops the pulse", stops, 1)
  check("one panel as it starts expanding", ShownPanels(), 1)
  local resizesBeforeSlide = resizes
  scripts.OnUpdate(frame, 0.05)
  check("one panel while expanding", ShownPanels(), 1)
  check("the reveal is partway out", widths[clip] > collapsedClip, true)
  check("the reveal is not fully out", widths[clip] < collapsedClip + 100, true)
  scripts.OnUpdate(frame, 1)
  check("only the clipping frame resizes in the slide", resizes, resizesBeforeSlide)
  check("the reveal passes the text", widths[clip] > collapsedClip + 100, true)
  check("hover area covers the text", width > collapsed + 100, true)
  check("animation stops when expanded", scripts.OnUpdate, nil)
  check("no pulse when expanded", plays, 1)
  scripts.OnShow()
  check("reopening the map expanded does not pulse", plays, 1)

  scripts.OnLeave()
  scripts.OnUpdate(frame, 0.05)
  check("no pulse while collapsing", plays, 1)
  check("one panel while collapsing", ShownPanels(), 1)
  check("the reveal is still sliding back", widths[clip] > collapsedClip, true)
  scripts.OnUpdate(frame, 1)
  check("the reveal slides all the way back", widths[clip], collapsedClip)
  check("hover area collapses", width, collapsed)
  check("one panel after collapsing", ShownPanels(), 1)
  check("animation stops when collapsed", scripts.OnUpdate, nil)
  check("pulse resumes once collapsed", plays, 2)
  scripts.OnShow()
  check("opening the map restarts the pulse", plays, 3)

  PingPong.Hint.ShowMessage("Too many pings")
  check("a message stops the pulse", stops, 2)
  check("a message opens the panel", width > collapsed + 100, true)
  scripts.OnUpdate(frame, 1)
  check("a message slides out", widths[clip] > collapsedClip + 100, true)
  check("a message stays open for a while", scripts.OnUpdate ~= nil, true)
  check("no pulse during a message", plays, 3)
  scripts.OnUpdate(frame, 5)
  check("a message closes by itself", width, collapsed)
  scripts.OnUpdate(frame, 1)
  check("a message slides back", widths[clip], collapsedClip)
  check("animation stops after a message", scripts.OnUpdate, nil)
  check("pulse resumes after a message", plays, 4)

  PingPong.Hint.ShowMessage("Too many pings")
  scripts.OnEnter()
  scripts.OnUpdate(frame, 5)
  check("hovering keeps it open after a message", width > collapsed + 100, true)
  scripts.OnLeave()
  scripts.OnUpdate(frame, 1)
  check("leaving closes it after a message", width, collapsed)

  PingPong.Hint.ShowMessage("Too many pings")
  scripts.OnHide()
  check("closing the map ends a message", width, collapsed)
  check("closing the map stops the animation", scripts.OnUpdate, nil)
  local playsBeforeReopen = plays
  scripts.OnShow()
  check("reopening after a message pulses", plays, playsBeforeReopen + 1)
end

return function(check, PingPong, env)
  CheckDoubleClick(check, PingPong.Map)
  CheckResolve(check, PingPong.Map, env)
  CheckMessages(check, PingPong, env)
  CheckBurstLimit(check, PingPong, env)
  CheckLinkClicks(check, PingPong, env)
  CheckCanvasClicks(check, PingPong, env)
  CheckHint(check, PingPong, env)
end
