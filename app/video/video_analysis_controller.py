from __future__ import annotations

import json
import logging
from pathlib import Path

from PySide6.QtCore import QObject, QThread, Signal, Slot

from .chroma_key import analyze_chroma_key, sample_color, settings_from_dict


logger = logging.getLogger(__name__)


class _VideoMaskWorker(QObject):
    finished = Signal(str)
    failed = Signal(str)

    def __init__(self, path: str, settings_json: str, cache_root: Path) -> None:
        super().__init__()
        self._path = path
        self._settings_json = settings_json
        self._cache_root = cache_root

    @Slot()
    def run(self) -> None:
        try:
            settings = settings_from_dict(json.loads(self._settings_json))
            result = analyze_chroma_key(Path(self._path), settings, self._cache_root)
        except Exception as error:
            logger.exception("Video analysis failed")
            self.failed.emit(str(error))
            return
        self.finished.emit(json.dumps(result))


class VideoAnalysisController(QObject):
    analysisStarted = Signal()
    analysisFinished = Signal(str)
    analysisFailed = Signal(str)

    def __init__(self, cache_root: Path) -> None:
        super().__init__()
        self._cache_root = cache_root
        self._thread: QThread | None = None
        self._worker: _VideoMaskWorker | None = None

    @Slot(str, str)
    def analyze(self, video_path: str, settings_json: str) -> None:
        if self._thread and self._thread.isRunning():
            self.analysisFailed.emit("A video analysis job is already running.")
            return
        if not video_path:
            self.analysisFailed.emit("Choose a visual video asset before analyzing.")
            return

        self._thread = QThread()
        self._worker = _VideoMaskWorker(video_path, settings_json, self._cache_root)
        self._worker.moveToThread(self._thread)
        self._thread.started.connect(self._worker.run)
        self._worker.finished.connect(self._handle_finished)
        self._worker.failed.connect(self._handle_failed)
        self._worker.finished.connect(self._thread.quit)
        self._worker.failed.connect(self._thread.quit)
        self._thread.finished.connect(self._cleanup)
        self.analysisStarted.emit()
        self._thread.start()

    @Slot(str, int, float, float, result=str)
    def sampleColor(self, video_path: str, time_ms: int, normalized_x: float, normalized_y: float) -> str:
        if not video_path:
            self.analysisFailed.emit("Choose a visual video asset before using the dropper.")
            return ""
        try:
            return sample_color(Path(video_path), time_ms, normalized_x, normalized_y)
        except Exception as error:
            logger.exception("Could not sample chroma key color")
            self.analysisFailed.emit(f"Could not sample color: {error}")
            return ""

    @Slot(str)
    def _handle_finished(self, result_json: str) -> None:
        self.analysisFinished.emit(result_json)

    @Slot(str)
    def _handle_failed(self, message: str) -> None:
        self.analysisFailed.emit(message)

    @Slot()
    def _cleanup(self) -> None:
        if self._worker:
            self._worker.deleteLater()
        if self._thread:
            self._thread.deleteLater()
        self._worker = None
        self._thread = None
