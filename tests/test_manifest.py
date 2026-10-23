from __future__ import annotations

import re
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NS = {"iq": "http://www.garmin.com/xml/connectiq"}


def test_manifest_is_watch_app_with_required_permissions() -> None:
    tree = ET.parse(ROOT / "manifest.xml")
    app = tree.getroot().find("iq:application", NS)
    assert app is not None
    assert app.attrib.get("type") == "watch-app"
    assert app.attrib.get("entry") == "DailyVerseApp"
    assert app.attrib.get("minApiLevel") == "4.0.0"

    perms = {
        p.attrib.get("id")
        for p in app.findall("iq:permissions/iq:uses-permission", NS)
    }
    assert "Communications" in perms
    assert "Background" in perms


def test_manifest_has_modern_round_products() -> None:
    tree = ET.parse(ROOT / "manifest.xml")
    products = [
        p.attrib["id"]
        for p in tree.getroot().findall("iq:application/iq:products/iq:product", NS)
    ]
    assert products
    assert len(products) == len(set(products))
    for required in ("fenix7", "fr255", "venu2", "epix2"):
        assert required in products


def test_monkey_jungle_points_at_manifest_and_source() -> None:
    jungle = (ROOT / "monkey.jungle").read_text(encoding="utf-8")
    assert "project.manifest = manifest.xml" in jungle
    assert "base.sourcePath = source" in jungle
    assert "base.resourcePath = resources" in jungle


def test_background_modules_are_annotated() -> None:
    required = {
        "BackgroundService.mc": "class BackgroundService",
        "ReminderScheduler.mc": "module ReminderScheduler",
        "AppConfig.mc": "module AppConfig",
        "Translations.mc": "module Translations",
        "VerseCache.mc": "module VerseCache",
    }
    for filename, needle in required.items():
        text = (ROOT / "source" / filename).read_text(encoding="utf-8")
        assert "(:background)" in text, f"{filename} missing (:background)"
        assert needle in text


def test_no_watchui_import_in_background_modules() -> None:
    for filename in (
        "BackgroundService.mc",
        "ReminderScheduler.mc",
        "AppConfig.mc",
        "Translations.mc",
        "VerseCache.mc",
    ):
        text = (ROOT / "source" / filename).read_text(encoding="utf-8")
        assert "Toybox.WatchUi" not in text, f"{filename} must not import WatchUi"


def test_verse_view_exits_on_back_not_select() -> None:
    text = (ROOT / "source" / "VerseView.mc").read_text(encoding="utf-8")
    assert re.search(r"function onBack\(\)[\s\S]*?dismiss\(\)", text)
    assert "System.exit()" in text
    # Select / tap must keep the screen lit, not leave the app.
    select = re.search(
        r"function onSelect\(\) as Boolean \{([\s\S]*?)\n    \}",
        text,
    )
    assert select is not None
    assert "dismiss()" not in select.group(1)
    assert "System.exit()" not in select.group(1)
    assert "keepLit()" in select.group(1) or "pokeBacklight()" in select.group(1)
    assert "Attention has :backlight" in text


def test_reminder_scheduler_uses_local_clock_not_utc_moment() -> None:
    text = (ROOT / "source" / "ReminderScheduler.mc").read_text(encoding="utf-8")
    assert "momentForLocalClock" in text
    assert "getLastTemporalEventTime" in text
    # Must not call Gregorian.moment(...) with local HH:MM (UTC options).
    assert not re.search(r"Gregorian\.moment\s*\(", text)


def test_settings_menu_filters_translations_and_uses_time_picker() -> None:
    text = (ROOT / "source" / "SettingsMenu.mc").read_text(encoding="utf-8")
    assert "Translations.codesForLanguage(lang)" in text
    assert "SlotTimePicker" in text
    assert "NumberFactory" in text
    assert "class NumberPickMenu" not in text
