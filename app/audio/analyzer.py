from __future__ import annotations

from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

import numpy as np


SUGGESTED_RANGES: list[dict[str, Any]] = [
    {"name": "Sub bass", "low_hz": 20, "high_hz": 60},
    {"name": "Kick / bass", "low_hz": 60, "high_hz": 160},
    {"name": "Low mids", "low_hz": 160, "high_hz": 500},
    {"name": "Mids", "low_hz": 500, "high_hz": 2000},
    {"name": "Presence", "low_hz": 2000, "high_hz": 5000},
    {"name": "Treble / hats", "low_hz": 5000, "high_hz": 12000},
]


@dataclass(frozen=True)
class BeatMarker:
    time_seconds: float
    frame_number: int
    strength: float
    band_name: str
    low_hz: float
    high_hz: float


@dataclass(frozen=True)
class AudioAnalysisSettings:
    band_name: str = "Kick / bass"
    low_hz: float = 60.0
    high_hz: float = 160.0
    threshold: float = 0.45
    min_interval_ms: int = 120
    sensitivity: float = 1.0
    frame_rate: int = 30
    sample_rate: int = 22050
    hop_length: int = 512


def settings_from_dict(data: dict[str, Any]) -> AudioAnalysisSettings:
    return AudioAnalysisSettings(
        band_name=str(data.get("band_name", "Custom")),
        low_hz=float(data.get("low_hz", 60.0)),
        high_hz=float(data.get("high_hz", 160.0)),
        threshold=float(data.get("threshold", 0.45)),
        min_interval_ms=int(data.get("min_interval_ms", 120)),
        sensitivity=float(data.get("sensitivity", 1.0)),
        frame_rate=int(data.get("frame_rate", 30)),
    )


def _normalize(values: np.ndarray) -> np.ndarray:
    values = np.asarray(values, dtype=np.float32)
    if values.size == 0:
        return values
    values = values - float(values.min())
    maximum = float(values.max())
    if maximum <= 1e-9:
        return np.zeros_like(values)
    return values / maximum


def analyze_audio(path: Path, settings: AudioAnalysisSettings) -> dict[str, Any]:
    try:
        import librosa
    except ImportError as error:
        raise RuntimeError(
            "Audio analysis requires librosa. Install dependencies with: pip install -r requirements.txt"
        ) from error

    if not path.exists():
        raise FileNotFoundError(f"Audio file does not exist: {path}")

    y, sr = librosa.load(path, sr=settings.sample_rate, mono=True)
    if y.size == 0:
        raise ValueError("Audio file contains no samples.")

    stft = np.abs(librosa.stft(y, hop_length=settings.hop_length))
    freqs = librosa.fft_frequencies(sr=sr)
    band_mask = (freqs >= settings.low_hz) & (freqs <= settings.high_hz)
    if not np.any(band_mask):
        raise ValueError("Selected frequency range does not contain any FFT bins.")

    band_energy = stft[band_mask].mean(axis=0)
    band_energy = _normalize(band_energy)
    novelty = np.diff(band_energy, prepend=band_energy[0])
    novelty = _normalize(np.maximum(novelty, 0.0)) * max(0.01, settings.sensitivity)

    times = librosa.frames_to_time(
        np.arange(novelty.size),
        sr=sr,
        hop_length=settings.hop_length,
    )
    min_interval_seconds = max(0.0, settings.min_interval_ms / 1000.0)

    markers: list[BeatMarker] = []
    last_time = -min_interval_seconds
    for time_seconds, strength in zip(times, novelty):
        if strength < settings.threshold:
            continue
        if time_seconds - last_time < min_interval_seconds:
            if markers and strength > markers[-1].strength:
                markers[-1] = BeatMarker(
                    time_seconds=float(time_seconds),
                    frame_number=round(float(time_seconds) * settings.frame_rate),
                    strength=round(float(min(1.0, strength)), 4),
                    band_name=settings.band_name,
                    low_hz=settings.low_hz,
                    high_hz=settings.high_hz,
                )
                last_time = float(time_seconds)
            continue
        markers.append(
            BeatMarker(
                time_seconds=float(time_seconds),
                frame_number=round(float(time_seconds) * settings.frame_rate),
                strength=round(float(min(1.0, strength)), 4),
                band_name=settings.band_name,
                low_hz=settings.low_hz,
                high_hz=settings.high_hz,
            )
        )
        last_time = float(time_seconds)

    onset_envelope = librosa.onset.onset_strength(y=y, sr=sr, hop_length=settings.hop_length)
    tempo_raw, beat_frames = librosa.beat.beat_track(
        onset_envelope=onset_envelope,
        sr=sr,
        hop_length=settings.hop_length,
    )
    tempo = float(np.asarray(tempo_raw).reshape(-1)[0]) if np.asarray(tempo_raw).size else 0.0
    beat_times = librosa.frames_to_time(beat_frames, sr=sr, hop_length=settings.hop_length)

    duration = float(librosa.get_duration(y=y, sr=sr))
    preview_points = [
        {
            "time_seconds": round(float(time), 4),
            "energy": round(float(energy), 4),
            "novelty": round(float(value), 4),
        }
        for time, energy, value in zip(times[::2], band_energy[::2], novelty[::2])
    ]

    return {
        "source": str(path),
        "duration_seconds": round(duration, 4),
        "tempo_bpm": round(tempo, 2),
        "beat_count": int(len(beat_times)),
        "detected_beat_count": len(markers),
        "settings": asdict(settings),
        "markers": [asdict(marker) for marker in markers],
        "global_beats": [
            {
                "time_seconds": round(float(time), 4),
                "frame_number": round(float(time) * settings.frame_rate),
            }
            for time in beat_times
        ],
        "preview_points": preview_points[:1200],
        "suggested_ranges": SUGGESTED_RANGES,
    }
