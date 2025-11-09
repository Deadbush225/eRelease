# run from project root

Write-Host "Current Directory: $(Get-Location)"
# read file contents release-template.md
$releaseNotesPath = "./scripts/release-template.md"
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

Write-Host "Release Notes:"
Write-Host $releaseNotes

#check if a git tag already exists
$existingTag = git tag --list $variableMap['TAG']
if ([string]::IsNullOrWhiteSpace($existingTag)) {
    Write-Error "Git tag $($variableMap['TAG']) does not exist. Please create the tag and commit before publishing the release."
    exit
}

# confirm
$confirm = Read-Host "Create GitHub release $($variableMap['TAG']) in repo $($variableMap['REPO'])? (Y/n)"
if ([string]::IsNullOrWhiteSpace($confirm)) {
    $confirm = 'Y';
}
if ($confirm.ToUpper() -notin @('Y', 'YES')) {
    Write-Warning "Release cancelled by user."
    exit
}

# prepare temp dir and write notes
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("tracie_release_{0}" -f ([guid]::NewGuid().ToString()))
New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

$notesFile = Join-Path $tempDir 'release-template.md'
$releaseNotes | Out-File -FilePath $notesFile -Encoding UTF8

Write-Host "Wrote release notes to: $notesFile"

# create release using gh CLI
$tag = $variableMap['TAG']
$repo = $variableMap['REPO']
$title = "$($variableMap['APPNAME']) $version"

try {
    & gh release create $tag --title $title --notes-file $notesFile -R $repo
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