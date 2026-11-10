param(
    # One WoW AddOns folder. Defaults to every client the TOCs list (CLIENTS below) under the
    # install found in the registry.
    [string]$AddOnsPath,
    # Print what would change without touching anything.
    [switch]$DryRun,
    # Like -DryRun, but exits 1 when any link is missing, wrong or stale (lint-changed uses it).
    # Exits 0 with a note when no WoW install is found, so it never blocks a machine without WoW.
    [switch]$Check
)

$ErrorActionPreference = "Stop"

# Links the PingPong addon folder into the AddOns folder of every installed client as a directory
# junction (no admin needed). A client folder that is not installed is skipped. An existing link is
# replaced. A real folder with that name is left alone.
# A PingPong link that points into this repo at a folder that no longer exists (an addon
# that was renamed or removed) is pruned. Links pointing anywhere else are left alone.

# Client folders under the WoW root, matching the TOC's ## Interface / ## Interface-Forever.
$CLIENTS = @("_retail_", "_forever_")

# Addons left out of a client: none today.
$SKIP_ON_CLIENT = @{}

if ($Check) { $DryRun = $true }

$targets = @()
if ($AddOnsPath) {
    $targets = @($AddOnsPath)
}
else {
    $keys = @(
        "HKLM:\SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft",
        "HKLM:\SOFTWARE\Blizzard Entertainment\World of Warcraft"
    )
    foreach ($key in $keys) {
        if (Test-Path $key) {
            $install = (Get-ItemProperty $key).InstallPath
            if ($install) {
                # InstallPath is a client folder (usually ...\_retail_\); its parent is the WoW root.
                $root = Split-Path $install.TrimEnd('\') -Parent
                foreach ($client in $CLIENTS) {
                    $path = Join-Path $root "$client\Interface\AddOns"
                    if (Test-Path $path) { $targets += $path }
                }
                break
            }
        }
    }
}
$targets = @($targets | Where-Object { Test-Path $_ })
if ($targets.Count -eq 0) {
    if ($Check) {
        Write-Host "[SKIP] link check: no WoW AddOns folder found on this machine."
        exit 0
    }
    Write-Error "AddOns folder not found. Pass -AddOnsPath '<WoW>\_retail_\Interface\AddOns'."
    exit 1
}

$repo = Split-Path $PSScriptRoot -Parent
$addons = Get-ChildItem -Path $repo -Directory | Where-Object {
    $_.Name -eq "PingPong" -and (Test-Path (Join-Path $_.FullName "$($_.Name).toc"))
}
$repoPrefix = $repo.TrimEnd('\') + '\'

$failed = $false
$pending = $false
foreach ($target in $targets) {
    if ($Check) {
        Write-Host "== Checking the PingPong link in $target =="
    }
    else {
        Write-Host "== Linking PingPong into $target =="
    }
    $skipHere = @()
    foreach ($client in $SKIP_ON_CLIENT.Keys) {
        if ($target -like "*\$client\*") { $skipHere = $SKIP_ON_CLIENT[$client] }
    }
    foreach ($addon in $addons) {
        $dest = Join-Path $target $addon.Name
        $item = Get-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue

        if ($skipHere -contains $addon.Name) {
            # Not wanted on this client: drop our link if one exists, never a real folder.
            if ($item -and $item.LinkType) {
                $pending = $true
                if ($DryRun) {
                    Write-Host "[DRY]  unlink $($addon.Name) (not used on this client)"
                }
                else {
                    $item.Delete()
                    Write-Host "[UNLINK] $($addon.Name) (not used on this client)"
                }
            }
            continue
        }

        if ($item -and -not $item.LinkType) {
            Write-Host "[SKIP] $dest is a real folder; move it away and run again"
            $failed = $true
            continue
        }
        if ($item -and ($item.Target | Select-Object -First 1) -eq $addon.FullName) {
            if (-not $Check) { Write-Host "[OK]   $($addon.Name) already linked" }
            continue
        }
        $pending = $true
        if ($DryRun) {
            $old = if ($item) { " (replaces link to $($item.Target))" } else { "" }
            Write-Host "[DRY]  $($addon.Name) -> $($addon.FullName)$old"
            continue
        }
        if ($item) {
            # Non-recursive delete on a link removes only the link, never its target.
            $item.Delete()
        }
        New-Item -ItemType Junction -Path $dest -Target $addon.FullName | Out-Null
        Write-Host "[LINK] $($addon.Name) -> $($addon.FullName)"
    }

    # Stale links: PingPong junctions into this repo whose folder is gone.
    $links = Get-ChildItem -LiteralPath $target -Directory -Force | Where-Object { $_.Name -eq "PingPong" -and $_.LinkType }
    foreach ($link in $links) {
        $linkTarget = $link.Target | Select-Object -First 1
        if (-not $linkTarget -or -not $linkTarget.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase)) { continue }
        if (Test-Path -LiteralPath $linkTarget) { continue }
        $pending = $true
        if ($DryRun) {
            Write-Host "[DRY]  prune $($link.Name) (points at missing $linkTarget)"
            continue
        }
        $link.Delete()
        Write-Host "[PRUNE] $($link.Name) (pointed at missing $linkTarget)"
    }
}

if ($Check) {
    if ($pending -or $failed) {
        Write-Host "[FAIL] WoW AddOns links are out of date. Run: pwsh ./scripts/link-addons.ps1"
        exit 1
    }
    Write-Host "[PASS] PingPong is linked in $($targets.Count) client(s)."
    exit 0
}
if ($failed) {
    exit 1
}
exit 0
