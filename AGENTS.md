# AGENTS.md — Daily Verse (Garmin Connect IQ)

Anweisungen für Menschen und Coding-Agents, die an diesem Repository arbeiten.

---

## Projektzweck

Connect IQ **watch-app**, die:

- den **Bibelvers des Tages** (App-Name in jeder Sprache: **Daily Verse**) von DailyVerses.net lädt,
- zu bis zu **3** konfigurierbaren Uhrzeiten per `requestApplicationWake` fragt (Annehmen/Ablehnen),
- bei Annehmen den Vers zeigt und bei Ablehnen nichts tut,
- den Vers auch **manuell** aus dem Apps-Menü zeigt,
- Sprache + Bibelübersetzung (inkl. zufällig pro Sprache) einstellen lässt,
- **energieeffizient** arbeitet (kein Polling, Tages-Cache, ein TemporalEvent).

UI-Default: **Englisch** (`resources`). Weitere UI-Sprachen: Deutsch (`resources-deu`), Französisch (`resources-fre`). Die Uhrensprache wählt das Overlay automatisch.

---

## Harte Invarianten

1. **App-Typ bleibt `watch-app`.** Kein Widget/Glance als Ersatz für den Wake-Flow (Widgets sind auf Zielgeräten oft abgekündigt; Wake braucht die App).
2. **Nur ein TemporalEvent.** Immer die *nächste* **aktivierte** Slot-Zeit schedulen (`ReminderScheduler.scheduleNext`). Niemals Intervall-Polling. Niemals eine Nicht-Slot-Zeit (z. B. `now+5min`) als Wake registrieren.
3. **Ablehnen = Idle.** Kein automatisches erneutes Öffnen; nächste Erinnerung trotzdem planen (im Background vor/bei Wake). **`requestApplicationWake` nur wenn `isReminderDueNow`** (lokale Zeit nahe einem aktivierten Slot); sonst nur neu schedulen und exit.
4. **Nur Zurück in VerseView beendet die App** (`System.exit`) → normales Watchface. Select/Tap beendet **nicht**; sie halten die Anzeige hell (`Attention.backlight`, wo unterstützt).
5. **API:** Plaintext `https://dailyverses.net/get/verse?language=<code>`. Der Website-`verse.js`-Embed ist dokumentiert, aber nicht der Primärpfad.
6. **`language` Query-Param = Übersetzungscode** (z. B. `lut`), nicht ISO-Sprachcode. Gespeichert wird die Katalog-Position `languageIndex`.
7. **Übersetzung „Zufällig“** (`translationIndex` 0, intern `random`): stabile Tageswahl aus Codes der Sprache; Ergebnis cachen.
8. **Dokumentationspflicht:** Jede Verhaltens-/API-/Settings-/Geräte-Änderung aktualisiert **README.md und AGENTS.md in derselben Änderung**.

---

## Dateizuordnung

| Bereich | Dateien |
| --- | --- |
| Manifest / Geräte | `manifest.xml`, `monkey.jungle` |
| Entry / Lifecycle | `source/DailyVerseApp.mc` |
| Background Wake | `source/BackgroundService.mc`, `source/ReminderScheduler.mc` |
| Vers laden | `source/VerseApi.mc`, `source/VerseCache.mc` |
| Katalog | `source/Translations.mc` |
| Properties | `source/AppConfig.mc`, `resources/properties/properties.xml`, `resources/settings/settings.xml` |
| UI Vers | `source/VerseView.mc`, `resources/layouts/verse.xml`, `resources-round-*/` |
| UI Home (optional) | `source/HomeView.mc` (Default-Entry ist VerseView) |
| UI Settings | `source/SettingsMenu.mc`, `source/NumberFactory.mc` (Zeit-Picker) |
| Strings | `resources/strings/strings.xml` (EN), `resources-deu/…`, `resources-fre/…` |
| CI / Tests | `.github/workflows/ci.yml`, `tests/`, `tools/dailyverse_lib/`, `requirements-dev.txt` |
| Build-Skripte | `scripts/build.sh`, `scripts/test.sh`, `scripts/export.sh`, `scripts/fetch_devices.sh` |
| Store | `store/listing-en.md` (Master), `listing-de.md`, `listing-fr.md`, `store/README.md`, `store/privacy-*.md`, `store/assets/` (Screenshots: englische UI) |
| Release | `CHANGELOG.md`, `release/connectiq/BUILD_INFO.md`, `LICENSE` |
| Auto-Merge | `.github/workflows/auto-merge.yml` (nach grüner CI → squash in `main`, keine Drafts) |
| Parser-Smoke | `tools/verify_verse_parse.py` (nutzt `dailyverse_lib`) |
| Icons / Settings | `tools/gen_icons.py`, `tools/gen_settings.py`, `tools/gen_screenshots.py` |
| Docs | `README.md`, `AGENTS.md` |

### Background-Annotation

Alles, was der Background-Prozess lädt, muss mit `(:background)` markiert sein bzw. nur erlaubte APIs nutzen:

- `BackgroundService`, `ReminderScheduler`, `AppConfig`, `Translations`, `VerseCache`

Keine `WatchUi`-Abhängigkeiten im Background-Pfad.

---

## Einstellungen (Properties)

| Key | Typ | Bedeutung |
| --- | --- | --- |
| `languageIndex` | number | Position in `Translations.languageIds()` (`6` = `de`) |
| `translationIndex` | number | `0` = zufällig, sonst Position im Katalog (`13` = `lut`) |
| `appVersion` | string | Angezeigte Version, nur lesbar in den Settings |
| `slotNEnabled` | boolean | N = 1..3 |
| `slotNHour` | number | 0–23 |
| `slotNMinute` | number | 0–59 |

On-Device-Menüs sind die UX-Quelle der Wahrheit für kaskadierende Sprache→Übersetzung: die Übersetzungs-Liste zeigt nur `Translations.codesForLanguage(lang)` (+ „Zufällig“). Wird die Sprache gewechselt und die aktuelle Übersetzung ungültig, Fallback auf `defaultCode(lang)`.

Connect-Mobile-Settings spiegeln die Properties, können die Übersetzungsliste aber **nicht** dynamisch nach Sprache filtern (Garmin `list`-Settings sind flach/numerisch). `AppConfig.normalize()` / `getTranslationCode()` validieren und fallen auf den Sprach-Default zurück. Das ist die bestmögliche Plattformlösung.

Nach Settings-Änderungen immer `ReminderScheduler.scheduleNext()` aufrufen.

Erinnerungszeiten sind **lokale Wanduhrzeit** der Uhr (`momentForLocalClock` über `Gregorian.info` / Mitternacht lokal). Niemals lokale HH:MM in `Gregorian.moment` stecken (dessen Optionen sind UTC — Ursache für ~1–2 h Versatz, z. B. 09:00→11:00 bei UTC+2). TemporalEvent: min. 5 Minuten ab `now` **und** `Background.getLastTemporalEventTime`. Deaktivierte Slots zählen nicht; Background holt keine Verse und zeigt keine Wake außerhalb des Due-Fensters (~15 Min).

---

## Wenn du X änderst → aktualisiere Y

| Änderung | Pflicht-Updates |
| --- | --- |
| Neue Sprache / Übersetzung | `Translations.mc`, `settings.xml`, Strings (`Lang_*`, `Trans_*` in EN/DEU/FRE), **README** (Tabelle), **AGENTS** (falls Invariante/Katalogbeschreibung) |
| Erinnerungslogik / Slot-Anzahl | `AppConfig`, `ReminderScheduler`, `properties.xml`, `settings.xml`, Settings-UI, **README**, **AGENTS** |
| API-URL oder Parse-Format | `VerseApi.mc`, `tools/dailyverse_lib/parse.py`, `tests/test_verse_parse.py`, **README**, **AGENTS** |
| Katalog Sprache/Übersetzung | `Translations.mc`, Settings/Strings, `tools/dailyverse_lib/catalog.py`, `tests/test_catalog_consistency.py`, **README**, **AGENTS** |
| Reminder-Algorithmus | `ReminderScheduler.mc`, `tools/dailyverse_lib/reminder.py`, `tests/test_reminder_schedule.py`, **README**, **AGENTS** |
| Neue Geräte | `manifest.xml`, **README** Geräte-Liste |
| UI-Flow (Exit, Menü, Wake) | Views/Delegates, **README** Nutzerfluss, **AGENTS** Invarianten |
| Default-Properties | `properties.xml`, **README** Defaults |

### Doc-Update-Checkliste (vor Commit)

- [ ] README beschreibt das aktuelle Nutzerverhalten korrekt
- [ ] README API-/Settings-/Geräte-Abschnitte stimmen
- [ ] AGENTS-Invarianten stimmen noch
- [ ] Dateizuordnung in AGENTS enthält neue wichtigen Dateien
- [ ] Keine veralteten Widget-/Polling-Hinweise
- [ ] CI-Tests / `dailyverse_lib` angepasst, falls Logik betroffen
- [ ] `pytest -m "not network"` lokal grün

---

## Build / Test für Agents

- Das Garmin SDK liegt nicht im Repo. Build über `scripts/build.sh` dokumentieren; CI installiert SDK 9.2.0 selbst.
- **CI (GitHub Actions):** `.github/workflows/ci.yml` — Python 3.12, `pytest -m "not network"` (pflicht), Network-Smoke optional/`continue-on-error`, plus Compile mit SDK 9.2.0 für jedes Manifest-Produkt.
- Lokal: `scripts/test.sh`, `scripts/build.sh`, `scripts/export.sh` (`ROOT` = Repo-Wurzel).
- **Auto-Merge:** `.github/workflows/auto-merge.yml` — nach erfolgreicher CI werden Ready-PRs (nicht Draft) gegen `main` per Squash gemerged. PRs für Auto-Merge als non-draft belassen oder auf Ready stellen.
- Lokal ohne SDK:

  ```bash
  pip install -r requirements-dev.txt
  pytest -m "not network"
  python3 tools/verify_verse_parse.py
  ```

- Python-Spiegel der Monkey-C-Logik liegen in `tools/dailyverse_lib/` und müssen bei Algorithmus-Änderungen mitgezogen werden.
- Manuelle Gerätetests (lokal): Simulator Background Wake, Accept/Decline, Offline-Cache, Sprachwechsel, Random-Übersetzung über Mitternacht.

### Bekannte CIQ-Fallen

- TemporalEvent: min. 5 Minuten; nur einer aktiv; `getLastTemporalEventTime` + 5 Min beachten. Kein Register von Nicht-Slot-Zeiten.
- `Gregorian.moment(options)` interpretiert Felder als **UTC**, nicht lokal. Lokale Slot-Zeiten über Mitternacht aus `Gregorian.info` bauen.
- `requestApplicationWake` nur nach `isReminderDueNow`; Schedule der nächsten Zeit **nicht** vom Accept abhängig machen.
- `makeWebRequest` braucht Phone-Link.
- Ungültige `<iq:product id>` im Manifest brechen den Build — nur dokumentierte Device-IDs. SDK 9.2.0 kennt `fenix7pronowifi` und `fenix7xpronowifi` nicht.
- `String` hat kein `trim()`. Whitespace in `VerseApi.trim` selbst entfernen.
- Sprach-Ressourcen nicht per `deu.resourcePath` / `fre.resourcePath` anhängen. Der Default-Jungle mappt `resources-<lang>` auf `base.lang.<lang>` (Default-Strings = Englisch in `resources/`).
- Connect-Settings vom Typ `list` akzeptieren nur numerische `listEntry`-Werte und können nicht von einer anderen Setting abhängen. `settings.xml` kommt aus `tools/gen_settings.py`.
- Layouts erzeugen Custom-Drawables mit einem Parameter-Dictionary. `initialize(params)` muss es an `Drawable.initialize` weiterreichen.
- `Attention.backlight`: Feature-Check (`Attention has :backlight`); auf OLED kann längeres Halten `BacklightOnTooLongException` werfen (~1 Min). System-Timeout der Hintergrundbeleuchtung bleibt maßgeblich; die App kann nur erneut anstoßen, nicht dauerhaft erzwingen.

---

## Nicht-Ziele

- Kein Watchface, kein Data Field, kein Companion-Phone-Plugin.
- Kein Offline-Bibel-Volltext auf der Uhr.
- Keine Push-Server-Infrastruktur neben DailyVerses.net.
- Keine Social-/Share-Features.

---

## Coding-Stil (Monkey C)

- Explizite Typen wo der CIQ-Typechecker es verlangt (`as String`, `as Void`, …).
- Module für zustandslose Helpers (`Translations`, `VerseCache`, `AppConfig`).
- Keine unnötigen Timer/Redraws.
- Ressourcen-IDs über `Rez.*`; keine hardcodierten User-Strings in der UI (Wake-Message im Background ist Ausnahme wegen fehlendem Rez).

---

## Agent-Workflow in diesem Repo

1. Feature-Branch `cursor/<kurzname>-b565` (Cloud-Agent-Konvention).
2. Änderungen implementieren.
3. Docs mitziehen (README + AGENTS).
4. `pytest -m "not network"` (und bei Parser/API zusätzlich Network/Smoke).
5. Commit mit klarer Message, push, PR — CI muss für Offline-Tests grün sein.

Bei Unklarheiten: Invarianten in diesem File haben Vorrang vor kosmetischen Refactors.
