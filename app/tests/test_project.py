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


def test_validate_project_accepts_horizontal_resolution() -> None:
    project = empty_project()
    project["settings"]["width"] = 1920
    project["settings"]["height"] = 1080

    validated = validate_project(project)

    assert validated["settings"]["width"] == 1920
    assert validated["settings"]["height"] == 1080


def test_validate_project_preserves_audio_keyframe_layers() -> None:
    project = empty_project()
    project["audio_keyframe_layers"] = [
        {
            "id": "audio-keyframes-1",
            "name": "Kick markers",
            "source_audio_name": "song.wav",
            "source_audio_path": "H:/media/song.wav",
            "band_name": "Kick / bass",
            "low_hz": 60,
            "high_hz": 160,
            "keyframes": [
                {"time_seconds": 0.5, "frame_number": 15, "value": 0.82},
            ],
        }
    ]

    validated = validate_project(project)

    assert validated["audio_keyframe_layers"][0]["keyframes"][0]["frame_number"] == 15


def test_validate_project_preserves_mask_layers() -> None:
    project = empty_project()
    project["mask_layers"] = [
        {
            "id": "mask-1",
            "name": "Green screen mask",
            "source_video_name": "clip.mp4",
            "source_video_path": "H:/media/clip.mp4",
            "source_type": "video",
            "key_color": "#00ff00",
            "tolerance": 0.28,
            "inverted": False,
            "preview_path": "H:/.vidmake-cache/masks/mask-preview.png",
        }
    ]

    validated = validate_project(project)

    assert validated["mask_layers"][0]["key_color"] == "#00ff00"
