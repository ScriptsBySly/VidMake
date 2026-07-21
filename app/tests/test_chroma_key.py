from __future__ import annotations

from app.video.chroma_key import ChromaKeySettings, IMAGE_EXTENSIONS, _hex_to_rgb, settings_from_dict


def test_chroma_settings_from_dict() -> None:
    settings = settings_from_dict(
        {
            "key_color": "#12abef",
            "tolerance": 0.4,
            "inverted": True,
            "preview_time_ms": 1500,
        }
    )

    assert settings == ChromaKeySettings(
        key_color="#12abef",
        tolerance=0.4,
        inverted=True,
        preview_time_ms=1500,
    )


def test_hex_to_rgb() -> None:
    assert _hex_to_rgb("#00ff00") == (0, 255, 0)


def test_image_extensions_are_supported_for_masks() -> None:
    assert ".png" in IMAGE_EXTENSIONS
    assert ".jpg" in IMAGE_EXTENSIONS
