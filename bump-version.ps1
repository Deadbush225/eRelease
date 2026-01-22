#!/usr/bin/env pwsh
param(
  [Parameter(Position=0)]
  [string]$Path = "manifest.json",

  [switch]$major,
  [switch]$minor,
  [switch]$patch
)

# Ensure only one bump flag is provided
$flags = @($major,$minor,$patch) | Where-Object { $_ }
if ($flags.Count -gt 1) {
  Write-Error "Specify only one of -Major, -Minor or -Patch."
  exit 2
}

# Default to patch_i if none provided
if ($flags.Count -eq 0) {
  Write-Host "No version bump flag provided; defaulting to -Patch."
  $patch = $true
}

if (-not (Test-Path -Path $Path)) {
  Write-Error "File not found: $Path"
  exit 1
}

# Read JSON
try {
  $raw = Get-Content -Raw -Path $Path
  $json = $raw | ConvertFrom-Json
} catch {
  Write-Error "Failed to read or parse JSON from $Path"
  exit 1
}

if (-not $json.PSObject.Properties.Name -contains 'version') {
  Write-Error "No 'version' property found in $Path"
  exit 1
}

$version = [string]$json.version

# Parse semantic version: major_i.minor_i.patch_i (optionally with pre-release/build - ignored)
if ($version -notmatch '^\s*(\d+)\.(\d+)\.(\d+)') {
  Write-Error "Version '$version' is not in expected MAJOR.MINOR.PATCH format."
  exit 1
}

[int]$major_i = [int]$Matches[1]
[int]$minor_i = [int]$Matches[2]
[int]$patch_i = [int]$Matches[3]

Write-Host "Current version: $major_i.$minor_i.$patch_i"
Write-Host "$major $minor $patch"

if ($major) {
  $major_i += 1
  $minor_i = 0
  $patch_i = 0
} elseif ($minor) {
  $minor_i += 1
  $patch_i = 0
} elseif ($patch) {
  $patch_i += 1
}

$newVersion = "$major_i.$minor_i.$patch_i"

# Backup original
# $backup = "$Path.bak.$((Get-Date).ToString('yyyyMMddHHmmss'))"
# Copy-Item -Path $Path -Destination $backup -Force

# Update and write JSON
$json.version = $newVersion
# Pretty-print JSON with reasonable depth
$txt = $json | ConvertTo-Json -Depth 20
Set-Content -Path $Path -Value $txt -Encoding UTF8

Write-Output $newVersion