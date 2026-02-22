"""FastAPI local transcription service wrapping the qwen-asr C binary."""

import asyncio
import shutil
import tempfile
import time
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, HTTPException, UploadFile
from fastapi.responses import JSONResponse

from api import config
from api.models import ErrorResponse, HealthResponse, TranscriptionResponse
from api.transcribe import TranscriptionError, run_transcription

# --- State ---
_start_time: float = 0.0
_semaphore: Optional[asyncio.Semaphore] = None
_queue_depth: int = 0

ALLOWED_EXTENSIONS = {".wav", ".mp3", ".m4a", ".flac", ".ogg", ".webm"}


def _check_binary() -> bool:
    return config.BINARY_PATH.exists() and bool(config.BINARY_PATH.stat().st_mode & 0o111)

def _check_model() -> bool:
    return config.MODEL_DIR.is_dir() and (config.MODEL_DIR / "model.safetensors").exists()

def _check_ffmpeg() -> bool:
    return shutil.which("ffmpeg") is not None


def _sweep_temp_dir() -> int:
    """Delete stale temp files from previous runs. Returns count deleted."""
    if not config.TEMP_DIR.exists():
        return 0
    count = 0
    for f in config.TEMP_DIR.iterdir():
        if f.is_file():
            f.unlink()
            count += 1
    return count


@asynccontextmanager
async def lifespan(app: FastAPI):
    global _start_time, _semaphore
    _start_time = time.monotonic()
    _semaphore = asyncio.Semaphore(1)
    config.TEMP_DIR.mkdir(mode=0o700, parents=True, exist_ok=True)
    swept = _sweep_temp_dir()
    if swept:
        print(f"Cleaned up {swept} stale temp file(s)")
    yield


app = FastAPI(
    title="qwen-asr Local API",
    version=config.VERSION,
    lifespan=lifespan,
)


@app.get("/health", response_model=HealthResponse)
async def health():
    binary_ok = _check_binary()
    model_ok = _check_model()
    ffmpeg_ok = _check_ffmpeg()
    all_ok = binary_ok and model_ok and ffmpeg_ok

    response = HealthResponse(
        status="healthy" if all_ok else "unhealthy",
        model="qwen3-asr-0.6b" if model_ok else "not found",
        uptime_seconds=round(time.monotonic() - _start_time, 1),
        version=config.VERSION,
        binary_found=binary_ok,
        model_found=model_ok,
        ffmpeg_found=ffmpeg_ok,
    )

    if not all_ok:
        return JSONResponse(status_code=503, content=response.model_dump())
    return response


@app.post("/transcribe", response_model=TranscriptionResponse)
async def transcribe(file: UploadFile):
    global _queue_depth

    # Validate prerequisites
    if not _check_binary():
        raise HTTPException(503, detail="Binary not built. Run 'make blas' first.")
    if not _check_model():
        raise HTTPException(503, detail="Model not found. Run './download_model.sh --model small' first.")

    # Validate file
    if not file.filename:
        raise HTTPException(400, detail="No filename provided")

    ext = Path(file.filename).suffix.lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(400, detail=f"Unsupported file type: {ext}. Allowed: {', '.join(sorted(ALLOWED_EXTENSIONS))}")

    # Check queue depth
    if _queue_depth >= config.QUEUE_SIZE:
        return JSONResponse(
            status_code=429,
            content=ErrorResponse(detail="Queue full. Try again later.", status_code=429).model_dump(),
            headers={"Retry-After": "30"},
        )

    _queue_depth += 1
    temp_path: Optional[Path] = None

    try:
        # Save upload to temp file
        config.TEMP_DIR.mkdir(mode=0o700, parents=True, exist_ok=True)
        fd, temp_str = tempfile.mkstemp(suffix=ext, dir=config.TEMP_DIR)

        temp_path = Path(temp_str)
        try:
            content = await file.read()
            if len(content) == 0:
                raise HTTPException(400, detail="Empty file uploaded")
            if len(content) > config.MAX_UPLOAD_MB * 1024 * 1024:
                raise HTTPException(413, detail=f"File too large. Maximum: {config.MAX_UPLOAD_MB}MB")

            with open(fd, "wb") as f:
                f.write(content)
        except HTTPException:
            import os
            os.close(fd)
            raise

        # Acquire semaphore for sequential processing
        assert _semaphore is not None
        async with _semaphore:
            result = await run_transcription(temp_path)

        return TranscriptionResponse(
            text=result.text,
            duration_seconds=result.duration_seconds,
            processing_time_ms=result.processing_time_ms,
        )

    except HTTPException:
        raise
    except TranscriptionError as e:
        raise HTTPException(500, detail=str(e))
    except Exception as e:
        raise HTTPException(500, detail=f"Internal error: {e}")
    finally:
        _queue_depth -= 1
        if temp_path and temp_path.exists():
            temp_path.unlink()
