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
│   │   └── ...
│   └── release-template.md
└── manifest.json
```

- `manifest.json` - contains the dynamic variables used in `release-template.md`

### Setup

1. Create a `manifest.json` file in the root to configure the publisher settings.
2. Create/edit `release-template.md` file that will contain the body of the commit.

> (Optional) Add `workflow/create-release.yml` to your github workflow

### Creating release

1. Edit version in `manifest.json` or run `bump_version.ps1 -[minor|major|*patch]`
2. Run `eRelease.ps1` on the root of the project

### eRelease.ps1 Mechanism

1. Checks for `release-assets` folder, if not empty adds it to the release and write a hash table for it.

### Required Config for Manifest.json

| Key     | Value |
| ------- | ----- |
| VERSION | 1.0.0 |

### Automatic Variables

| Key | Value         |
| --- | ------------- |
| TAG | "v${VERSION}" |

### User Custom Variables

> Custom Variables are also Supported

| Key      | Value                          |
| -------- | ------------------------------ |
| APPNAME  | Tracie                         |
| REPO     | Deadbush225/Tracie             |
| DEMOLINK | https://tracie-viz.vercel.app/ |

### Example

```md
# ${APPNAME} — Release Notes

**Version:** ${TAG}
**Release date:** ${DATE}

**Full Changelog**: https://github.com/${REPO}/commits/${TAG}
**Live Link:** ${DEMOLINK}
```

### Template only Variables

| Key | Value         |
| @HASH_TABLE@ | Where hash table will be inserted |
