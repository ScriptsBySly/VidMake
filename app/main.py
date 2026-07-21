from __future__ import annotations

import logging
import sys
from pathlib import Path

from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine


def main() -> int:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )

    app = QGuiApplication(sys.argv)
    app.setApplicationName("VidMake")
    app.setOrganizationName("Scripts By Sly")

    engine = QQmlApplicationEngine()
    qml_path = Path(__file__).resolve().parent / "ui" / "Main.qml"
    engine.load(QUrl.fromLocalFile(str(qml_path)))

    if not engine.rootObjects():
        logging.error("Failed to load QML UI from %s", qml_path)
        return 1

    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
