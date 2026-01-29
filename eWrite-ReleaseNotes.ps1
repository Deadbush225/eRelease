
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

    # read manifest.json
    $manifestPath = "./manifest.json"
    if (-not (Test-Path $manifestPath)) {
        Write-Error "manifest.json file not found: $manifestPath"
        return
    }
    $manifest = Get-Content $manifestPath | ConvertFrom-Json
    $version = $manifest.VERSION

    # Determine previous tag for changelog
    $currentTag = "v$version"
    $tags = @(git tag --sort=-creatordate)
    $previousTag = $null

    if ($tags -contains $currentTag) {
        $idx = $tags.IndexOf($currentTag)
        if ($idx + 1 -lt $tags.Count) {
            $previousTag = $tags[$idx + 1]
        }
    } elseif ($tags.Count -gt 0) {
        $previousTag = $tags[0]
    }

    $changeLogUrl = ""
    if ($previousTag -and $manifest.REPO) {
        $repoUrl = $manifest.REPO.TrimEnd('/')
        $changeLogUrl = "**Full Changelog**: $repoUrl/compare/$previousTag...$currentTag"
    }

    $releaseNotes = Get-Content $releaseNotesPath -Raw

    # add standard and automatic variables to map
    $variableMap = @{
        "APPNAME"  = $manifest.APPNAME;
        "VERSION"  = $manifest.VERSION;
        "DATE"     = (Get-Date).ToString("yyyy-MM-dd");
        "TAG"      = "v$version";
    }

    # add custom manifest variables to map
    foreach ($property in $manifest.PSObject.Properties) {
        $variableMap[$property.Name] = $property.Value
    }

    foreach ($key in $variableMap.Keys) {
        $pattern = [regex]::Escape('${' + $key + '}')
        $replacement = $variableMap[$key]
        $releaseNotes = [regex]::Replace($releaseNotes, $pattern, [System.Text.RegularExpressions.MatchEvaluator] { param($m) $replacement })
    }

    # ------------------------------------------------------------ #

    # Get assets from manifest
    $assetPaths = $variableMap['ASSETS_PATHS']
    if ($null -eq $assetPaths -or $assetPaths.Count -eq 0) {
        Write-Warning "No ASSETS array provided in manifest.json. Falling back to default 'release-assets'."
        $assetPaths = @("release-assets")
    }
    $assetExts = $variableMap['ASSETS_EXTENSIONS']
    $assetIgnoreRegex = $variableMap['ASSETS_IGNORE_REGEX']

    # Check for release-assets to generate SHA table
    $hashTableMd = ""
    $allAssets = @()

    foreach ($path in $assetPaths) {
        if (Test-Path $path) {
            $item = Get-Item $path
            if ($item.PSIsContainer) {
                # Add directory files, optionally filtered by extension
                $files = Get-ChildItem -Path $path -File
                if ($null -ne $assetExts -and $assetExts.Count -gt 0) {
                     $files = $files | Where-Object { $assetExts -contains $_.Extension }
                }
                
                # Filter by ignore regex
                if ($null -ne $assetIgnoreRegex -and $assetIgnoreRegex.Count -gt 0) {
                     foreach ($regex in $assetIgnoreRegex) {
                        $files = $files | Where-Object { $_.Name -notmatch $regex }
                     }
                }

                $allAssets += $files
            } else {
                # Add single file, checking extension if filter exists
                if ($null -eq $assetExts -or $assetExts.Count -eq 0 -or ($assetExts -contains $item.Extension)) {
                    # Check regex ignore for single file
                    $shouldAdd = $true
                    if ($null -ne $assetIgnoreRegex -and $assetIgnoreRegex.Count -gt 0) {
                        foreach ($regex in $assetIgnoreRegex) {
                           if ($item.Name -match $regex) {
                               $shouldAdd = $false
                           }
                        }
                    } 
                    
                    if ($shouldAdd) {
                        $allAssets += $item
                    }
                }
            }
        }
    }

    if ($allAssets.Count -gt 0) {
        $hashTableMd += "### File Checksums`n"
        $hashTableMd += "| Download Link | Installer Size | SHA256 |`n"
        $hashTableMd += "| :--- | :--- | :--- |`n"
        foreach ($file in $allAssets) {
            $hash = Get-FileHash -Path $file.FullName -Algorithm SHA256
            $name = $file.Name
            $fileSize = [Math]::Round($file.Length / 1MB, 2)
            $sha = "``$($hash.Hash)``"
            $downloadLink = "$($variableMap['REPO'])/releases/download/$($variableMap['TAG'])/$name"
            $hashTableMd += "| [$name]($downloadLink) | $fileSize MB | $sha |"

            if ($file -ne $allAssets[-1]) {
                $hashTableMd += "`n"
            }
        }
    }
    
    if ($releaseNotes -match '@ASSETS_TABLE@') {
        $releaseNotes = $releaseNotes -replace '@ASSETS_TABLE@', $hashTableMd
    } else {
        $releaseNotes += "`n$hashTableMd"
    }

    if ($releaseNotes -match '@CHANGE_LOG_URL@') {
        $releaseNotes = $releaseNotes -replace '@CHANGE_LOG_URL@', $changeLogUrl
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
    return $notesFile, $variableMap, $tempDir, $allAssets
}

Write-ReleaseNotes