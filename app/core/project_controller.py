from __future__ import annotations

import json
import logging
from pathlib import Path

from PySide6.QtCore import QObject, QUrl, Signal, Slot

from .project import empty_project, load_project, save_project, validate_project


logger = logging.getLogger(__name__)


class ProjectController(QObject):
    statusChanged = Signal(str)
    errorOccurred = Signal(str)

    @Slot(result=str)
    def newProjectJson(self) -> str:
        return json.dumps(empty_project())

    @Slot(QUrl, str, result=str)
    def saveProject(self, file_url: QUrl, project_json: str) -> str:
        local_path = file_url.toLocalFile()
        if not local_path:
            self.errorOccurred.emit("Choose a project path before saving.")
            return ""
        path = Path(local_path)

        try:
            data = validate_project(json.loads(project_json))
            saved_path = save_project(path, data)
        except (OSError, ValueError, json.JSONDecodeError) as error:
            logger.exception("Failed to save project")
            self.errorOccurred.emit(f"Could not save project: {error}")
            return ""

        self.statusChanged.emit(f"Saved {saved_path.name}")
        return str(saved_path)

    @Slot(QUrl, result=str)
    def loadProject(self, file_url: QUrl) -> str:
        local_path = file_url.toLocalFile()
        if not local_path:
            self.errorOccurred.emit("Choose a project file to open.")
            return ""
        path = Path(local_path)

        try:
            data = load_project(path)
        except (OSError, ValueError) as error:
            logger.exception("Failed to load project")
            self.errorOccurred.emit(f"Could not load project: {error}")
            return ""

        self.statusChanged.emit(f"Opened {path.name}")
        return json.dumps(data)
