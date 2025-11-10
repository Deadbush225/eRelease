function BOLD {
    param (
        $string
    )
    return "`e[1m$string`e[0m"
}

function Write-ReleaseNotes {
    # read file contents release-template.md
    $releaseNotesPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'release-template.md'
    if (-not (Test-Path $releaseNotesPath)) {
        Write-Error "Release notes file not found: $releaseNotesPath"
        exit
    }

    # read

    # read manifest.json
    $manifestPath = "./manifest.json"
    if (-not (Test-Path $manifestPath)) {
        Write-Error "manifest.json file not found: $manifestPath"
        exit
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
    return $notesFile, $variableMap
}