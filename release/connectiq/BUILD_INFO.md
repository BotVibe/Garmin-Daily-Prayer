# Connect IQ build info

Fill this in for the package that was uploaded to the Connect IQ Store.
Do not commit the `.iq` file or the developer key. The key used for the first
upload has to sign every later update of this app.

| | |
| --- | --- |
| App | Daily Verse |
| Version | 1.2.0 |
| App id | `5af97fbc-6678-4ebe-8e0a-2cddfca4a32b` |
| Type | watch-app |
| Min API | 4.0.0 |
| SDK | 9.2.0 |
| Built | 2026-10-25 |
| Git | tag v1.2.0 (commit "Release 1.2.0", built from `b0ba16a` + version bump + `fre` manifest language) |
| Devices | 28 manifest products, 45/45 device targets built |
| Package | `release/connectiq/app.iq (not committed)` |
| SHA-256 | `5e583e2444efd0b6ea49174e4bbf0668efc34433b3b3dd4d963e7d95de23147f` |
| Developer key | `~/.config/ciq-release/developer_key.der` (box) |
| Price | free |

## Commands

From the repository root, with `CIQ_SDK_HOME` pointing at the SDK and
`CIQ_DEVELOPER_KEY` pointing at the DER key:

```bash
scripts/test.sh
scripts/build.sh
scripts/export.sh
sha256sum release/connectiq/app.iq (not committed)
```

`scripts/export.sh` fails unless every manifest product is built into the
package. Upload `release/connectiq/app.iq (not committed)` at
https://apps.garmin.com/developer/dashboard

Store text: `store/listing-en.md` (master), `store/listing-de.md`, `store/listing-fr.md`.
Privacy text: `store/privacy-en.md`, `store/privacy-de.md`.
Screenshots and icons: `store/assets/` (screenshots show the English UI).
