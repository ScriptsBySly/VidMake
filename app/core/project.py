from __future__ import annotations

import json
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any


FORMAT_VERSION = 1
SUPPORTED_RESOLUTIONS = {(1080, 1920), (1920, 1080)}


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


@dataclass(frozen=True)
class Project:
    format_version: int = FORMAT_VERSION
    settings: ProjectSettings = field(default_factory=ProjectSettings)
    assets: list[ProjectAsset] = field(default_factory=list)


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

    validated_assets: list[dict[str, str]] = []
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
        validated_assets.append({"name": name, "kind": kind, "path": path})

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
