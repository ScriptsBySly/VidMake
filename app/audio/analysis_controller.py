from __future__ import annotations

import json
import logging
from pathlib import Path

from PySide6.QtCore import QObject, QThread, Signal, Slot

from .analyzer import SUGGESTED_RANGES, analyze_audio, settings_from_dict


logger = logging.getLogger(__name__)


class _AnalysisWorker(QObject):
    finished = Signal(str)
    failed = Signal(str)

    def __init__(self, path: str, settings_json: str) -> None:
        super().__init__()
        self._path = path
        self._settings_json = settings_json

    @Slot()
    def run(self) -> None:
        try:
            settings = settings_from_dict(json.loads(self._settings_json))
            result = analyze_audio(Path(self._path), settings)
        except Exception as error:
            logger.exception("Audio analysis failed")
            self.failed.emit(str(error))
            return
        self.finished.emit(json.dumps(result))


class AudioAnalysisController(QObject):
    analysisStarted = Signal()
    analysisFinished = Signal(str)
    analysisFailed = Signal(str)

    def __init__(self) -> None:
        super().__init__()
        self._thread: QThread | None = None
        self._worker: _AnalysisWorker | None = None

    @Slot(result=str)
    def suggestedRangesJson(self) -> str:
        return json.dumps(SUGGESTED_RANGES)

    @Slot(str, str)
    def analyze(self, audio_path: str, settings_json: str) -> None:
        if self._thread and self._thread.isRunning():
            self.analysisFailed.emit("An audio analysis job is already running.")
            return
        if not audio_path:
            self.analysisFailed.emit("Choose an audio asset before analyzing.")
            return

        self._thread = QThread()
        self._worker = _AnalysisWorker(audio_path, settings_json)
        self._worker.moveToThread(self._thread)
        self._thread.started.connect(self._worker.run)
        self._worker.finished.connect(self._handle_finished)
        self._worker.failed.connect(self._handle_failed)
        self._worker.finished.connect(self._thread.quit)
        self._worker.failed.connect(self._thread.quit)
        self._thread.finished.connect(self._cleanup)
        self.analysisStarted.emit()
        self._thread.start()

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
