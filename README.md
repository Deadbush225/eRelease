## Usage

> Run eRelease on the root project

1. Create a `manifest.json` file in the root to configure the publisher settings.
2. Edit `release-template.md` file that will contain the body of the commit.
3. Run `eRelease.ps1` on the root of the project

## Config for Manifest.json

| Key      | Value                          |
| -------- | ------------------------------ |
| APPNAME  | Tracie                         |
| REPO     | Deadbush225/Tracie             |
| DEMOLINK | https://tracie-viz.vercel.app/ |
| VERSION  | 1.0.0                          |

## Example

```md
# ${APPNAME} — Release Notes

**Version:** ${TAG}
**Release date:** ${DATE}

**Full Changelog**: https://github.com/${REPO}/commits/${TAG}
**Live Link:** ${DEMOLINK}
```
