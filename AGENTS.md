# AGENTS.md — Spruch des Tages (Garmin Connect IQ)

Anweisungen für Menschen und Coding-Agents, die an diesem Repository arbeiten.

---

## Projektzweck

Connect IQ **watch-app**, die:

- den **Spruch des Tages** von DailyVerses.net lädt,
- zu bis zu **3** konfigurierbaren Uhrzeiten per `requestApplicationWake` fragt (Annehmen/Ablehnen),
- bei Annehmen den Vers zeigt und bei Ablehnen nichts tut,
- den Vers auch **manuell** aus dem Apps-Menü zeigt,
- Sprache + Bibelübersetzung (inkl. zufällig pro Sprache) einstellen lässt,
- **energieeffizient** arbeitet (kein Polling, Tages-Cache, ein TemporalEvent).

UI-Default: **Deutsch**. Zweite UI-Sprache: Englisch (`resources-eng`).

---

## Harte Invarianten

1. **App-Typ bleibt `watch-app`.** Kein Widget/Glance als Ersatz für den Wake-Flow (Widgets sind auf Zielgeräten oft abgekündigt; Wake braucht die App).
2. **Nur ein TemporalEvent.** Immer die *nächste* Slot-Zeit schedulen (`ReminderScheduler.scheduleNext`). Niemals Intervall-Polling für Erinnerungen.
3. **Ablehnen = Idle.** Kein automatisches erneutes Öffnen; nächste Erinnerung trotzdem planen (im Background vor/bei Wake).
4. **Zurück/Select in VerseView beendet die App** (`System.exit`) → normales Watchface.
5. **API:** Plaintext `https://dailyverses.net/get/verse?language=<code>`. Der Website-`verse.js`-Embed ist dokumentiert, aber nicht der Primärpfad.
6. **`language` Query-Param = Übersetzungscode** (z. B. `lut`), nicht ISO-Sprachcode. ISO liegt in Property `languageId`.
7. **`translationCode = random`:** stabile Tageswahl aus Codes der Sprache; Ergebnis cachen.
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
| UI Settings | `source/SettingsMenu.mc` |
| Strings | `resources/strings/strings.xml`, `resources-eng/strings/strings.xml` |
| Parser-Smoke | `tools/verify_verse_parse.py` |
| Docs | `README.md`, `AGENTS.md` |

### Background-Annotation

Alles, was der Background-Prozess lädt, muss mit `(:background)` markiert sein bzw. nur erlaubte APIs nutzen:

- `BackgroundService`, `ReminderScheduler`, `AppConfig`, `Translations`, `VerseCache`

Keine `WatchUi`-Abhängigkeiten im Background-Pfad.

---

## Einstellungen (Properties)

| Key | Typ | Bedeutung |
| --- | --- | --- |
| `languageId` | string | Katalog-Sprache (`de`, `en`, …) |
| `translationCode` | string | API-Code oder `random` |
| `slotNEnabled` | boolean | N = 1..3 |
| `slotNHour` | number | 0–23 |
| `slotNMinute` | number | 0–59 |

On-Device-Menüs sind die UX-Quelle der Wahrheit für kaskadierende Sprache→Übersetzung. Connect-Mobile-Settings spiegeln die Properties.

Nach Settings-Änderungen immer `ReminderScheduler.scheduleNext()` aufrufen.

---

## Wenn du X änderst → aktualisiere Y

| Änderung | Pflicht-Updates |
| --- | --- |
| Neue Sprache / Übersetzung | `Translations.mc`, `settings.xml`, Strings (`Lang_*`), **README** (Tabelle), **AGENTS** (falls Invariante/Katalogbeschreibung) |
| Erinnerungslogik / Slot-Anzahl | `AppConfig`, `ReminderScheduler`, `properties.xml`, `settings.xml`, Settings-UI, **README**, **AGENTS** |
| API-URL oder Parse-Format | `VerseApi.mc`, `tools/verify_verse_parse.py`, **README**, **AGENTS** |
| Neue Geräte | `manifest.xml`, **README** Geräte-Liste |
| UI-Flow (Exit, Menü, Wake) | Views/Delegates, **README** Nutzerfluss, **AGENTS** Invarianten |
| Default-Properties | `properties.xml`, **README** Defaults |

### Doc-Update-Checkliste (vor Commit)

- [ ] README beschreibt das aktuelle Nutzerverhalten korrekt
- [ ] README API-/Settings-/Geräte-Abschnitte stimmen
- [ ] AGENTS-Invarianten stimmen noch
- [ ] Dateizuordnung in AGENTS enthält neue wichtigen Dateien
- [ ] Keine veralteten Widget-/Polling-Hinweise

---

## Build / Test für Agents

- In dieser Cloud-Umgebung ist das **Garmin SDK typischerweise nicht installiert**. Liefere gültiges Monkey-C-Projekt; dokumentiere Build in README.
- Parser-Smoke ohne SDK:

  ```bash
  python3 tools/verify_verse_parse.py
  ```

- Manuelle Gerätetests (lokal): Simulator Background Wake, Accept/Decline, Offline-Cache, Sprachwechsel, Random-Übersetzung über Mitternacht.

### Bekannte CIQ-Fallen

- TemporalEvent: min. 5 Minuten; nur einer aktiv.
- `requestApplicationWake` + `Background.exit` im Background-Kontext; Schedule der nächsten Zeit **nicht** vom Accept abhängig machen.
- `makeWebRequest` braucht Phone-Link.
- Ungültige `<iq:product id>` im Manifest brechen den Build — nur dokumentierte Device-IDs.

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
4. `python3 tools/verify_verse_parse.py` wenn API/Parser betroffen.
5. Commit mit klarer Message, push, PR.

Bei Unklarheiten: Invarianten in diesem File haben Vorrang vor kosmetischen Refactors.
