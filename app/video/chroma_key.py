from __future__ import annotations

import hashlib
import time
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

import numpy as np

IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".bmp"}
VIDEO_EXTENSIONS = {".mp4", ".mov", ".mkv", ".avi"}


@dataclass(frozen=True)
class ChromaKeySettings:
    key_color: str = "#00ff00"
    tolerance: float = 0.28
    inverted: bool = False
    preview_time_ms: int = 0


def settings_from_dict(data: dict[str, Any]) -> ChromaKeySettings:
    return ChromaKeySettings(
        key_color=str(data.get("key_color", "#00ff00")),
        tolerance=float(data.get("tolerance", 0.28)),
        inverted=bool(data.get("inverted", False)),
        preview_time_ms=int(data.get("preview_time_ms", 0)),
    )


def _hex_to_rgb(color: str) -> tuple[int, int, int]:
    normalized = color.strip().lstrip("#")
    if len(normalized) != 6:
        raise ValueError("Chroma key color must use #rrggbb format.")
    return (
        int(normalized[0:2], 16),
        int(normalized[2:4], 16),
        int(normalized[4:6], 16),
    )


def _rgb_to_hex(rgb: tuple[int, int, int]) -> str:
    return f"#{rgb[0]:02x}{rgb[1]:02x}{rgb[2]:02x}"


def _read_frame(path: Path, time_ms: int) -> tuple[np.ndarray, float, int, int, float, str]:
    try:
        import cv2
    except ImportError as error:
        raise RuntimeError(
            "Visual analysis requires opencv-python. Install dependencies with: pip install -r requirements.txt"
        ) from error

    if path.suffix.lower() in IMAGE_EXTENSIONS:
        frame_bgr = cv2.imread(str(path), cv2.IMREAD_COLOR)
        if frame_bgr is None:
            raise ValueError(f"Could not open image file: {path}")
        height, width = frame_bgr.shape[:2]
        return frame_bgr, 0.0, width, height, 0.0, "image"

    capture = cv2.VideoCapture(str(path))
    if not capture.isOpened():
        raise ValueError(f"Could not open video file: {path}")

    fps = float(capture.get(cv2.CAP_PROP_FPS) or 30.0)
    frame_count = int(capture.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
    width = int(capture.get(cv2.CAP_PROP_FRAME_WIDTH) or 0)
    height = int(capture.get(cv2.CAP_PROP_FRAME_HEIGHT) or 0)
    duration = frame_count / fps if fps > 0 and frame_count > 0 else 0.0

    capture.set(cv2.CAP_PROP_POS_MSEC, max(0, time_ms))
    ok, frame_bgr = capture.read()
    capture.release()
    if not ok or frame_bgr is None:
        raise ValueError("Could not read a frame from the selected video.")

    return frame_bgr, fps, width, height, duration, "video"


def sample_color(path: Path, time_ms: int, normalized_x: float, normalized_y: float) -> str:
    frame_bgr, _fps, width, height, _duration, _source_type = _read_frame(path, time_ms)
    x = max(0, min(width - 1, round(normalized_x * (width - 1))))
    y = max(0, min(height - 1, round(normalized_y * (height - 1))))
    b, g, r = frame_bgr[y, x]
    return _rgb_to_hex((int(r), int(g), int(b)))


def analyze_chroma_key(path: Path, settings: ChromaKeySettings, cache_root: Path) -> dict[str, Any]:
    try:
        import cv2
    except ImportError as error:
        raise RuntimeError(
            "Visual analysis requires opencv-python. Install dependencies with: pip install -r requirements.txt"
        ) from error

    if not path.exists():
        raise FileNotFoundError(f"Visual file does not exist: {path}")

    frame_bgr, fps, width, height, duration, source_type = _read_frame(path, settings.preview_time_ms)
    frame_rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB).astype(np.float32) / 255.0
    key_rgb = np.array(_hex_to_rgb(settings.key_color), dtype=np.float32) / 255.0

    distance = np.linalg.norm(frame_rgb - key_rgb, axis=2) / np.sqrt(3.0)
    mask = (distance > settings.tolerance).astype(np.uint8) * 255
    if settings.inverted:
        mask = 255 - mask

    cache_root.mkdir(parents=True, exist_ok=True)
    digest = hashlib.sha1(
        f"{path}|{path.stat().st_mtime_ns}|{settings}|{time.time_ns()}".encode("utf-8")
    ).hexdigest()[:16]
    preview_path = cache_root / f"mask-preview-{digest}.png"
    cv2.imwrite(str(preview_path), mask)

    kept_ratio = float(mask.mean() / 255.0)
    return {
        "source": str(path),
        "source_type": source_type,
        "duration_seconds": round(duration, 4),
        "frame_rate": round(fps, 4),
        "width": width,
        "height": height,
        "settings": asdict(settings),
        "preview_path": str(preview_path),
        "preview_url": preview_path.resolve().as_uri(),
        "kept_ratio": round(kept_ratio, 4),
        "transparent_ratio": round(1.0 - kept_ratio, 4),
    }
