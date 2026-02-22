"""Async subprocess wrapper for scripts/transcribe.sh."""

import asyncio
import re
import time
from pathlib import Path

from api import config


class TranscriptionError(Exception):
    """Raised when the transcription subprocess fails."""

    def __init__(self, message: str, stderr: str = ""):
        super().__init__(message)
        self.stderr = stderr


class TranscriptionResult:
    __slots__ = ("text", "duration_seconds", "processing_time_ms")

    def __init__(self, text: str, duration_seconds: float | None, processing_time_ms: float):
        self.text = text
        self.duration_seconds = duration_seconds
        self.processing_time_ms = processing_time_ms


def _parse_timing(stderr: str) -> float | None:
    """Extract audio duration from stderr timing line."""
    # Pattern: "Audio: 13.0 s processed in 1.5 s (8.67x realtime)"
    match = re.search(r"Audio:\s+([\d.]+)\s+s\s+processed", stderr)
    if match:
        return float(match.group(1))
    return None


async def run_transcription(audio_path: Path) -> TranscriptionResult:
    """Run transcribe.sh on audio_path and return result."""
    if not config.TRANSCRIBE_SCRIPT.exists():
        raise TranscriptionError(f"Transcription script not found: {config.TRANSCRIBE_SCRIPT}")

    start = time.monotonic()

    proc = await asyncio.create_subprocess_exec(
        str(config.TRANSCRIBE_SCRIPT),
        str(audio_path),
        "--silent",
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )

    try:
        stdout_bytes, stderr_bytes = await asyncio.wait_for(
            proc.communicate(),
            timeout=config.TRANSCRIBE_TIMEOUT,
        )
    except asyncio.TimeoutError:
        proc.kill()
        await proc.communicate()
        raise TranscriptionError(
            f"Transcription timed out after {config.TRANSCRIBE_TIMEOUT}s"
        )

    elapsed_ms = (time.monotonic() - start) * 1000
    stdout_text = stdout_bytes.decode("utf-8", errors="replace").strip()
    stderr_text = stderr_bytes.decode("utf-8", errors="replace")

    if proc.returncode != 0:
        raise TranscriptionError(
            f"Transcription failed (exit code {proc.returncode})",
            stderr=stderr_text,
        )

    if not stdout_text:
        raise TranscriptionError("Transcription produced empty output", stderr=stderr_text)

    duration = _parse_timing(stderr_text)

    return TranscriptionResult(
        text=stdout_text,
        duration_seconds=duration,
        processing_time_ms=round(elapsed_ms, 1),
    )
