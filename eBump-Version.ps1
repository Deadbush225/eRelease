#!/usr/bin/env pwsh
param(
  [Parameter(Position=0)]
  [switch]$major,
  [switch]$minor,
  [switch]$patch
)

# Find project root (containing manifest.json)
$root = $PSScriptRoot
while ($true) {
    if (Test-Path (Join-Path $root "manifest.json")) {
        break
    }
    $parent = Split-Path -Parent $root
    if ($parent -eq $root) { 
        $root = $null
        break 
    }
    $root = $parent
}

if ($null -eq $root) {
    # Fallback: assume we are in root or context is correct
    Write-Error "Could not find project root containing manifest.json"
    exit 1
}

Push-Location $root
$Path = Join-Path $root "manifest.json"
try {
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

  Write-Host "Current manifest version: $major_i.$minor_i.$patch_i"

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
  Write-Host "Bumping target to: $newVersion"

  # 1. Update manifest.json
  $json.version = $newVersion
  $txt = $json | ConvertTo-Json -Depth 20
  Set-Content -Path $Path -Value $txt -Encoding UTF8
  Write-Host " -> Updated manifest.json"

  # 2. Dictionary of other versioned files and their Regex patterns
  # (?m) enables multiline mode so ^ matches the start of a line
  $filesToUpdate = @{
      "package.json" = @{
          # Matches: "version": "1.0.0" (keeps spacing intact)
          Pattern = '(?m)(^\s*"version"\s*:\s*)"\d+\.\d+\.\d+[a-zA-Z0-9\.\-\+]*"'
          Replacement = '${1}"' + $newVersion + '"'
      }
      "pubspec.yaml" = @{
          # Matches: version: 1.0.0+1 (keeps spacing intact, handles build numbers)
          Pattern = '(?m)(^version\s*:\s*)[''"]?\d+\.\d+\.\d+[a-zA-Z0-9\.\-\+]*[''"]?'
          Replacement = '${1}' + $newVersion
      }
      "Cargo.toml" = @{
          # Matches: version = "1.0.0" (For Rust, if needed)
          Pattern = '(?m)(^version\s*=\s*)"\d+\.\d+\.\d+[a-zA-Z0-9\.\-\+]*"'
          Replacement = '${1}"' + $newVersion + '"'
      }
      "pyproject.toml" = @{
          # Matches: version = "1.0.0" (For Python, if needed)
          Pattern = '(?m)(^version\s*=\s*)"\d+\.\d+\.\d+[a-zA-Z0-9\.\-\+]*"'
          Replacement = '${1}"' + $newVersion + '"'
      }
  }

  # 3. Iterate and apply changes to any matched files
  foreach ($fileName in $filesToUpdate.Keys) {
      $targetPath = Join-Path $root $fileName
      if (Test-Path $targetPath) {
          $config = $filesToUpdate[$fileName]
          $content = Get-Content -Raw -Path $targetPath
          
          if ($content -match $config.Pattern) {
              $newContent = [regex]::Replace($content, $config.Pattern, $config.Replacement)
              Set-Content -Path $targetPath -Value $newContent -Encoding UTF8
              Write-Host " -> Updated $fileName"
          } else {
              Write-Warning " -> Found $fileName, but could not locate a valid version string."
          }
      }
  }

  Write-Output ""
  Write-Output "Successfully updated to $newVersion"

} finally {
  Pop-Location
}