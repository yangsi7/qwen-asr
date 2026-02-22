"""Tests for the local API service.

Uses FastAPI TestClient with mocked subprocess to avoid requiring
the actual C binary and model during testing.
"""

import io
from contextlib import contextmanager
from pathlib import Path
from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient

from api import config


# --- Fixtures ---

@pytest.fixture(autouse=True)
def temp_dir(tmp_path):
    """Override temp dir to use pytest's tmp_path."""
    original = config.TEMP_DIR
    config.TEMP_DIR = tmp_path / "api-tmp"
    config.TEMP_DIR.mkdir()
    yield config.TEMP_DIR
    config.TEMP_DIR = original


@pytest.fixture
def client():
    from api.main import app
    with TestClient(app) as c:
        yield c


@contextmanager
def mock_prereqs(binary=True, model=True, ffmpeg=True):
    with patch("api.main._check_binary", return_value=binary), \
         patch("api.main._check_model", return_value=model), \
         patch("api.main._check_ffmpeg", return_value=ffmpeg):
        yield


def _make_wav_bytes():
    """Create minimal valid WAV header (44 bytes)."""
    import struct
    data_size = 2  # 1 sample so it's not "empty"
    sample = b"\x00\x00"
    header = struct.pack(
        "<4sI4s4sIHHIIHH4sI",
        b"RIFF", 36 + data_size, b"WAVE",
        b"fmt ", 16, 1, 1, 16000, 32000, 2, 16,
        b"data", data_size,
    )
    return header + sample


def _mock_transcription(text="Hello world", duration=5.0, time_ms=1200.0):
    from api.transcribe import TranscriptionResult
    result = TranscriptionResult(text=text, duration_seconds=duration, processing_time_ms=time_ms)
    return patch("api.main.run_transcription", new_callable=AsyncMock, return_value=result)


# --- Config Tests ---

class TestConfig:
    def test_defaults(self):
        assert config.HOST == "127.0.0.1"
        assert config.PORT == 8000
        assert config.QUEUE_SIZE == 10
        assert config.MAX_UPLOAD_MB == 500
        assert config.TRANSCRIBE_TIMEOUT == 300
        assert config.VERSION == "0.1.0"

    def test_project_dir_is_parent(self):
        assert config.PROJECT_DIR == Path(__file__).resolve().parent.parent

    def test_binary_path(self):
        assert config.BINARY_PATH == config.PROJECT_DIR / "qwen_asr"

    def test_model_dir(self):
        assert config.MODEL_DIR == config.PROJECT_DIR / "qwen3-asr-0.6b"


# --- Response Model Tests ---

class TestModels:
    def test_transcription_response(self):
        from api.models import TranscriptionResponse
        r = TranscriptionResponse(text="hello world", duration_seconds=5.0, processing_time_ms=1200.5)
        d = r.model_dump()
        assert d["text"] == "hello world"
        assert d["duration_seconds"] == 5.0
        assert d["processing_time_ms"] == 1200.5

    def test_transcription_response_optional_fields(self):
        from api.models import TranscriptionResponse
        r = TranscriptionResponse(text="hello")
        assert r.duration_seconds is None
        assert r.processing_time_ms is None

    def test_health_response(self):
        from api.models import HealthResponse
        r = HealthResponse(
            status="healthy", model="qwen3-asr-0.6b",
            uptime_seconds=60.0, version="0.1.0",
            binary_found=True, model_found=True, ffmpeg_found=True,
        )
        assert r.status == "healthy"

    def test_error_response(self):
        from api.models import ErrorResponse
        r = ErrorResponse(detail="bad request", status_code=400)
        assert r.detail == "bad request"


# --- Health Endpoint Tests ---

class TestHealth:
    def test_healthy(self, client):
        with mock_prereqs(True, True, True):
            resp = client.get("/health")
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "healthy"
        assert data["version"] == "0.1.0"
        assert data["binary_found"] is True
        assert data["model_found"] is True

    def test_unhealthy_no_binary(self, client):
        with mock_prereqs(False, True, True):
            resp = client.get("/health")
        assert resp.status_code == 503
        assert resp.json()["status"] == "unhealthy"
        assert resp.json()["binary_found"] is False

    def test_unhealthy_no_model(self, client):
        with mock_prereqs(True, False, True):
            resp = client.get("/health")
        assert resp.status_code == 503
        assert resp.json()["model_found"] is False


# --- Transcribe Endpoint Tests ---

class TestTranscribe:
    def test_valid_wav(self, client):
        with mock_prereqs(), _mock_transcription():
            resp = client.post(
                "/transcribe",
                files={"file": ("test.wav", io.BytesIO(_make_wav_bytes()), "audio/wav")},
            )
        assert resp.status_code == 200
        data = resp.json()
        assert data["text"] == "Hello world"
        assert data["duration_seconds"] == 5.0
        assert data["processing_time_ms"] == 1200.0

    def test_unsupported_format(self, client):
        with mock_prereqs():
            resp = client.post(
                "/transcribe",
                files={"file": ("test.txt", io.BytesIO(b"not audio"), "text/plain")},
            )
        assert resp.status_code == 400
        assert "Unsupported file type" in resp.json()["detail"]

    def test_empty_file(self, client):
        with mock_prereqs():
            resp = client.post(
                "/transcribe",
                files={"file": ("test.wav", io.BytesIO(b""), "audio/wav")},
            )
        assert resp.status_code == 400
        assert "Empty file" in resp.json()["detail"]

    def test_503_no_binary(self, client):
        with mock_prereqs(False, True, True):
            resp = client.post(
                "/transcribe",
                files={"file": ("test.wav", io.BytesIO(_make_wav_bytes()), "audio/wav")},
            )
        assert resp.status_code == 503

    def test_503_no_model(self, client):
        with mock_prereqs(True, False, True):
            resp = client.post(
                "/transcribe",
                files={"file": ("test.wav", io.BytesIO(_make_wav_bytes()), "audio/wav")},
            )
        assert resp.status_code == 503

    def test_transcription_error_returns_500(self, client):
        from api.transcribe import TranscriptionError
        with mock_prereqs(), \
             patch("api.main.run_transcription", new_callable=AsyncMock,
                   side_effect=TranscriptionError("binary crashed")):
            resp = client.post(
                "/transcribe",
                files={"file": ("test.wav", io.BytesIO(_make_wav_bytes()), "audio/wav")},
            )
        assert resp.status_code == 500
        assert "binary crashed" in resp.json()["detail"]


# --- Temp File Cleanup Tests ---

class TestTempFileCleanup:
    def test_temp_file_cleaned_after_success(self, client, temp_dir):
        with mock_prereqs(), _mock_transcription():
            client.post(
                "/transcribe",
                files={"file": ("test.wav", io.BytesIO(_make_wav_bytes()), "audio/wav")},
            )
        remaining = list(temp_dir.iterdir())
        assert len(remaining) == 0, f"Temp files not cleaned: {remaining}"

    def test_temp_file_cleaned_after_failure(self, client, temp_dir):
        from api.transcribe import TranscriptionError
        with mock_prereqs(), \
             patch("api.main.run_transcription", new_callable=AsyncMock,
                   side_effect=TranscriptionError("fail")):
            client.post(
                "/transcribe",
                files={"file": ("test.wav", io.BytesIO(_make_wav_bytes()), "audio/wav")},
            )
        remaining = list(temp_dir.iterdir())
        assert len(remaining) == 0, f"Temp files not cleaned after failure: {remaining}"


# --- Subprocess Wrapper Tests ---

class TestTranscribeModule:
    def test_parse_timing(self):
        from api.transcribe import _parse_timing
        assert _parse_timing("Audio: 13.0 s processed in 1.5 s (8.67x realtime)") == 13.0
        assert _parse_timing("no timing here") is None
        assert _parse_timing("") is None
