from __future__ import annotations

from app.audio.analyzer import AudioAnalysisSettings, _normalize, settings_from_dict


def test_settings_from_dict_uses_configurable_frequency_range() -> None:
    settings = settings_from_dict(
        {
            "band_name": "Treble",
            "low_hz": 5000,
            "high_hz": 12000,
            "threshold": 0.7,
            "min_interval_ms": 240,
            "sensitivity": 1.5,
            "frame_rate": 60,
        }
    )

    assert settings == AudioAnalysisSettings(
        band_name="Treble",
        low_hz=5000.0,
        high_hz=12000.0,
        threshold=0.7,
        min_interval_ms=240,
        sensitivity=1.5,
        frame_rate=60,
    )


def test_normalize_handles_flat_values() -> None:
    normalized = _normalize([3.0, 3.0, 3.0])

    assert normalized.tolist() == [0.0, 0.0, 0.0]
