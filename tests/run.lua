-- tests/run.lua: compiles and loads the addon against tests/wowstub.lua, once per client, then
-- runs the unit specs. Started by scripts/test.ps1: luajit tests/run.lua <repo>.
-- LuaJIT shares Lua 5.1's language and its limit of 200 locals per function.

local args = { ... }
local root = table.remove(args, 1)
local ADDON = "PingPong"

package.path = root .. "/tests/?.lua;" .. package.path
local Stub = require("wowstub")

local SPECS = { "spec_codec", "spec_pingpong" }

local failures = 0
local fileCount = 0

local function Fail(where, message)
  failures = failures + 1
  print(("[FAIL] %s: %s"):format(where, message))
end

local function ReadAll(path)
  local handle = assert(io.open(path, "rb"))
  local text = handle:read("*a")
  handle:close()
  return text
end

local toc = ReadAll(("%s/%s/%s.toc"):format(root, ADDON, ADDON))

local function Scripts()
  local scripts = {}
  for line in toc:gmatch("[^\r\n]+") do
    if line:match("%.lua%s*$") and not line:match("^#") then
      scripts[#scripts + 1] = line:match("^%s*(.-)%s*$"):gsub("\\", "/")
    end
  end
  return scripts
end

local function InterfaceNumbers()
  local retail = assert(toc:match("## Interface:%s*(%d+)"), "the TOC has no ## Interface")
  local forever = assert(toc:match("## Interface%-Forever:%s*(%d+)"), "the TOC has no Forever line")
  return tonumber(retail), tonumber(forever)
end

local function LoadFile(env, addonTable, file)
  local where = ("%s/%s"):format(ADDON, file)
  fileCount = fileCount + 1
  local chunk, syntaxError = loadfile(("%s/%s"):format(root, where))
  if not chunk then
    Fail(where, syntaxError)
    return
  end
  setfenv(chunk, env)
  local ok, loadError = xpcall(function()
    chunk(ADDON, addonTable)
  end, debug.traceback)
  if not ok then
    Fail(where, loadError)
  end
end

local function RunSpecs(client, addonTable, env)
  for _, name in ipairs(SPECS) do
    local spec = require(name)
    local function Check(label, actual, expected)
      if actual ~= expected then
        Fail(
          ("%s (%s)"):format(name, client),
          ("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual))
        )
      end
    end
    local ok, specError = xpcall(function()
      spec(Check, addonTable, env)
    end, debug.traceback)
    if not ok then
      Fail(("%s (%s)"):format(name, client), specError)
    end
  end
end

local function RunClient(client, build)
  local env = Stub.NewEnv(build)
  local addonTable = {}
  for _, file in ipairs(Scripts()) do
    LoadFile(env, addonTable, file)
  end
  RunSpecs(client, addonTable, env)
end

local retail, forever = InterfaceNumbers()
RunClient("retail", retail)
RunClient("forever", forever)

if failures > 0 then
  print(("%d test failure(s)."):format(failures))
  os.exit(1)
end
print(("[PASS] %d file loads across Retail and Forever, plus unit specs."):format(fileCount))
os.exit(0)
