# Daily Verse

Energieeffiziente **Garmin Connect IQ Watch-App** (Bibelvers des Tages). Sie lädt den Vers des Tages von [DailyVerses.net](https://dailyverses.net/), erinnert zu konfigurierbaren Uhrzeiten und zeigt den Vers auf der Uhr. Der Name der App ist in jeder Sprache **Daily Verse**. Version **1.1.0**, kostenlos.

| | |
| --- | --- |
| Typ | Connect IQ **watch-app** (Apps-Menü) |
| Version | **1.1.0** |
| API | `https://dailyverses.net/get/verse?language=<code>` |
| Min. API | Connect IQ **4.0.0** |
| Sprachen UI | Englisch (Default), Deutsch, Französisch (folgt der Uhrensprache) |
| Erinnerungen | Bis zu **3** Zeitslots |

---

## Features

1. **Erinnerungen** – Bis zu drei **lokale** Uhrzeiten (einzeln aktivierbar). Jeder aktive Slot feuert **einmal pro Kalendertag** zur HH:MM der Uhr (Zeitzone/DST der Uhr). Deaktivierte Slots feuern nie (ihre gespeicherten Zeiten zählen nicht).
2. **Ablehnen** – Es passiert nichts; die Uhr läuft normal weiter. Die nächste Erinnerung wird trotzdem geplant. Keine Catch-up-/Doppel-Alerts außerhalb eines fälligen Slots.
3. **Annehmen** – Die App öffnet die Vers-Ansicht mit dem Spruch des Tages.
4. **Ausblenden** – Nur die **Zurück**-Taste beendet die App → Zifferblatt. Tippen/Select beendet nicht; sie halten die Anzeige länger hell auf der **Systemhelligkeit** (soweit die Plattform das erlaubt). Lange Verse: nach oben/unten wischen bzw. UP/DOWN-Tasten scrollen (Referenz am Ende); kurze Verse unverändert.
5. **Manuell** – App im Apps-Menü starten → Vers wird sofort geladen (Cache bevorzugt).
6. **Einstellungen** – Sprache, Bibelübersetzung nur der gewählten Sprache (inkl. **Zufällig**), Erinnerungszeiten per Stunden-/Minuten-Rad – on-device und (eingeschränkt) in Garmin Connect Mobile.
7. **Energieeffizienz** – Ein TemporalEvent nur für die *nächste* Zeit, Tages-Cache, dunkles OLED-freundliches UI, kein Polling.

---

## Nutzerfluss

```text
Background TemporalEvent  (lokale Wanduhrzeit der Uhr)
        │
        ▼
requestApplicationWake  ──Ablehnen──►  Uhr normal / nächste Zeit geplant
        │
     Annehmen
        ▼
   VerseView (Spruch)
        │
   Tippen/Select → Display hell halten (Systemhelligkeit, kein Exit)
   Wischen / UP·DOWN → langen Vers scrollen (falls nötig)
   Zurück → App beendet → Watchface

Apps-Menü → App starten → VerseView (manuell)
Menü-Taste → Einstellungen / Aktualisieren
```

---

## Einstellungen

### On-Device (Menü-Taste)

| Eintrag | Beschreibung |
| --- | --- |
| Sprache | Alle von DailyVerses.net unterstützten Sprachen |
| Bibelübersetzung | **Nur** Übersetzungen der gewählten Sprache **plus** „Zufällig (Sprache)“ |
| Erinnerungen | Slot 1–3: aktiv, Uhrzeit (Zwei-Spalten-Rad Stunde∶Minute) |
| Aktualisieren | Vers neu von der API laden |
| Spruch des Tages | Zurück zur Vers-Ansicht |

Sprachwechsel: passt die gewählte Übersetzung nicht mehr zur Sprache, fällt die App auf den Default dieser Sprache zurück (`Translations.defaultCode`).

### Garmin Connect Mobile

Dieselben Properties (`languageIndex`, `translationIndex`, Slot-Flags/Zeiten) sind unter den App-Einstellungen spiegelbar. Garmin Connect akzeptiert in Auswahllisten nur Zahlen und **kann Listen nicht dynamisch nach einer anderen Einstellung filtern**. Deshalb zeigt Connect weiterhin den flachen Katalog: `0` ist „Zufällig“, danach alle Übersetzungen in der Reihenfolge von `Translations.languageIds()`. Eine Kombination, die nicht zur gewählten Sprache passt, wird beim App-Start und bei `onSettingsChanged` auf die Standard-Übersetzung dieser Sprache zurückgesetzt (`AppConfig.normalize`). Das ist die bestmögliche Lösung auf der Connect-Seite; die gefilterte Auswahl gibt es on-device. Die Versionszeile ist dort nur lesbar.

### Defaults

| Property | Default |
| --- | --- |
| Sprache | `languageIndex` **6** → `de` (Deutsch) |
| Übersetzung | `translationIndex` **13** → `lut` (Luther 2017) |
| Version | `appVersion` `1.1.0` (nur Anzeige) |
| Slot 1 | **an**, 08:00 |
| Slot 2 | aus, 12:00 |
| Slot 3 | aus, 20:00 |

---

## DailyVerses.net API

Die Website-Einbindung unter z. B. [dailyverses.net/de/webseite](https://dailyverses.net/de/webseite) nutzt JavaScript (`verse.js`). Für die Uhr verwenden wir den **Plaintext-Endpoint**, der denselben Tagesvers liefert:

```text
GET https://dailyverses.net/get/verse?language=<translationCode>
```

Beispiel (`language=elb`):

```text
Und der HERR wird König sein über die ganze Erde; …

Sacharja 14:9
```

Der Parameter `language` ist bei DailyVerses der **Übersetzungscode** (z. B. `lut`, `niv`, `elb`), nicht der ISO-Sprachcode. Die App mappt intern die gespeicherte Sprach-Position auf die erlaubten Codes.

### Zufällige Übersetzung

Wenn die Übersetzung auf „Zufällig“ steht (`translationIndex` 0, intern `random`), wählt die App deterministisch für den aktuellen Kalendertag einen Code aus der Liste der gewählten Sprache und cached das Ergebnis. So bleibt der Vers am selben Tag stabil.

### Sprachen & Codes

Der Katalog in [`source/Translations.mc`](source/Translations.mc) entspricht der DailyVerses-/WordPress-Plugin-Liste, u. a.:

| Sprache | Codes |
| --- | --- |
| Deutsch | `elb`, `lu12`, `lut`, `neu` |
| Englisch | `esv`, `kjv`, `nasb`, `ncb`, `niv`, `nkjv`, `nlt`, `nrsv`, `web` |
| Französisch | `bds`, `neg79`, `sg21` |
| Spanisch | `lbla`, `nvi`, `rvr60`, `rvr95` |
| … | siehe `Translations.codesForLanguage` |

Bei Erweiterung der Liste **müssen** `Translations.mc`, `resources/settings/settings.xml`, `README.md` und `AGENTS.md` gemeinsam aktualisiert werden.

---

## Architektur

```text
source/
  DailyVerseApp.mc       App-Entry, Background-Hook, Settings-Change
  BackgroundService.mc   TemporalEvent → due? Wake : idle → exit
  ReminderScheduler.mc   Nächstes Moment aus aktiven Slots + Due-Check
  VerseView.mc           Vers-UI + Delegate (Exit / Menü / Scroll)
  VerseScroll.mc         Scroll-Offset / Seitengröße (reine Helpers)
  HomeView.mc            Optionaler Brand-Screen (nicht Default-Entry)
  SettingsMenu.mc        On-Device-Menüs + Zeit-Picker
  NumberFactory.mc       Picker-Spalten (Stunde/Minute)
  VerseApi.mc            makeWebRequest + Parser
  VerseCache.mc          Application.Storage Tages-Cache
  AppConfig.mc           Properties-Zugriff
  Translations.mc        Sprachen-/Code-Katalog
  BackgroundDrawable.mc  Dunkler Round-Hintergrund
```

### Energie & Background

- Nur **ein** `registerForTemporalEvent(Moment)` (Garmin-Limit), immer die nächste *aktivierte* Slot-Zeit.
- Slot-Zeiten sind **lokale Wanduhrzeit** (`ReminderScheduler.momentForLocalClock`); `Gregorian.moment` (UTC-Optionen) wird dafür nicht verwendet.
- `requestApplicationWake` nur wenn `isReminderDueNow` (lokale Zeit innerhalb ~15 Min eines aktiven Slots). Sonst nur neu schedulen — keine Alerts bei App-Start, Settings-Sync oder verirrten TemporalEvents.
- Nach jedem Fire wird sofort die **nächste** Zeit berechnet (auch bei Ablehnen). Kein Fallback auf „jetzt + 5 Min“ als Wake-Zeit.
- Minimum **5 Minuten** Abstand zu `Time.now` **und** zum letzten TemporalEvent (`getLastTemporalEventTime`). Erwartete Genauigkeit: typisch wenige Minuten um die Soll-Minute; bis ~5 Min verspätet, wenn die 5‑Min-Regel greift, plus OS-Wake-Latenz.
- Fetch nur im **Foreground** nach App-Start; Background lädt keine Verse und erzeugt keine Alerts außerhalb fälliger Erinnerungen.
- Cache-Schlüssel: Datum + Sprache + Übersetzungseinstellung.
- Anzeige hell halten: `Attention.backlight(true)` (Feature-Check) — Boolean **true** = Systemhelligkeit der Uhr, kein Float-Maximum. Auf OLED ~1 Min Continuous-Limit (`BacklightOnTooLongException`). Tippen setzt den Dim-Timer zurück; Auto-Repeat ~40 s, dann System-Timeout.
- Lange Verse: Scroll statt „…“-Abschneiden (`onNextPage`/`onPreviousPage` = Wischen bzw. Tasten). Bibelstelle nach dem Vers-Text; kurzer Chevron-Hinweis wenn noch Text folgt.

### Berechtigungen

- `Communications` – Vers laden (Telefon muss verbunden sein).
- `Background` – Temporal Events + Application Wake.

---

## Unterstützte Geräte

Moderne runde Uhren (Auswahl):

- fēnix 7 / 7S / 7X und die Pro-Modelle
- fēnix 8 (43 mm, 47 mm, Pro 47 mm, Solar 47/51 mm)
- epix (Gen 2) und epix Pro (42/47/51 mm)
- Forerunner 255 / 255 Music / 255S / 265 / 955 / 965
- Venu 2 / 2S / 2 Plus / 3 / 3S

Vollständige IDs: [`manifest.xml`](manifest.xml). `fenix7pronowifi` und `fenix7xpronowifi` kennt SDK 9.2.0 nicht; die Pro-Modelle ohne dieses Suffix decken dieselben Uhren ab.

---

## Build & Installation

### Voraussetzungen

1. [Garmin Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) (API ≥ 4.0)
2. Visual Studio Code + [Monkey C Extension](https://marketplace.visualstudio.com/items?itemName=garmin.monkey-c) **oder** CLI `monkeyc`
3. Developer Key (für Gerät/Export)
4. Garmin Connect Mobile am Telefon (für WebRequest auf der Uhr)

### Projekt öffnen

```bash
# Repo klonen
cd Garmin-Daily-Prayer   # bzw. Workspace-Root

# In VS Code: Ordner öffnen, „Monkey C: Build for Device“ / Simulator
```

### CLI

`scripts/build.sh`, `scripts/test.sh` und `scripts/export.sh` rechnen `ROOT` vom Speicherort des Skripts aus, nicht vom aktuellen Verzeichnis.

```bash
export CIQ_SDK_HOME=~/connectiq-sdk          # Ordner mit bin/monkeyc
export CIQ_DEVELOPER_KEY=~/.Garmin/ConnectIQ/developer_key.der

scripts/test.sh                              # pytest, ohne Netz
scripts/build.sh                             # jedes Produkt im Manifest
scripts/build.sh fenix7                      # ein Gerät
scripts/export.sh                            # signiertes export/DailyVerse.iq
```

Geräte-Definitionen kommen aus dem Connect IQ SDK Manager (`~/.Garmin/ConnectIQ/Devices`). In CI lädt `scripts/fetch_devices.sh` dieselben Ordner aus öffentlichen Spiegeln. Den Schlüssel nie committen; für den Store muss es immer derselbe Schlüssel bleiben.

Launcher-Icons liegen größenrichtig unter `resources/drawables` (40 px) und `resources-icon-*`. Neu zeichnen: `python3 tools/gen_icons.py`. Die Connect-Settings erzeugt `python3 tools/gen_settings.py` aus `Translations.mc`.

Vorlage für den Store-Upload: [`release/connectiq/BUILD_INFO.md`](release/connectiq/BUILD_INFO.md). Texte und Bilder: [`store/`](store/) — Listings EN (Master) + DE + FR; Screenshots zeigen die **englische** UI (siehe [`store/README.md`](store/README.md)).

### Auf die Uhr

- Sideload der `.prg` über Garmin Express / Connect IQ App, **oder**
- `scripts/export.sh` und Upload der `.iq` in den Connect IQ Store.

### Simulator-Hinweise

- Background Temporal Events und `requestApplicationWake` im Simulator testen (Connect IQ Simulator → Timing / Background).
- `makeWebRequest` benötigt simulierte Internetverbindung.

---

## Tests & CI

Ohne Garmin SDK prüft die GitHub Actions Pipeline (`.github/workflows/ci.yml`) die logikkritischen Teile:

| Suite | Inhalt |
| --- | --- |
| `tests/test_verse_parse.py` | Parser für Plaintext/HTML/JS-Antworten |
| `tests/test_random_translation.py` | stabile Zufalls-Übersetzung pro Tag |
| `tests/test_reminder_schedule.py` | nächste Erinnerungszeit, Due-Guard, Zürich UTC+2 09:00≠11:00, 14:07/22:36 über Tage, Settings-Wechsel |
| `tests/test_translation_filter.py` | Sprach→Übersetzungs-Filter / Default-Fallback |
| `tests/test_catalog_consistency.py` | `Translations.mc` ↔ Settings ↔ Strings |
| `tests/test_string_parity.py` | String-IDs EN ↔ DEU ↔ FRE identisch |
| `tests/test_manifest.py` | Manifest, Permissions, Background-Invarianten |
| `tests/test_project_structure.py` | Pflicht-Dateien & Doku-Hinweise |

Lokal:

```bash
python3 -m pip install -r requirements-dev.txt
pytest                 # Offline-Unit-/Konsistenztests
pytest -m network      # optionaler Live-Call gegen DailyVerses.net
python3 tools/verify_verse_parse.py   # Legacy-Smoke
```

Die CI führt zuerst `pytest -m "not network"` aus (muss grün sein) und danach den Network-Smoke mit `continue-on-error` (Upstream-Ausfälle blockieren den Build nicht). Ein zweiter Job lädt SDK 9.2.0 und kompiliert jedes Produkt im Manifest.

### Auto-Merge

Workflow [`.github/workflows/auto-merge.yml`](.github/workflows/auto-merge.yml):

- Läuft nach erfolgreicher **CI**-Workflow-Ausführung
- Squash-merged offene, **nicht-draft** PRs gegen `main`, deren Head-SHA dem grünen CI-Lauf entspricht
- Draft-PRs werden übersprungen (zuerst „Ready for review“)

---

## UX-Hinweise

- Dunkler Teal-Hintergrund, warmer Akzent für die Bibelstelle – lesbar und OLED-schonend.
- Eine Hauptansicht: Vers, Referenz, Übersetzungskürzel.
- Keine Dashboard-Karten, keine Badges auf dem Vers.
- Round-Layouts unter `resources-round-*` für unterschiedliche Displaygrößen.

---

## Troubleshooting

| Problem | Lösung |
| --- | --- |
| Vers lädt nicht | Telefon verbinden, Garmin Connect geöffnet, Internet aktiv; Menü → Aktualisieren |
| Keine Erinnerung | Mindestens einen Slot aktivieren; App einmal öffnen (registriert TemporalEvent); Background-Berechtigung |
| Erinnerung zur falschen Stunde | Zeiten sind lokale Uhrzeit der Uhr; nach Zeitzonen-/DST-Wechsel App einmal öffnen. Plattform kann um wenige Minuten verzögern (5‑Min-Regel / Wake-Latenz) |
| Falsche Übersetzung | On-device nur Codes der Sprache; in Connect ggf. Default nach Sprachwechsel prüfen |
| Alter Vers | Datum gewechselt? Cache gilt pro Tag; „Aktualisieren“ erzwingen |
| Ablehnen öffnet nichts | Erwartetes Verhalten |

---

## Dokumentation pflegen

Bei Änderungen an Verhalten, API, Einstellungen, Geräte-Matrix oder Architektur:

1. **`README.md`** aktualisieren (Nutzer- und Entwicklersicht)
2. **`AGENTS.md`** aktualisieren (Invarianten, Dateizuordnung, Agent-Regeln)

Details und Checkliste: [`AGENTS.md`](AGENTS.md).

---

## Lizenz & Quellen

- App-Code: [MIT](LICENSE), Copyright Christof Rosentreter.
- Die Verstexte lädt die App von [DailyVerses.net](https://dailyverses.net/). Die Bibelübersetzungen bleiben urheberrechtlich bei den jeweiligen Rechteinhabern.
