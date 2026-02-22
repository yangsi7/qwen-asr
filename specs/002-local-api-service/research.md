# Research: 002-local-api-service

## FastAPI
**Version**: 0.115+ (latest stable)
**Key Patterns**:
- `UploadFile` for multipart file handling (backed by `python-multipart`)
- `BackgroundTasks` for post-response cleanup (temp file deletion)
- Lifespan context manager for startup/shutdown validation
- Pydantic v2 response models for structured JSON

**Pitfalls**:
- `UploadFile.read()` loads entire file into memory — use `shutil.copyfileobj` to stream to temp file instead
- Default uvicorn worker count = 1 (correct for our sequential processing model)
- `subprocess.run()` blocks the event loop — use `asyncio.create_subprocess_exec` for non-blocking binary invocation
- File upload size limits must be enforced at the app level (uvicorn doesn't enforce by default)

## Subprocess Integration with qwen_asr
**Approach**: Call `scripts/transcribe.sh` via subprocess (not the binary directly)
**Why**: transcribe.sh handles ffmpeg format conversion, model/binary validation, and WAV passthrough — we reuse that logic instead of duplicating it

**Key Decision**: Use `asyncio.create_subprocess_exec` with stdout/stderr capture:
- stdout = transcription text
- stderr = timing/debug info (parse for realtime factor, processing time)
- Return code 0 = success, non-zero = error

## Concurrency Model
**Choice**: `asyncio.Semaphore(1)` for sequential binary invocation + `asyncio.Queue` for request queuing
**Why**: The C binary uses ~2.8GB RAM. Concurrent invocations would OOM. Sequential processing is explicitly in the spec (US-4, AC-4.1).
**Queue overflow**: Return 429 when queue depth exceeds configurable limit (default: 10)

## Temp File Strategy
**Choice**: Python `tempfile.NamedTemporaryFile` in a dedicated temp dir with restricted permissions (0o700)
**Cleanup**: Delete in `finally` block immediately after transcription completes
**Startup cleanup**: On server start, sweep any leftover temp files from previous unclean shutdowns

## Localhost Binding
**Default**: `127.0.0.1:8000` (not `0.0.0.0`)
**Why**: Privacy-first architecture. Service is local-only per spec NFR-002 and NFR-004.
