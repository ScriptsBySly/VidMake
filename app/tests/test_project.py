from __future__ import annotations

import json

import pytest

from app.core.project import empty_project, load_project, save_project, validate_project


def test_empty_project_has_versioned_defaults() -> None:
    project = empty_project()

    assert project["format_version"] == 1
    assert project["settings"]["width"] == 1080
    assert project["settings"]["height"] == 1920
    assert project["assets"] == []


def test_save_and_load_project_round_trip(tmp_path) -> None:
    project = empty_project()
    project["assets"] = [
        {"name": "song.wav", "kind": "Audio", "path": "H:/media/song.wav"},
        {"name": "cover.png", "kind": "Visual", "path": "H:/media/cover.png"},
    ]

    saved_path = save_project(tmp_path / "demo", project)
    loaded = load_project(saved_path)

    assert saved_path.name == "demo.vidmake"
    assert loaded == project
    assert json.loads(saved_path.read_text(encoding="utf-8")) == project


def test_validate_project_rejects_unknown_asset_kind() -> None:
    project = empty_project()
    project["assets"] = [{"name": "notes.txt", "kind": "Text", "path": "notes.txt"}]

    with pytest.raises(ValueError, match="unsupported kind"):
        validate_project(project)
