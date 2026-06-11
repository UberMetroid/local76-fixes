#!/usr/bin/env pwsh
# run.ps1 - local76 monorepo unified CLI task runner

param(
    [Parameter(Position = 0)]
    [ValidateSet("build", "test", "deb", "release", "verify", "help", "")]
    [string]$Action = "help",

    [Parameter(Position = 1)]
    [string]$Target = "",

    [Parameter(Position = 2)]
    [string]$Version = ""
)

$ErrorActionPreference = "Stop"
$monorepoRoot = $PSScriptRoot

$apps = @("helm", "pulse", "scout", "trance", "ignite")
$screensavers = @("beams", "bounce", "bursts", "chaos", "cosmos", "disco", "flame", "glyphs", "gnats", "storm")

function Show-Help {
    Write-Host "local76 Monorepo Unified Task Runner" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Gray
    Write-Host "  pwsh ./run.ps1 build                   - Build all crates in dependency order" -ForegroundColor Gray
    Write-Host "  pwsh ./run.ps1 build library           - Build the shared library only" -ForegroundColor Gray
    Write-Host "  pwsh ./run.ps1 build apps              - Build all apps" -ForegroundColor Gray
    Write-Host "  pwsh ./run.ps1 build screensavers      - Build all screensaver shims" -ForegroundColor Gray
    Write-Host "  pwsh ./run.ps1 build <name>            - Build a specific app or screensaver (e.g. helm, bounce)" -ForegroundColor Gray
    Write-Host "  pwsh ./run.ps1 test                    - Run cargo tests across all crates" -ForegroundColor Gray
    Write-Host "  pwsh ./run.ps1 deb                     - Build DEB packages for all screensavers (Linux)" -ForegroundColor Gray
    Write-Host "  pwsh ./run.ps1 release <name> <version> - Package and publish a GitHub release for an app" -ForegroundColor Gray
    Write-Host "  pwsh ./run.ps1 verify                  - Verify cargo dep pins and gitignore hygiene" -ForegroundColor Gray
    Write-Host ""
}

if ($Action -eq "" -or $Action -eq "help") {
    Show-Help
    exit 0
}

switch ($Action) {
    "build" {
        if ($Target -eq "" -or $Target -eq "all") {
            # Build everything via the compiler script
            pwsh "$monorepoRoot/toolkit/scripts/compile-local-development.ps1"
        }
        elseif ($Target -eq "library") {
            pwsh "$monorepoRoot/toolkit/scripts/compile-local-development.ps1" -SkipScreensavers -SkipApps
        }
        elseif ($Target -eq "apps") {
            pwsh "$monorepoRoot/toolkit/scripts/compile-local-development.ps1" -SkipScreensavers
        }
        elseif ($Target -eq "screensavers") {
            pwsh "$monorepoRoot/toolkit/scripts/compile-local-development.ps1" -SkipApps
        }
        else {
            # Specific target
            if ($Target -in $apps) {
                $dir = "app-$Target"
                if (-not (Test-Path "$monorepoRoot/$dir")) {
                    $dir = $Target
                }
            }
            elseif ($Target -in $screensavers) {
                $dir = "screensaver-$Target"
            }
            else {
                Write-Host "Unknown build target: $Target" -ForegroundColor Red
                Show-Help
                exit 1
            }

            # Compile library prerequisite
            Write-Host "=== Building library (prerequisite) ===" -ForegroundColor Cyan
            Push-Location "$monorepoRoot/library"
            try {
                cargo build --release
            } finally {
                Pop-Location
            }

            # Compile target
            Write-Host "=== Building $Target ===" -ForegroundColor Cyan
            Push-Location "$monorepoRoot/$dir"
            try {
                cargo build --release
            } finally {
                Pop-Location
            }
        }
    }
    "test" {
        # 1. Test library
        Write-Host "=== Testing library ===" -ForegroundColor Cyan
        Push-Location "$monorepoRoot/library"
        try { cargo test } finally { Pop-Location }

        if ($Target -eq "library") { return }

        # 2. Test screensavers
        if ($Target -eq "" -or $Target -eq "screensavers" -or $Target -in $screensavers) {
            $targets = if ($Target -in $screensavers) { @($Target) } else { $screensavers }
            foreach ($s in $targets) {
                Write-Host "=== Testing screensaver-$s ===" -ForegroundColor Cyan
                Push-Location "$monorepoRoot/screensaver-$s"
                try { cargo test } finally { Pop-Location }
            }
        }

        # 3. Test apps
        if ($Target -eq "" -or $Target -eq "apps" -or $Target -in $apps) {
            $targets = if ($Target -in $apps) { @($Target) } else { $apps }
            foreach ($a in $targets) {
                $dir = "app-$a"
                if (-not (Test-Path "$monorepoRoot/$dir")) { $dir = $a }
                Write-Host "=== Testing app-$a ===" -ForegroundColor Cyan
                Push-Location "$monorepoRoot/$dir"
                try { cargo test } finally { Pop-Location }
            }
        }
    }
    "deb" {
        pwsh "$monorepoRoot/toolkit/scripts/build-all-screensaver-linux-packages.ps1"
    }
    "verify" {
        if (Test-Path "$monorepoRoot/toolkit/scripts/verify-pins.ps1") {
            pwsh "$monorepoRoot/toolkit/scripts/verify-pins.ps1"
        } else {
            Write-Host "verify-pins.ps1 not found, skipping" -ForegroundColor Yellow
        }
    }
    "release" {
        if ($Target -eq "") {
            Write-Host "Error: App/screensaver name is required for release action." -ForegroundColor Red
            Show-Help
            exit 1
        }
        if ($Version -eq "") {
            Write-Host "Error: Version is required for release action (e.g. 2026.7.0)." -ForegroundColor Red
            Show-Help
            exit 1
        }
        pwsh "$monorepoRoot/toolkit/scripts/publish-app-release.ps1" -App $Target -Version $Version
    }
}
