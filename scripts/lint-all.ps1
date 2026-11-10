param()

$ErrorActionPreference = "Stop"

# The whole-repo check: WoW API names, StyLua, Selene and the load test. Reports only, nothing is
# reformatted. Exits 1 if any step fails.

$repo = Split-Path $PSScriptRoot -Parent
Push-Location $repo
try {
    $failed = @()

    pwsh -NoProfile -File (Join-Path $PSScriptRoot "check-globals.ps1")
    if ($LASTEXITCODE -ne 0) { $failed += "check-globals" }

    $luaFiles = @(Get-ChildItem -Path $repo -Recurse -File -Filter *.lua |
            ForEach-Object { $_.FullName.Substring($repo.Length + 1) -replace '\\', '/' } |
            Where-Object { $_ -match '^(PingPong|tests)/' } |
            Sort-Object)

    Write-Host "== StyLua ($($luaFiles.Count) files) =="
    & stylua --config-path stylua.toml --check @luaFiles
    if ($LASTEXITCODE -ne 0) { $failed += "stylua" }

    Write-Host "== Selene =="
    & selene --config selene.toml @luaFiles
    if ($LASTEXITCODE -ne 0) { $failed += "selene" }

    pwsh -NoProfile -File (Join-Path $PSScriptRoot "test.ps1")
    if ($LASTEXITCODE -ne 0) { $failed += "test" }

    if ($failed.Count -gt 0) {
        Write-Host "[FAIL] lint-all: $($failed -join ', ')"
        exit 1
    }
    Write-Host "[PASS] lint-all"
    exit 0
}
finally {
    Pop-Location
}
