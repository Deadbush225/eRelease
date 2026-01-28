function BOLD {
    param (
        $string
    )
    return "`e[1m$string`e[0m"
}

function Write-ReleaseNotes {
    # read file contents release-template.md
    $releaseNotesPath = Join-Path $PSScriptRoot 'release-template.md'
    if (-not (Test-Path $releaseNotesPath)) {
        Write-Error "Release notes file not found: $releaseNotesPath"
        return
    }

    # read

    # read manifest.json
    $manifestPath = "./manifest.json"
    if (-not (Test-Path $manifestPath)) {
        Write-Error "manifest.json file not found: $manifestPath"
        return
    }
    $manifest = Get-Content $manifestPath | ConvertFrom-Json
    $version = $manifest.VERSION

    $releaseNotes = Get-Content $releaseNotesPath -Raw

    $variableMap = @{
        "APPNAME"  = $manifest.APPNAME;
        "VERSION"  = $version;
        "DATE"     = (Get-Date).ToString("yyyy-MM-dd");
        "TAG"      = "v$version";
        "REPO"     = $manifest.REPO;
        "DEMOLINK" = $manifest.DEMOLINK;
    }

    foreach ($key in $variableMap.Keys) {
        $pattern = [regex]::Escape('${' + $key + '}')
        $replacement = $variableMap[$key]
        $releaseNotes = [regex]::Replace($releaseNotes, $pattern, [System.Text.RegularExpressions.MatchEvaluator] { param($m) $replacement })
    }

    # Check for release-assets to generate SHA table
    $assetsPath = "release-assets"
    $hashTableMd = ""
    if (Test-Path $assetsPath) {
        $assets = Get-ChildItem -Path $assetsPath -File
        if ($assets.Count -gt 0) {
            $hashTableMd += "### File Checksums`n"
            $hashTableMd += "| File | SHA256 |`n"
            $hashTableMd += "| :--- | :--- |`n"
            foreach ($file in $assets) {
                $hash = Get-FileHash -Path $file.FullName -Algorithm SHA256
                $name = $file.Name
                $sha = "`$($hash.Hash)`"
                $downloadLink = "$($variableMap['REPO'])/releases/download/$($variableMap['TAG'])/$name"
                $hashTableMd += "| [$name]($downloadLink) | $sha |"

                if ($file -ne $assets[-1]) {
                    $hashTableMd += "`n"
                }
            }
        }
    }
    
    if ($releaseNotes -match '@ASSETS_TABLE@') {
        $releaseNotes = $releaseNotes -replace '@ASSETS_TABLE@', $hashTableMd
    } else {
        $releaseNotes += "`n$hashTableMd"
    }

    # prepare temp dir and write notes
    # Build a safe path for the temporary directory (Pass Path and ChildPath separately to Join-Path)
    $tempDir = Join-Path $PSScriptRoot 'tmp'
    New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
    $notesFile = Join-Path $tempDir 'release-template.md'
    $releaseNotes | Out-File -FilePath $notesFile -Encoding UTF8

    Write-Host "Wrote release notes to: $notesFile"

    # Use ANSI bold (terminal must support ANSI)
    Write-Host (BOLD "Release Notes:")
    Write-Host $releaseNotes -ForegroundColor DarkCyan
    return $notesFile, $variableMap, $tempDir
}