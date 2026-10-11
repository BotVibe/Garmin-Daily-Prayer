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
| Built | YYYY-MM-DD |
| Git | `<commit>` |
| Package | `export/DailyVerse.iq` |
| SHA-256 | `<sha256sum of the .iq>` |
| Developer key | `<path, not the key itself>` |
| Price | free |

## Commands

From the repository root, with `CIQ_SDK_HOME` pointing at the SDK and
`CIQ_DEVELOPER_KEY` pointing at the DER key:

```bash
scripts/test.sh
scripts/build.sh
scripts/export.sh
sha256sum export/DailyVerse.iq
```

`scripts/export.sh` fails unless every manifest product is built into the
package. Upload `export/DailyVerse.iq` at
https://apps.garmin.com/developer/dashboard

Store text: `store/listing-de.md` (primary), `store/listing-en.md`.
Privacy text: `store/privacy-de.md`, `store/privacy-en.md`.
Screenshots and icons: `store/assets/`.
