"""Pydantic response models for the API."""

from pydantic import BaseModel


class TranscriptionResponse(BaseModel):
    text: str
    duration_seconds: float | None = None
    processing_time_ms: float | None = None


class HealthResponse(BaseModel):
    status: str
    model: str
    uptime_seconds: float
    version: str
    binary_found: bool
    model_found: bool
    ffmpeg_found: bool


class ErrorResponse(BaseModel):
    detail: str
    status_code: int
