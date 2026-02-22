"""Configuration for the local API service."""

import os
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parent.parent

HOST: str = os.environ.get("API_HOST", "127.0.0.1")
PORT: int = int(os.environ.get("API_PORT", "8000"))
TEMP_DIR: Path = Path(os.environ.get("API_TEMP_DIR", str(PROJECT_DIR / ".api-tmp")))
QUEUE_SIZE: int = int(os.environ.get("API_QUEUE_SIZE", "10"))
MAX_UPLOAD_MB: int = int(os.environ.get("API_MAX_UPLOAD_MB", "500"))
TRANSCRIBE_TIMEOUT: int = int(os.environ.get("API_TRANSCRIBE_TIMEOUT", "300"))

BINARY_PATH: Path = PROJECT_DIR / "qwen_asr"
MODEL_DIR: Path = PROJECT_DIR / "qwen3-asr-0.6b"
TRANSCRIBE_SCRIPT: Path = PROJECT_DIR / "scripts" / "transcribe.sh"

VERSION: str = "0.1.0"
