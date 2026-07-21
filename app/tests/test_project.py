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
            "cutout_path": "H:/.vidmake-cache/masks/mask-cutout.png",
            "mask_center_x": 0.42,
            "mask_center_y": 0.37,
            "mask_bounds": {"min_x": 0.2, "min_y": 0.1, "max_x": 0.7, "max_y": 0.8},
        }
    ]

    validated = validate_project(project)

    assert validated["mask_layers"][0]["key_color"] == "#00ff00"
    assert validated["mask_layers"][0]["cutout_path"].endswith("mask-cutout.png")
    assert validated["mask_layers"][0]["mask_center_x"] == 0.42
    assert validated["mask_layers"][0]["mask_bounds"]["max_y"] == 0.8


def test_validate_project_preserves_zoom_blur_effect_layers() -> None:
    project = empty_project()
    project["effect_layers"] = [
        {
            "id": "effect-1",
            "name": "Zoom blur",
            "plugin": "builtin.zoom_blur",
            "source_visual_name": "clip.mp4",
            "source_visual_path": "H:/media/clip.mp4",
            "trigger_mode": "keyframes",
            "keyframe_layer_id": "audio-keyframes-1",
            "mask_mode": "mask",
            "mask_layer_id": "mask-1",
            "trigger_interval_seconds": 0.5,
            "blur_strength": 0.4,
            "zoom_amount": 1.18,
        }
    ]

    validated = validate_project(project)

    assert validated["effect_layers"][0]["plugin"] == "builtin.zoom_blur"
    assert validated["effect_layers"][0]["trigger_mode"] == "keyframes"
    assert validated["effect_layers"][0]["keyframe_layer_id"] == "audio-keyframes-1"
    assert validated["effect_layers"][0]["mask_mode"] == "mask"
    assert validated["effect_layers"][0]["mask_layer_id"] == "mask-1"
    assert validated["effect_layers"][0]["zoom_amount"] == 1.18


def test_validate_project_preserves_color_spread_effect_layers() -> None:
    project = empty_project()
    project["effect_layers"] = [
        {
            "id": "effect-2",
            "name": "Color spread",
            "plugin": "builtin.color_spread",
            "source_visual_name": "clip.mp4",
            "source_visual_path": "H:/media/clip.mp4",
            "trigger_mode": "interval",
            "keyframe_layer_id": "",
            "mask_mode": "mask",
            "mask_layer_id": "mask-1",
            "trigger_interval_seconds": 0.75,
            "spread_duration_seconds": 0.9,
            "color_1": "#00c8ff",
            "color_2": "#ff4fd8",
        }
    ]

    validated = validate_project(project)

    assert validated["effect_layers"][0]["plugin"] == "builtin.color_spread"
    assert validated["effect_layers"][0]["mask_mode"] == "mask"
    assert validated["effect_layers"][0]["mask_layer_id"] == "mask-1"
    assert validated["effect_layers"][0]["color_1"] == "#00c8ff"
    assert validated["effect_layers"][0]["color_2"] == "#ff4fd8"
