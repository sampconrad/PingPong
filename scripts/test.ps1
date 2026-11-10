param(
    [switch]$SkipIfMissing
)

$ErrorActionPreference = "Stop"

# Compiles and loads the addon against a stubbed client (Retail and Forever), then runs the unit
# specs in tests/. Needs LuaJIT (winget install DEVCOM.LuaJIT). A pass means every file loads and
# the pure logic works; what the addon does on a real map still needs the live client.

$repo = Split-Path $PSScriptRoot -Parent

$lua = (Get-Command luajit -ErrorAction SilentlyContinue).Source
if (-not $lua -and $env:LOCALAPPDATA) {
    # A shell opened before the install has a stale PATH.
    $installed = Join-Path $env:LOCALAPPDATA "Programs/LuaJIT/bin/luajit.exe"
    if (Test-Path -LiteralPath $installed) { $lua = $installed }
}
if (-not $lua) {
    if ($SkipIfMissing) {
        Write-Host "[WARN] LuaJIT not found; skipped the load test (winget install DEVCOM.LuaJIT)."
        exit 0
    }
    Write-Host "[FAIL] LuaJIT not found (winget install DEVCOM.LuaJIT)."
    exit 1
}

Write-Host "== PingPong load test =="
& $lua (Join-Path $repo "tests/run.lua") ($repo -replace '\\', '/')
exit $LASTEXITCODE
