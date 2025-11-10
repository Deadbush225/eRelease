#!/usr/bin/env pwsh
param([switch]$noInteractive = $false, [switch]$publish)

# run from the project root
import-module "$PSScriptRoot/Write-ReleaseNotes.ps1"
$notesFile, $variableMap = Write-ReleaseNotes

#check if a git tag already exists
$existingTag = git tag --list $variableMap['TAG']
if ([string]::IsNullOrWhiteSpace($existingTag)) {
    Write-Error "Git tag $($variableMap['TAG']) does not exist. Please create the tag and commit before publishing the release."
    exit
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