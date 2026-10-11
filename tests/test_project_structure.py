from __future__ import annotations

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
    "source/SettingsMenu.mc",
    "source/Translations.mc",
    "source/AppConfig.mc",
    "resources/properties/properties.xml",
    "resources/settings/settings.xml",
    "resources/strings/strings.xml",
    "resources-eng/strings/strings.xml",
    "resources/layouts/verse.xml",
    "resources/drawables/launcher_icon.png",
    ".github/workflows/ci.yml",
    ".github/workflows/auto-merge.yml",
]


def test_required_project_files_exist() -> None:
    missing = [rel for rel in REQUIRED_FILES if not (ROOT / rel).exists()]
    assert not missing, f"Missing required files: {missing}"


def test_readme_and_agents_mention_ci() -> None:
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    agents = (ROOT / "AGENTS.md").read_text(encoding="utf-8")
    assert "GitHub Actions" in readme or "CI" in readme
    assert "pytest" in readme.lower() or "tests/" in readme
    assert "pytest" in agents.lower() or "tests/" in agents
