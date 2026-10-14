@ECHO OFF
REM Settings for run-container.bat and run-compose-job.bat. Copy this file to
REM config.bat and edit it. config.bat is git-ignored, so machine-specific
REM paths and settings stay local. Keep secrets out of this file too: pass them
REM with --env-file (see README). %STAMP% (the run timestamp) and %~dp0 (this
REM folder, with a trailing \) can be used below.

REM === Shared ================================================================

REM Where logs go, how long to keep them, and how long to wait for Docker.
SET "LOG_DIR=%~dp0logs"
SET "KEEP_LOG_DAYS=30"
SET "DOCKER_WAIT_SECONDS=180"

REM 1 = start Docker Desktop if it isn't running (needed when the task runs
REM while nobody is logged on, see README). The path is the default install.
SET "START_DOCKER_DESKTOP=0"
SET "DOCKER_DESKTOP_EXE=%ProgramFiles%\Docker\Docker\Docker Desktop.exe"

REM === run-container.bat: a fresh container per run ============================

REM Image to run, and a fixed container name (used to detect overlapping runs).
SET "IMAGE=python:3.12-slim"
SET "CONTAINER_NAME=scheduled-job"

REM Extra docker run arguments. This example mounts the sample job read-only
REM and an output folder read-write.
SET "DOCKER_ARGS=-v "%~dp0job:/job:ro" -v "%~dp0output:/output" -e JOB_NAME=example"

REM Command run inside the container. Leave empty to use the image's default.
SET "JOB_COMMAND=python /job/job.py"

REM === run-compose-job.bat: a job inside a long-running service ================

REM Compose file, the service to exec into, and a name for the log files.
SET "COMPOSE_FILE=%~dp0compose.yaml"
SET "COMPOSE_SERVICE=notebook"
SET "JOB_NAME=scheduled-report"

REM Options for "docker compose exec" (before the service name), then the
REM command. This example executes the notebook headless and saves the
REM executed copy, with its outputs, next to the CSV and PNG it writes.
REM Add -e FAIL=1 to EXEC_ARGS to test a failing run.
SET "EXEC_ARGS=-e RUN_STAMP=%STAMP%"
SET "EXEC_COMMAND=jupyter nbconvert --to notebook --execute --ExecutePreprocessor.timeout=1800 --output-dir /home/jovyan/output --output scheduled-report_%STAMP% /home/jovyan/work/scheduled-report.ipynb"

REM 1 = stop the service after each run (saves memory, slower next start).
SET "COMPOSE_DOWN_AFTER=0"
