## Installation

> Just add the repo as a submodule

```
git submodule add https://github.com/Deadbush225/eRelease.git scripts/eRelease
```

## Recommended Project Structure

```
project/
├── scripts/
│   ├── eRelease/
│   │   ├── eRelease.ps1
│   │   ├── release-template.md    # create this one
│   │   └── ...
└── manifest.json
```

- `manifest.json` - contains the dynamic variables used in `release-template.md`

### Setup

1. Create a `manifest.json` file in the root to **configure** the publisher settings.
2. Create/edit `release-template.md` file that will contain the body of the commit.

> (Required)
github cli (gh), make sure you have authenticated first

> (Optional) Add `workflow/create-release.yml` to your github workflow

### Creating release

> Build first the assets before creating a release

1. Edit version in `manifest.json` or run `bump_version.ps1 -[minor|major|*patch]`
2. Run `eRelease.ps1` on the root of the project

### eRelease.ps1 Mechanism

1. Checks for `release-assets` folder, if not empty adds it to the release and write a hash table for it.

### Required Config for Manifest.json

| Key     | Value |
| ------- | ----- |
| VERSION | 1.0.0 |
| REPO     | https://github.com/Deadbush225/Poltergeist |

### Automatic Variables

| Key | Value | Deps | Description |
| --- | ----- | ---- | ----------- |
| `TAG` | `v${VERSION}` | `VERSION` | Generated release tag (prefix `v`) |
| `DATE` | Current date | — | Release date (ISO 8601 or project locale) |
| `@ASSETS_TABLE@` | Generated Markdown table of asset names, sizes and hashes | `ASSETS_*` (`ASSETS_PATHS`, `ASSETS_EXTENSIONS`, `ASSETS_IGNORE_REGEX`) | Inserted into the release body when assets are present |
| `@CHANGE_LOG_URL@` | URL to full changelog | `REPO` | Link to changelog; requires a valid previous tag in the repository |


### Optional Variables

| Key | Value |
| --- | ----- |
| ASSETS_PATHS | Array of assets folders |

### User Custom Variables

> Custom Variables are also Supported

| Key      | Value                          |
| -------- | ------------------------------ |
| APPNAME  | Tracie                         |
| DEMOLINK | https://tracie-viz.vercel.app/ |

### Example

```md
# ${APPNAME} — Release Notes

**Version:** ${TAG}
**Release date:** ${DATE}

**Full Changelog**: ${CHANGE_LOG_URL}
**Live Link:** ${DEMOLINK}
```

```json
{
	"APPNAME": "eprint",
	"VERSION": "1.6.3",
	"DESCRIPTION": "A mobile application for scanning, printing, and managing documents on the go.",
	"ASSETS_PATHS": ["./build/app/outputs/flutter-apk"],
	"ASSETS_EXTENSIONS": [".apk"],
	"ASSETS_IGNORE_REGEX": ["unaligned", "debug", "mapping"]
}
```

### Process Flow

manifest.json -> eWrite-ReleaseNotes.ps1 -> eRelease.ps1