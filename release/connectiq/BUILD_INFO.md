# Connect IQ build info

Fill this in for the package that was uploaded to the Connect IQ Store.
Do not commit the `.iq` file or the developer key. The key used for the first
upload has to sign every later update of this app.

| | |
| --- | --- |
| App | Daily Verse |
| Version | 1.0.0 |
| App id | `5af97fbc-6678-4ebe-8e0a-2cddfca4a32b` |
| Type | watch-app |
| Min API | 4.0.0 |
| SDK | 9.2.0 |
| Built | 2026-10-12 |
| Git | `671f240` (tag v1.0.0) |
| Package | `release/connectiq/app.iq (not committed)` |
| SHA-256 | `5a9eff6694ad77a57d9be28741a9ab557cd5ac3595b33597a2a33060c5fbb2ef` |
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

Store text: `store/listing-de.md` (primary), `store/listing-en.md`.
Privacy text: `store/privacy-de.md`, `store/privacy-en.md`.
Screenshots and icons: `store/assets/`.
