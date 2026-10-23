# Changelog

All notable changes to Daily Verse are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses [semantic versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- Reminder times now fire at the configured **local** watch clock time (time zone + DST). Scheduling no longer feeds local hour/minute into `Gregorian.moment` (UTC), which caused ~1 hour skew (e.g. 09:00 → ~10:00 in CET); the remaining minutes of delay came from the platform 5-minute temporal-event rule / wake latency. Scheduling also respects `Background.getLastTemporalEventTime`.
- Long verse references wrap to multiple lines (text-area sized to the screen) instead of truncating on round displays.
- On-device translation menu stays filtered to the selected language; invalid pairs after a language change (or from Connect Mobile) fall back to that language’s default. Connect Mobile still cannot filter lists dynamically — documented and validated on the watch.

### Changed

- Reminder time editing uses a two-column hour∶minute wheel picker (`WatchUi.Picker`) instead of separate hour/minute lists.
- Tapping / Select on the verse screen no longer exits the app; only Back returns to the watch face. Tap re-triggers the backlight where `Attention.backlight` is available (OLED devices may refuse continuous hold after ~1 minute).

## [1.0.0] - 2026-10-11

First public Connect IQ Store release. Price: free.

### Added

- Verse of the day, loaded from DailyVerses.net and shown when the app is opened.
- Up to three reminder times. The watch asks whether to show the verse; declining leaves the watch face as it is, and the next reminder is still scheduled.
- Choice of language and Bible translation, including one translation picked for the day and kept stable until midnight.
- German and English interface. The app name is Daily Verse in both.
- The verse is kept for the day. With no phone connection the last stored verse is shown.
- Long verses step down in type size so the whole text stays on screen.
