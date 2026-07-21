from __future__ import annotations

import hashlib
import shutil
import subprocess
import time
from dataclasses import asdict, dataclass
from pathlib import Path
from tempfile import TemporaryDirectory
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


def _mask_from_frame_rgb(frame_rgb: np.ndarray, settings: ChromaKeySettings) -> np.ndarray:
    frame_float = frame_rgb.astype(np.float32) / 255.0
    key_rgb = np.array(_hex_to_rgb(settings.key_color), dtype=np.float32) / 255.0
    distance = np.linalg.norm(frame_float - key_rgb, axis=2) / np.sqrt(3.0)
    mask = (distance > settings.tolerance).astype(np.uint8) * 255
    if settings.inverted:
        mask = 255 - mask
    return mask


def _mask_stats(mask: np.ndarray) -> dict[str, float]:
    height, width = mask.shape[:2]
    kept_ratio = float(mask.mean() / 255.0)
    ys, xs = np.nonzero(mask > 0)
    if len(xs) > 0 and width > 0 and height > 0:
        return {
            "kept_ratio": kept_ratio,
            "min_x": float(xs.min() / max(1, width - 1)),
            "max_x": float(xs.max() / max(1, width - 1)),
            "min_y": float(ys.min() / max(1, height - 1)),
            "max_y": float(ys.max() / max(1, height - 1)),
            "center_x": float(xs.mean() / max(1, width - 1)),
            "center_y": float(ys.mean() / max(1, height - 1)),
            "weight": float(len(xs)),
        }
    return {
        "kept_ratio": kept_ratio,
        "min_x": 0.0,
        "max_x": 1.0,
        "min_y": 0.0,
        "max_y": 1.0,
        "center_x": 0.5,
        "center_y": 0.5,
        "weight": 0.0,
    }


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
    try:
        if not capture.isOpened():
            return _read_video_frame_with_ffmpeg(path, time_ms, cv2)

        fps = float(capture.get(cv2.CAP_PROP_FPS) or 30.0)
        frame_count = int(capture.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
        width = int(capture.get(cv2.CAP_PROP_FRAME_WIDTH) or 0)
        height = int(capture.get(cv2.CAP_PROP_FRAME_HEIGHT) or 0)
        duration = frame_count / fps if fps > 0 and frame_count > 0 else 0.0

        capture.set(cv2.CAP_PROP_POS_MSEC, max(0, time_ms))
        ok, frame_bgr = capture.read()
        if not ok or frame_bgr is None:
            return _read_video_frame_with_ffmpeg(path, time_ms, cv2)
    except Exception:
        return _read_video_frame_with_ffmpeg(path, time_ms, cv2)
    finally:
        capture.release()

    return frame_bgr, fps, width, height, duration, "video"


def _read_video_frame_with_ffmpeg(path: Path, time_ms: int, cv2: Any) -> tuple[np.ndarray, float, int, int, float, str]:
    ffmpeg_path = _ffmpeg_executable()
    if not ffmpeg_path:
        raise ValueError(
            "Could not read a frame from the selected video. OpenCV cannot decode it, and ffmpeg was not found."
        )

    with TemporaryDirectory(prefix="vidmake-frame-") as temp_dir:
        frame_path = Path(temp_dir) / "preview.png"
        command = [
            ffmpeg_path,
            "-y",
            "-ss",
            f"{max(0, time_ms) / 1000.0:.3f}",
            "-i",
            str(path),
            "-frames:v",
            "1",
            str(frame_path),
        ]
        result = subprocess.run(command, capture_output=True, text=True, timeout=30)
        if result.returncode != 0 or not frame_path.exists():
            details = (result.stderr or result.stdout or "").strip().splitlines()
            reason = details[-1] if details else "ffmpeg could not decode the selected video."
            raise ValueError(f"Could not read a frame from the selected video: {reason}")

        frame_bgr = cv2.imread(str(frame_path), cv2.IMREAD_COLOR)
        if frame_bgr is None:
            raise ValueError("Could not read the extracted preview frame.")

    height, width = frame_bgr.shape[:2]
    return frame_bgr, 0.0, width, height, 0.0, "video"


def _ffmpeg_executable() -> str:
    try:
        import imageio_ffmpeg

        return str(imageio_ffmpeg.get_ffmpeg_exe())
    except Exception:
        return shutil.which("ffmpeg") or ""


def sample_color(path: Path, time_ms: int, normalized_x: float, normalized_y: float) -> str:
    frame_bgr, _fps, width, height, _duration, _source_type = _read_frame(path, time_ms)
    x = max(0, min(width - 1, round(normalized_x * (width - 1))))
    y = max(0, min(height - 1, round(normalized_y * (height - 1))))
    b, g, r = frame_bgr[y, x]
    return _rgb_to_hex((int(r), int(g), int(b)))


def _analyze_image(
    frame_bgr: np.ndarray,
    settings: ChromaKeySettings,
    preview_path: Path,
    cutout_path: Path,
) -> dict[str, Any]:
    try:
        import cv2
    except ImportError as error:
        raise RuntimeError(
            "Visual analysis requires opencv-python. Install dependencies with: pip install -r requirements.txt"
        ) from error

    frame_rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
    mask = _mask_from_frame_rgb(frame_rgb, settings)
    cv2.imwrite(str(preview_path), mask)
    frame_rgba = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGBA)
    frame_rgba[:, :, 3] = mask
    cv2.imwrite(str(cutout_path), frame_rgba)
    return _mask_stats(mask)


def _analyze_video(
    path: Path,
    settings: ChromaKeySettings,
    preview_path: Path,
    cutout_path: Path,
    cutout_frames_path: Path,
) -> dict[str, Any]:
    try:
        import imageio
        import imageio.v3 as iio
    except ImportError as error:
        raise RuntimeError(
            "Video mask analysis requires imageio and imageio-ffmpeg. Install dependencies with: pip install -r requirements.txt"
        ) from error

    metadata = iio.immeta(path, plugin="FFMPEG")
    fps = float(metadata.get("fps") or 30.0)
    duration = float(metadata.get("duration") or 0.0)
    source_size = metadata.get("source_size") or metadata.get("size") or (0, 0)
    width = int(source_size[0] or 0)
    height = int(source_size[1] or 0)

    preview_writer = imageio.get_writer(
        preview_path,
        fps=fps,
        codec="libx264",
        quality=7,
        macro_block_size=None,
        ffmpeg_log_level="error",
    )
    cutout_writer = imageio.get_writer(
        cutout_path,
        fps=fps,
        codec="libvpx-vp9",
        macro_block_size=None,
        ffmpeg_log_level="error",
        output_params=["-pix_fmt", "yuva420p"],
    )

    frame_count = 0
    kept_total = 0.0
    weight_total = 0.0
    center_x_total = 0.0
    center_y_total = 0.0
    min_x = 1.0
    min_y = 1.0
    max_x = 0.0
    max_y = 0.0

    cutout_frames_path.mkdir(parents=True, exist_ok=True)

    try:
        for frame_rgb in iio.imiter(path, plugin="FFMPEG"):
            if frame_rgb.ndim == 2:
                frame_rgb = np.repeat(frame_rgb[:, :, np.newaxis], 3, axis=2)
            if frame_rgb.shape[2] > 3:
                frame_rgb = frame_rgb[:, :, :3]
            if width <= 0 or height <= 0:
                height, width = frame_rgb.shape[:2]

            mask = _mask_from_frame_rgb(frame_rgb, settings)
            stats = _mask_stats(mask)
            kept_total += stats["kept_ratio"]
            if stats["weight"] > 0:
                weight_total += stats["weight"]
                center_x_total += stats["center_x"] * stats["weight"]
                center_y_total += stats["center_y"] * stats["weight"]
                min_x = min(min_x, stats["min_x"])
                min_y = min(min_y, stats["min_y"])
                max_x = max(max_x, stats["max_x"])
                max_y = max(max_y, stats["max_y"])

            preview_writer.append_data(np.repeat(mask[:, :, np.newaxis], 3, axis=2))
            cutout_rgba = np.dstack((frame_rgb, mask))
            cutout_writer.append_data(cutout_rgba)
            imageio.imwrite(cutout_frames_path / f"frame_{frame_count:06d}.png", cutout_rgba)
            frame_count += 1
    finally:
        preview_writer.close()
        cutout_writer.close()

    if frame_count == 0:
        raise ValueError("Could not read frames from the selected video.")

    if duration <= 0.0 and fps > 0:
        duration = frame_count / fps
    if weight_total <= 0:
        min_x = 0.0
        min_y = 0.0
        max_x = 1.0
        max_y = 1.0
        center_x = 0.5
        center_y = 0.5
    else:
        center_x = center_x_total / weight_total
        center_y = center_y_total / weight_total

    return {
        "kept_ratio": kept_total / frame_count,
        "min_x": min_x,
        "min_y": min_y,
        "max_x": max_x,
        "max_y": max_y,
        "center_x": center_x,
        "center_y": center_y,
        "fps": fps,
        "duration": duration,
        "width": width,
        "height": height,
        "frame_count": frame_count,
    }


def analyze_chroma_key(path: Path, settings: ChromaKeySettings, cache_root: Path) -> dict[str, Any]:
    try:
        import cv2
    except ImportError as error:
        raise RuntimeError(
            "Visual analysis requires opencv-python. Install dependencies with: pip install -r requirements.txt"
        ) from error

    if not path.exists():
        raise FileNotFoundError(f"Visual file does not exist: {path}")

    cache_root.mkdir(parents=True, exist_ok=True)
    digest = hashlib.sha1(
        f"{path}|{path.stat().st_mtime_ns}|{settings}|{time.time_ns()}".encode("utf-8")
    ).hexdigest()[:16]

    if path.suffix.lower() in IMAGE_EXTENSIONS:
        frame_bgr, fps, width, height, duration, source_type = _read_frame(path, settings.preview_time_ms)
        preview_path = cache_root / f"mask-preview-{digest}.png"
        cutout_path = cache_root / f"mask-cutout-{digest}.png"
        cutout_frames_path = Path()
        stats = _analyze_image(frame_bgr, settings, preview_path, cutout_path)
    else:
        source_type = "video"
        preview_path = cache_root / f"mask-preview-{digest}.mp4"
        cutout_path = cache_root / f"mask-cutout-{digest}.webm"
        cutout_frames_path = cache_root / f"mask-cutout-frames-{digest}"
        stats = _analyze_video(path, settings, preview_path, cutout_path, cutout_frames_path)
        fps = stats["fps"]
        width = int(stats["width"])
        height = int(stats["height"])
        duration = stats["duration"]

    kept_ratio = float(stats["kept_ratio"])
    min_x = float(stats["min_x"])
    min_y = float(stats["min_y"])
    max_x = float(stats["max_x"])
    max_y = float(stats["max_y"])
    center_x = float(stats["center_x"])
    center_y = float(stats["center_y"])
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
        "cutout_path": str(cutout_path),
        "cutout_url": cutout_path.resolve().as_uri(),
        "cutout_frames_path": str(cutout_frames_path) if source_type == "video" else "",
        "frame_count": int(stats.get("frame_count", 1 if source_type == "image" else 0)),
        "kept_ratio": round(kept_ratio, 4),
        "transparent_ratio": round(1.0 - kept_ratio, 4),
        "mask_center_x": round(center_x, 4),
        "mask_center_y": round(center_y, 4),
        "mask_bounds": {
            "min_x": round(min_x, 4),
            "min_y": round(min_y, 4),
            "max_x": round(max_x, 4),
            "max_y": round(max_y, 4),
        },
    }
