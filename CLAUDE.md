# PingPong (WoW addon)

Standalone Retail (12.x) and Forever addon: double-left-click or Alt+left-click the world map to ping it for group members who also run PingPong. Namespace is the addon table (`local _, PingPong = ...`). Lua 5.1, no build step, no SavedVariables, no slash commands. The repo root holds tooling; only `PingPong/` is linked into WoW.

## What's where

- `PingPong/PingPong.toc` is the load order: `Init`, `Codec`, `PingFrame`, `Hint`, `MapProvider`, `Comms`.
- `Core/`: `Init.lua` (constants and `IsSecret`), `Codec.lua` (message format), `Comms.lua` (send and receive).
- `Map/`: `MapProvider.lua` (double-click and Alt+click detection, placing and holding pings), `PingFrame.lua` (the animation), `Hint.lua` (the logo on the map that expands on hover to show the Alt + Left Click shortcut, and by itself to show a short message).
- `Assets/`: the BLP art. Paths name the folder: `Interface\AddOns\PingPong\Assets\`.
- `tests/`: `wowstub.lua` fakes the client, `spec_*.lua` cover the pure logic. A pass doesn't replace in-game testing.
- In game, `/run PingPongTest(mapID, x, y)` (all optional) fakes an incoming ping through the real receive path, for testing solo. Only a second player with the addon proves messages travel between clients.

## Facts that shape the code

- `SendAddonMessage` is blocked during an active encounter, Mythic+ key or PvP match (`C_ChatInfo.InChatMessagingLockdown`). The sender still sees a local ping and gets an error.
- Spam limits: one send per second, one accepted ping per player per half second, and a burst limit (`BURST_*` in `Init.lua`) that ignores a player for a while. Receivers enforce them; the sender applies the burst limit to itself too, and the map's PingPong button slides out to say so.
- The first click of a double click navigates as usual, and the second is swallowed. The ping uses the first click's map and spot.
- Alt+left-click is swallowed and pings at once, so the map doesn't navigate. Blizzard only uses Alt on the map in a GM-only debug provider.
- The zone link in the chat line opens the map through `C_Map.OpenWorldMap`, which doesn't taint the map but is blocked in combat, so a click in combat only shows an error.
- Details on taint and secrets: `.claude/rules/lua-safety.md`.

## Commands

- `pwsh ./scripts/lint-changed.ps1`: StyLua, Selene and tests on changed Lua, plus link and API name checks. **Run it twice** (the first run reformats).
- `pwsh ./scripts/lint-all.ps1`: every check on the whole repo, report only.
- `pwsh ./scripts/test.ps1`: load test on Retail and Forever, then specs.
- `pwsh ./scripts/check-globals.ps1`: fails on a name Blizzard's source doesn't have. Fix a typo, or for a real name run `-Update` or add it to `scripts/data/wow-globals-manual.txt` with the reason.
- `pwsh ./scripts/link-addons.ps1`: junctions `PingPong/` into every installed client. WoW only finds new addons at startup.

## Working agreements

- **Ask before** committing, bumping `## Version`, pushing, or posting to GitHub.
- **WoW API facts:** `wow-api` MCP first, then Blizzard's UI source (`https://github.com/Gethe/wow-ui-source`, branches `live` and `forever`), then warcraft.wiki.gg.
- **Headers:** every Lua file keeps `PingPong/Folder/File.lua — DOMAIN — title`, then *What it does / Architecture / Does not / Related*.
- Reach game globals through `_G.` (Selene denies undefined names, and `check-globals` reads those).
- Text files are LF. Use the Edit tool for Lua: shell tools mangle backslashes in texture paths.
