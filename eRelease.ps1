#!/usr/bin/env pwsh
param(
    [switch]$noInteractive = $false
)

$scriptPath = $PSScriptRoot

# Find project root (containing manifest.json)
$root = $scriptPath
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
try {
    # run from the project root
    import-module "$scriptPath/eWrite-ReleaseNotes.ps1" -Force
    $notesFile, $variableMap, $tempDir, $allAssets = Write-ReleaseNotes

    #check if a git tag already exists
    $existingTag = git tag --list $variableMap['TAG']
    if ([string]::IsNullOrWhiteSpace($existingTag)) {
        Write-Error "Git tag $($variableMap['TAG']) does not exist. Please create the tag and commit before publishing the release."
        exit 1
    }

    # confirm
    if (-not $noInteractive) {
        $confirm = Read-Host (BOLD "Create GitHub release $($variableMap['TAG']) in repo $($variableMap['REPO'])? (Y/n)")
        if ([string]::IsNullOrWhiteSpace($confirm)) {
            $confirm = 'Y';
        }
        if ($confirm.ToUpper() -notin @('Y', 'YES')) {
            Write-Warning "Release cancelled by user."
            exit
        }
    }

    # create release using gh CLI
    $tag = $variableMap['TAG']
    $repo = $variableMap['REPO']
    $version = $variableMap['VERSION']
    $title = "$($variableMap['APPNAME']) $version"

    # Collect assets to upload
    $assetsList = $allAssets | ForEach-Object { $_.FullName }

    try {
        if ($assetsList.Count -gt 0) {
            & gh release create $tag $assetsList --title $title --notes-file $notesFile -R $repo
        }
        else {
            & gh release create $tag --title $title --notes-file $notesFile -R $repo
        }

        if ($LASTEXITCODE -eq 0) {
            Write-Host "Release $tag created successfully."
        }
        else {
            Write-Error "gh exited with code $LASTEXITCODE."
        }
    }
    catch {
        Write-Error "Failed to run gh: $_"
    }
    finally {
        # cleanup temp dir
        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
finally {
    Pop-Location
}
