# Opens the Royal Mint Godot project with the repo-local .NET and Godot paths
# so the Mono editor can start cleanly on Windows without manual env setup.
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$GodotArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ProjectRoot
$DotnetRoot = Join-Path $RepoRoot ".local\\dotnet"
$GodotExe = Join-Path $RepoRoot ".local\\godot-mono\\4.6-stable\\Godot_v4.6-stable_mono_win64\\Godot_v4.6-stable_mono_win64.exe"

if (-not (Test-Path $DotnetRoot)) {
    throw "Missing local .NET SDK at '$DotnetRoot'. Run '..\\.codex\\setup.ps1' first."
}

if (-not (Test-Path $GodotExe)) {
    throw "Missing local Godot editor at '$GodotExe'. Run '..\\.codex\\setup.ps1' first."
}

$env:DOTNET_ROOT = $DotnetRoot
if (-not ($env:PATH -split ';' | Where-Object { $_ -eq $DotnetRoot })) {
    $env:PATH = "$DotnetRoot;$env:PATH"
}

& $GodotExe --path $ProjectRoot @GodotArgs
