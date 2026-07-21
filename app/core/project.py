from __future__ import annotations

import json
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any


FORMAT_VERSION = 1
SUPPORTED_RESOLUTIONS = {(1080, 1920), (1920, 1080)}


def _is_hex_color(value: str) -> bool:
    if len(value) != 7 or not value.startswith("#"):
        return False
    try:
        int(value[1:], 16)
    except ValueError:
        return False
    return True


def _frame_mask_centers_from_cutout_frames(frames_path: str) -> list[dict[str, float | int]]:
    path = Path(frames_path)
    if not path.is_dir():
        return []
    try:
        import imageio.v3 as iio
        import numpy as np
    except ImportError:
        return []

    centers: list[dict[str, float | int]] = []
    for index, frame_path in enumerate(sorted(path.glob("frame_*.png"))):
        try:
            frame = iio.imread(frame_path)
        except Exception:
            continue
        if frame.ndim < 3 or frame.shape[2] < 4:
            continue
        alpha = frame[:, :, 3]
        height, width = alpha.shape[:2]
        ys, xs = np.nonzero(alpha > 0)
        if len(xs) > 0 and width > 0 and height > 0:
            centers.append(
                {
                    "frame": index,
                    "center_x": float(xs.mean() / max(1, width - 1)),
                    "center_y": float(ys.mean() / max(1, height - 1)),
                    "weight": int(len(xs)),
                }
            )
        else:
            centers.append({"frame": index, "center_x": 0.5, "center_y": 0.5, "weight": 0})
    return centers


@dataclass(frozen=True)
class ProjectSettings:
    width: int = 1080
    height: int = 1920
    frame_rate: int = 30
    duration: float = 15.0


@dataclass(frozen=True)
class ProjectAsset:
    name: str
    kind: str
    path: str
    loop: bool = False


@dataclass(frozen=True)
class AudioKeyframeLayer:
    id: str
    name: str
    source_audio_name: str
    source_audio_path: str
    band_name: str
    low_hz: float
    high_hz: float
    keyframes: list[dict[str, float | int]]


@dataclass(frozen=True)
class MaskLayer:
    id: str
    name: str
    source_video_name: str
    source_video_path: str
    source_type: str
    key_color: str
    tolerance: float
    inverted: bool
    preview_path: str
    cutout_path: str
    cutout_frames_path: str
    frame_rate: float
    frame_count: int
    frame_mask_centers: list[dict[str, float | int]] = field(default_factory=list)


@dataclass(frozen=True)
class EffectLayer:
    id: str
    name: str
    plugin: str
    source_visual_name: str
    source_visual_path: str
    trigger_mode: str
    keyframe_layer_id: str
    mask_mode: str
    mask_layer_id: str
    trigger_interval_seconds: float
    blur_strength: float
    zoom_amount: float
    color_1: str
    color_2: str
    spread_duration_seconds: float
    spread_cutoff_seconds: float
    finish_spread: bool


@dataclass(frozen=True)
class Project:
    format_version: int = FORMAT_VERSION
    settings: ProjectSettings = field(default_factory=ProjectSettings)
    assets: list[ProjectAsset] = field(default_factory=list)
    audio_keyframe_layers: list[AudioKeyframeLayer] = field(default_factory=list)
    mask_layers: list[MaskLayer] = field(default_factory=list)
    effect_layers: list[EffectLayer] = field(default_factory=list)


def empty_project() -> dict[str, Any]:
    return asdict(Project())


def validate_project(data: Any) -> dict[str, Any]:
    if not isinstance(data, dict):
        raise ValueError("Project file must contain a JSON object.")

    format_version = data.get("format_version")
    if format_version != FORMAT_VERSION:
        raise ValueError(f"Unsupported project format version: {format_version!r}.")

    settings = data.get("settings", {})
    if not isinstance(settings, dict):
        raise ValueError("Project settings must be an object.")

    assets = data.get("assets", [])
    if not isinstance(assets, list):
        raise ValueError("Project assets must be a list.")

    audio_keyframe_layers = data.get("audio_keyframe_layers", [])
    if not isinstance(audio_keyframe_layers, list):
        raise ValueError("Project audio keyframe layers must be a list.")

    mask_layers = data.get("mask_layers", [])
    if not isinstance(mask_layers, list):
        raise ValueError("Project mask layers must be a list.")

    effect_layers = data.get("effect_layers", [])
    if not isinstance(effect_layers, list):
        raise ValueError("Project effect layers must be a list.")

    validated_assets: list[dict[str, Any]] = []
    for index, asset in enumerate(assets):
        if not isinstance(asset, dict):
            raise ValueError(f"Asset #{index + 1} must be an object.")
        kind = asset.get("kind")
        name = asset.get("name")
        path = asset.get("path")
        if kind not in {"Audio", "Visual"}:
            raise ValueError(f"Asset #{index + 1} has an unsupported kind.")
        if not isinstance(name, str) or not name:
            raise ValueError(f"Asset #{index + 1} is missing a name.")
        if not isinstance(path, str) or not path:
            raise ValueError(f"Asset #{index + 1} is missing a path.")
        validated_assets.append({"name": name, "kind": kind, "path": path, "loop": bool(asset.get("loop", False))})

    validated_keyframe_layers: list[dict[str, Any]] = []
    for index, layer in enumerate(audio_keyframe_layers):
        if not isinstance(layer, dict):
            raise ValueError(f"Audio keyframe layer #{index + 1} must be an object.")
        layer_id = layer.get("id")
        name = layer.get("name")
        source_audio_name = layer.get("source_audio_name")
        source_audio_path = layer.get("source_audio_path")
        band_name = layer.get("band_name")
        keyframes = layer.get("keyframes", [])
        if not isinstance(layer_id, str) or not layer_id:
            raise ValueError(f"Audio keyframe layer #{index + 1} is missing an id.")
        if not isinstance(name, str) or not name:
            raise ValueError(f"Audio keyframe layer #{index + 1} is missing a name.")
        if not isinstance(source_audio_name, str):
            raise ValueError(f"Audio keyframe layer #{index + 1} has an invalid source audio name.")
        if not isinstance(source_audio_path, str) or not source_audio_path:
            raise ValueError(f"Audio keyframe layer #{index + 1} is missing a source audio path.")
        if not isinstance(band_name, str) or not band_name:
            raise ValueError(f"Audio keyframe layer #{index + 1} is missing a band name.")
        if not isinstance(keyframes, list):
            raise ValueError(f"Audio keyframe layer #{index + 1} keyframes must be a list.")

        validated_keyframes: list[dict[str, float | int]] = []
        for keyframe_index, keyframe in enumerate(keyframes):
            if not isinstance(keyframe, dict):
                raise ValueError(
                    f"Audio keyframe layer #{index + 1} keyframe #{keyframe_index + 1} must be an object."
                )
            validated_keyframes.append(
                {
                    "time_seconds": float(keyframe.get("time_seconds", 0.0)),
                    "frame_number": int(keyframe.get("frame_number", 0)),
                    "value": float(keyframe.get("value", keyframe.get("strength", 1.0))),
                }
            )

        validated_keyframe_layers.append(
            {
                "id": layer_id,
                "name": name,
                "source_audio_name": source_audio_name,
                "source_audio_path": source_audio_path,
                "band_name": band_name,
                "low_hz": float(layer.get("low_hz", 0.0)),
                "high_hz": float(layer.get("high_hz", 0.0)),
                "keyframes": validated_keyframes,
            }
        )

    validated_mask_layers: list[dict[str, Any]] = []
    for index, layer in enumerate(mask_layers):
        if not isinstance(layer, dict):
            raise ValueError(f"Mask layer #{index + 1} must be an object.")
        layer_id = layer.get("id")
        name = layer.get("name")
        source_video_name = layer.get("source_video_name")
        source_video_path = layer.get("source_video_path")
        source_type = layer.get("source_type", "video")
        key_color = layer.get("key_color")
        preview_path = layer.get("preview_path", "")
        cutout_path = layer.get("cutout_path", "")
        cutout_frames_path = layer.get("cutout_frames_path", "")
        if not isinstance(layer_id, str) or not layer_id:
            raise ValueError(f"Mask layer #{index + 1} is missing an id.")
        if not isinstance(name, str) or not name:
            raise ValueError(f"Mask layer #{index + 1} is missing a name.")
        if not isinstance(source_video_name, str):
            raise ValueError(f"Mask layer #{index + 1} has an invalid source video name.")
        if not isinstance(source_video_path, str) or not source_video_path:
            raise ValueError(f"Mask layer #{index + 1} is missing a source video path.")
        if source_type not in {"image", "video"}:
            raise ValueError(f"Mask layer #{index + 1} has an invalid source type.")
        if not isinstance(key_color, str) or not key_color.startswith("#"):
            raise ValueError(f"Mask layer #{index + 1} has an invalid chroma key color.")
        mask_bounds = layer.get("mask_bounds", {})
        if not isinstance(mask_bounds, dict):
            mask_bounds = {}
        frame_mask_centers = layer.get("frame_mask_centers", [])
        if not isinstance(frame_mask_centers, list):
            frame_mask_centers = []
        if not frame_mask_centers and str(cutout_frames_path):
            frame_mask_centers = _frame_mask_centers_from_cutout_frames(str(cutout_frames_path))
        validated_frame_mask_centers: list[dict[str, float | int]] = []
        for center in frame_mask_centers:
            if not isinstance(center, dict):
                continue
            validated_frame_mask_centers.append(
                {
                    "frame": int(center.get("frame", len(validated_frame_mask_centers))),
                    "center_x": float(center.get("center_x", layer.get("mask_center_x", 0.5))),
                    "center_y": float(center.get("center_y", layer.get("mask_center_y", 0.5))),
                    "weight": int(center.get("weight", 0)),
                }
            )
        validated_mask_layers.append(
            {
                "id": layer_id,
                "name": name,
                "source_video_name": source_video_name,
                "source_video_path": source_video_path,
                "source_type": source_type,
                "key_color": key_color,
                "tolerance": float(layer.get("tolerance", 0.28)),
                "inverted": bool(layer.get("inverted", False)),
                "preview_path": str(preview_path),
                "cutout_path": str(cutout_path),
                "cutout_frames_path": str(cutout_frames_path),
                "frame_rate": float(layer.get("frame_rate", 0.0)),
                "frame_count": int(layer.get("frame_count", 0)),
                "frame_mask_centers": validated_frame_mask_centers,
                "mask_center_x": float(layer.get("mask_center_x", 0.5)),
                "mask_center_y": float(layer.get("mask_center_y", 0.5)),
                "mask_bounds": {
                    "min_x": float(mask_bounds.get("min_x", 0.0)),
                    "min_y": float(mask_bounds.get("min_y", 0.0)),
                    "max_x": float(mask_bounds.get("max_x", 1.0)),
                    "max_y": float(mask_bounds.get("max_y", 1.0)),
                },
            }
        )

    validated_effect_layers: list[dict[str, Any]] = []
    for index, layer in enumerate(effect_layers):
        if not isinstance(layer, dict):
            raise ValueError(f"Effect layer #{index + 1} must be an object.")
        layer_id = layer.get("id")
        name = layer.get("name")
        plugin = layer.get("plugin")
        source_visual_name = layer.get("source_visual_name")
        source_visual_path = layer.get("source_visual_path")
        if not isinstance(layer_id, str) or not layer_id:
            raise ValueError(f"Effect layer #{index + 1} is missing an id.")
        if not isinstance(name, str) or not name:
            raise ValueError(f"Effect layer #{index + 1} is missing a name.")
        if plugin not in {"builtin.zoom_blur", "builtin.color_spread", "builtin.chroma_key_remove"}:
            raise ValueError(f"Effect layer #{index + 1} has an unsupported plugin.")
        if not isinstance(source_visual_name, str):
            raise ValueError(f"Effect layer #{index + 1} has an invalid source visual name.")
        if not isinstance(source_visual_path, str) or not source_visual_path:
            raise ValueError(f"Effect layer #{index + 1} is missing a source visual path.")
        trigger_mode = str(layer.get("trigger_mode", "interval"))
        if trigger_mode not in {"interval", "keyframes"}:
            raise ValueError(f"Effect layer #{index + 1} has an invalid trigger mode.")
        if plugin == "builtin.chroma_key_remove":
            trigger_mode = "interval"
        keyframe_layer_id = str(layer.get("keyframe_layer_id", ""))
        if trigger_mode == "keyframes" and not keyframe_layer_id:
            raise ValueError(f"Effect layer #{index + 1} must reference an audio keyframe layer.")
        mask_mode = str(layer.get("mask_mode", "none"))
        if plugin in {"builtin.color_spread", "builtin.chroma_key_remove"}:
            mask_mode = "mask"
        if mask_mode not in {"none", "mask"}:
            raise ValueError(f"Effect layer #{index + 1} has an invalid mask mode.")
        mask_layer_id = str(layer.get("mask_layer_id", ""))
        if mask_mode == "mask" and not mask_layer_id:
            raise ValueError(f"Effect layer #{index + 1} must reference a mask layer.")
        color_1 = str(layer.get("color_1", "#00c8ff"))
        color_2 = str(layer.get("color_2", "#ff4fd8"))
        if plugin == "builtin.color_spread" and (not _is_hex_color(color_1) or not _is_hex_color(color_2)):
            raise ValueError(f"Effect layer #{index + 1} has an invalid color spread color.")

        validated_effect_layers.append(
            {
                "id": layer_id,
                "name": name,
                "plugin": plugin,
                "source_visual_name": source_visual_name,
                "source_visual_path": source_visual_path,
                "trigger_mode": trigger_mode,
                "keyframe_layer_id": keyframe_layer_id,
                "mask_mode": mask_mode,
                "mask_layer_id": mask_layer_id,
                "trigger_interval_seconds": max(0.05, float(layer.get("trigger_interval_seconds", 1.0))),
                "blur_strength": max(0.0, float(layer.get("blur_strength", 0.35))),
                "zoom_amount": max(1.0, float(layer.get("zoom_amount", 1.12))),
                "color_1": color_1,
                "color_2": color_2,
                "spread_duration_seconds": max(0.05, float(layer.get("spread_duration_seconds", 0.8))),
                "spread_cutoff_seconds": max(
                    0.05,
                    float(layer.get("spread_cutoff_seconds", layer.get("spread_duration_seconds", 0.8))),
                ),
                "finish_spread": bool(layer.get("finish_spread", False)),
            }
        )

    width = int(settings.get("width", 1080))
    height = int(settings.get("height", 1920))
    if (width, height) not in SUPPORTED_RESOLUTIONS:
        raise ValueError(f"Unsupported project resolution: {width}x{height}.")

    return {
        "format_version": FORMAT_VERSION,
        "settings": {
            "width": width,
            "height": height,
            "frame_rate": int(settings.get("frame_rate", 30)),
            "duration": float(settings.get("duration", 15.0)),
        },
        "assets": validated_assets,
        "audio_keyframe_layers": validated_keyframe_layers,
        "mask_layers": validated_mask_layers,
        "effect_layers": validated_effect_layers,
    }


def load_project(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise ValueError(f"Project file is not valid JSON: {error}") from error
    return validate_project(data)


def save_project(path: Path, data: dict[str, Any]) -> Path:
    validated = validate_project(data)
    target = path if path.suffix else path.with_suffix(".vidmake")
    target.write_text(
        json.dumps(validated, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return target
