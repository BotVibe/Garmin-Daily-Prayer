# Changelog

All notable changes to Daily Verse are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses [semantic versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Watch UI and Connect settings follow the watch language: **English** (default `resources`), **German** (`resources-deu`), **French** (`resources-fre`). Removed `resources-eng`; English no longer falls back to German on non-English watches.
- Store listings exist in English (master), German, and French; store screenshots show the English UI.

## [1.1.0] - 2026-10-23

### Fixed

- Reminder times now fire at the configured **local** watch clock time (time zone + DST). Scheduling no longer feeds local hour/minute into `Gregorian.moment` (UTC), which caused ~1–2 hour skew (e.g. 09:00 → ~10:00 in CET, **09:00 → 11:00 in CEST / Zurich UTC+2**). The remaining minutes of delay come from the platform 5-minute temporal-event rule / wake latency. Scheduling also respects `Background.getLastTemporalEventTime`.
- Temporal events that are **not** near an enabled reminder no longer show Accept/Decline (`isReminderDueNow`). Removed the fallback that registered a non-slot “now+5 min” event (that could wake the user at a random time). Disabled slots are ignored entirely; their stored HH:MM never fire.
- Long verse references wrap to multiple lines (text-area sized to the screen) instead of truncating on round displays.
- On-device translation menu stays filtered to the selected language; invalid pairs after a language change (or from Connect Mobile) fall back to that language’s default. Connect Mobile still cannot filter lists dynamically — documented and validated on the watch.

### Changed

- Reminder time editing uses a two-column hour∶minute wheel picker (`WatchUi.Picker`) instead of separate hour/minute lists.
- Tapping / Select on the verse screen no longer exits the app; only Back returns to the watch face. Tap re-triggers the backlight where `Attention.backlight` is available (OLED devices may refuse continuous hold after ~1 minute).

### Reminder behaviour (guaranteed)

- Each **enabled** slot fires once per local calendar day at its HH:MM (watch clock), until changed.
- Disabled slots never fire. All disabled → no TemporalEvent / no wakes.
- No catch-up or duplicate wakes from app start, settings sync, phone reconnect, or non-due background runs. Background does not fetch verses and never alerts outside a due window (~15 min around the slot, covering the 5‑min platform rule + OS lag).
- Expected precision: typically within a few minutes of the set minute; up to ~5 minutes late when the 5‑minute temporal rule applies, plus ordinary wake latency.

## [1.0.0] - 2026-10-11

First public Connect IQ Store release. Price: free.

### Added

- Verse of the day, loaded from DailyVerses.net and shown when the app is opened.
- Up to three reminder times. The watch asks whether to show the verse; declining leaves the watch face as it is, and the next reminder is still scheduled.
- Choice of language and Bible translation, including one translation picked for the day and kept stable until midnight.
- German and English interface. The app name is Daily Verse in both.
- The verse is kept for the day. With no phone connection the last stored verse is shown.
- Long verses step down in type size so the whole text stays on screen.
