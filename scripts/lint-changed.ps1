param()

$ErrorActionPreference = "Stop"

function Get-ChangedFiles {
    $staged = git diff --name-only --cached 2>$null
    $unstaged = git diff --name-only 2>$null
    $untracked = git ls-files --others --exclude-standard 2>$null

    $all = @()
    if ($staged) { $all += $staged }
    if ($unstaged) { $all += $unstaged }
    if ($untracked) { $all += $untracked }

    return $all | Sort-Object -Unique
}

Write-Host "== PingPong lint-changed =="

# The WoW AddOns link (no-op without WoW) and the API names are cheap, so they run every time.
pwsh -NoProfile -File (Join-Path $PSScriptRoot "link-addons.ps1") -Check
$repoExit = $LASTEXITCODE

pwsh -NoProfile -File (Join-Path $PSScriptRoot "check-globals.ps1")
if ($LASTEXITCODE -ne 0) { $repoExit = 1 }

$changed = Get-ChangedFiles

if (-not $changed -or $changed.Count -eq 0) {
    Write-Host "[PASS] No changed files detected."
    exit $repoExit
}

$luaTargets = $changed | Where-Object { $_ -match '\.lua$' -and (Test-Path -LiteralPath $_) }

if (-not $luaTargets -or $luaTargets.Count -eq 0) {
    Write-Host "[PASS] No changed Lua files to lint."
    exit $repoExit
}

Write-Host "[INFO] Running pre-commit on changed Lua files:"
$luaTargets | ForEach-Object { Write-Host "  - $_" }

pre-commit run --files @luaTargets
$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
    Write-Error "pre-commit failed for changed files."
    exit $exitCode
}

Write-Host "[PASS] pre-commit passed for changed Lua files."

pwsh -NoProfile -File (Join-Path $PSScriptRoot "test.ps1") -SkipIfMissing
if ($LASTEXITCODE -ne 0) { $repoExit = 1 }

if ($repoExit -ne 0) {
    Write-Error "check-globals, the WoW link check or the load test failed; see the [FAIL] lines above."
}
exit $repoExit
