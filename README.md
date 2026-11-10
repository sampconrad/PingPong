# PingPong

Double-left-click or Alt+left-click the world map to ping it for your group, the way a click on the minimap does.

- Everyone in your party, raid or instance group who runs PingPong sees the ping and hears the minimap ping sound.
- If the ping can't be seen right away, because the map is closed or showing somewhere else, they get a chat line saying who pinged and where. Clicking the zone name opens the map there, except during combat, when the game doesn't allow it. The ping waits 10 seconds in case they open the map.
- Double-clicking a zone on a continent map opens that zone and marks the spot you clicked.
- Alt+left-click pings right away and keeps the map where it is, for spots where a click would open a closer or underground map.
- The PingPong logo at the top right of the map shows the Alt + Left Click shortcut when you hover it.

## Limits

- Only players with the addon see pings.
- Blizzard blocks addon messages during an active boss encounter, Mythic+ key or PvP match. You still see your own ping, but it isn't shared.
- Double-clicks and Alt+clicks on a quest or point-of-interest icon go to that icon instead.

## Development

See [CLAUDE.md](CLAUDE.md). `pwsh ./scripts/link-addons.ps1` links the addon into your WoW clients.
