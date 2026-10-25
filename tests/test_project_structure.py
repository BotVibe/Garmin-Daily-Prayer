from __future__ import annotations

import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

REQUIRED_FILES = [
    "README.md",
    "AGENTS.md",
    "manifest.xml",
    "monkey.jungle",
    "source/DailyVerseApp.mc",
    "source/BackgroundService.mc",
    "source/ReminderScheduler.mc",
    "source/VerseApi.mc",
    "source/VerseCache.mc",
    "source/VerseView.mc",
    "source/VerseScroll.mc",
    "source/SettingsMenu.mc",
    "source/Translations.mc",
    "source/AppConfig.mc",
    "resources/properties/properties.xml",
    "resources/settings/settings.xml",
    "resources/strings/strings.xml",
    "resources-deu/strings/strings.xml",
    "resources-fre/strings/strings.xml",
    "resources/layouts/verse.xml",
    "resources/drawables/launcher_icon.png",
    ".github/workflows/ci.yml",
    ".github/workflows/auto-merge.yml",
    "LICENSE",
    "CHANGELOG.md",
    "scripts/build.sh",
    "scripts/test.sh",
    "scripts/export.sh",
    "scripts/fetch_devices.sh",
    "release/connectiq/BUILD_INFO.md",
    "store/listing-de.md",
    "store/listing-en.md",
    "store/listing-fr.md",
    "store/README.md",
    "store/privacy-de.md",
    "store/privacy-en.md",
    "store/assets/store_icon_500.png",
    "store/assets/screenshots/01-verse-en.png",
]


def test_required_project_files_exist() -> None:
    missing = [rel for rel in REQUIRED_FILES if not (ROOT / rel).exists()]
    assert not missing, f"Missing required files: {missing}"


def test_app_name_and_version_are_consistent() -> None:
    for rel in (
        "resources/strings/strings.xml",
        "resources-deu/strings/strings.xml",
        "resources-fre/strings/strings.xml",
    ):
        root = ET.parse(ROOT / rel).getroot()
        strings = {el.attrib["id"]: (el.text or "") for el in root.findall("string")}
        assert strings["AppName"] == "Daily Verse", rel
        assert strings["AppVersion"] == "1.1.0", rel
    props = ET.parse(ROOT / "resources/properties/properties.xml").getroot()
    version = next(el for el in props.findall("property") if el.attrib["id"] == "appVersion")
    assert (version.text or "").strip() == "1.1.0"
    changelog = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
    assert "## [1.1.0]" in changelog
    assert "## [1.0.0]" in changelog


def test_store_listing_basics() -> None:
    for rel in ("store/listing-de.md", "store/listing-en.md", "store/listing-fr.md"):
        text = (ROOT / rel).read_text(encoding="utf-8")
        assert "Daily Verse" in text
        assert "https://github.com/BotVibe/Garmin-Daily-Prayer/issues" in text
        assert "https://dailyverses.net/" in text
    german = (ROOT / "store/listing-de.md").read_text(encoding="utf-8")
    assert "Bibelvers des Tages" in german
    french = (ROOT / "store/listing-fr.md").read_text(encoding="utf-8")
    assert "verset biblique du jour" in french
    shots = list((ROOT / "store/assets/screenshots").glob("*.png"))
    assert len(shots) >= 4
    assert (ROOT / "store/assets/screenshots/01-verse-en.png").is_file()


def test_short_descriptions_fit_the_store_field() -> None:
    """The Connect IQ short description field allows 255 characters."""
    import re

    for rel in ("store/listing-de.md", "store/listing-en.md", "store/listing-fr.md"):
        text = (ROOT / rel).read_text(encoding="utf-8")
        match = re.search(
            r"## Kurzbeschreibung\n\n(.+)\n"
            r"|## Short description\n\n(.+)\n"
            r"|## Description courte\n\n(.+)\n",
            text,
        )
        assert match, rel
        short = match.group(1) or match.group(2) or match.group(3)
        assert len(short) <= 255, f"{rel} short description is {len(short)} characters"


def test_readme_and_agents_mention_ci() -> None:
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    agents = (ROOT / "AGENTS.md").read_text(encoding="utf-8")
    assert "GitHub Actions" in readme or "CI" in readme
    assert "pytest" in readme.lower() or "tests/" in readme
    assert "pytest" in agents.lower() or "tests/" in agents
