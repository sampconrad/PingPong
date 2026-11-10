---
description: Combat lockdown, secret-value and taint guardrails for all addon Lua
paths:
  - "**/*.lua"
---

# Lua safety

## Combat and taint

- PingPong never touches protected frames. Keep it that way: plain frames on the map canvas, no `AcquirePin` (it makes a protected call that addon code can't make in combat).
- `AddCanvasClickHandler` handlers run through `securecallfunction`, so they can't taint Blizzard's navigation. Never call `SetMapID` or navigate from addon code: that would run Blizzard's pin refresh tainted.
- Don't replace Blizzard globals. Prefer data providers and `hooksecurefunc`.

## Secret values (Retail and Forever)

In instances, unit identity and many measures are secret on tainted execution paths. Comparing, truth-testing, indexing with, or using `#` on a secret raises a Lua error.

- `PingPong.IsSecret(value)` before any compare or branch on a value from the game that could be secret. Treat secret as unknown and fail soft.
- `UnitName` can be secret, so identity must not depend on it. Own messages are recognized by text (`ConsumeOwnEcho` in `Comms.lua`).
- `pcall` contains a missing API. It never makes a secret readable, and neither does `tostring`.

## Forever client (`Interface-Forever: 16001`)

- Same secret model as Retail, but check that newer functions exist before calling them (`InChatMessagingLockdown`).
- The `wow-api` MCP reports Mainline only. For Forever signatures, check Blizzard's UI source on the `forever` branch.

## General

- Keep per-frame work small: no table churn in `OnUpdate`.
- Validate external input. Addon messages come from other players: decode strictly, rate-limit per sender.
