# Connect IQ build info

Fill this in for the package that was uploaded to the Connect IQ Store.
Do not commit the `.iq` file or the developer key. The key used for the first
upload has to sign every later update of this app.

| | |
| --- | --- |
| App | Daily Verse |
| Version | 1.1.0 |
| App id | `5af97fbc-6678-4ebe-8e0a-2cddfca4a32b` |
| Type | watch-app |
| Min API | 4.0.0 |
| SDK | 9.2.0 |
| Built | 2026-10-23 |
| Git | tag v1.1.0 (commit "Release 1.1.0", built from `c5ee981` + version bump) |
| Devices | 28 manifest products, 45/45 device targets built |
| Package | `release/connectiq/app.iq (not committed)` |
| SHA-256 | `2e37c47412c568157f7c61a5660ba9cc6a433493d7d63ae35b100427d2b6bce0` |
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
