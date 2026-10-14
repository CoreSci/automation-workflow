@ECHO OFF
REM ---------------------------------------------------------------------------
REM run-container.bat - run one Docker job unattended and log the result.
REM
REM Meant to be started by Windows Task Scheduler (see task-definition.xml and
REM register-task.bat), but it runs the same way from a console.
REM
REM   1. Loads settings from config.bat (copy config.example.bat to start).
REM   2. Optionally starts Docker Desktop if it isn't running
REM      (START_DOCKER_DESKTOP=1), then waits for the Docker engine, up to
REM      DOCKER_WAIT_SECONDS, since it may still be starting after logon or wake.
REM   3. Skips the run if the previous one is still going.
REM   4. Runs the container, appending all of its output to a timestamped log.
REM   5. Deletes logs older than KEEP_LOG_DAYS.
REM   6. Exits with the container's exit code, so Task Scheduler's
REM      "Last Run Result" shows success or failure.
REM
REM Exit codes: 0 = success or skipped (see log), 10 = Docker engine not
REM reachable, 11 = config.bat missing, anything else = from docker run
REM (125 = docker itself failed, 126/127 = command in the image not runnable,
REM otherwise the job's own exit code).
REM ---------------------------------------------------------------------------
SETLOCAL EnableExtensions
REM Work from this script's folder: Task Scheduler starts in System32 by default.
CD /D "%~dp0"

REM --- defaults (override any of these in config.bat) ------------------------
SET "IMAGE=python:3.12-slim"
SET "CONTAINER_NAME=scheduled-job"
SET "DOCKER_ARGS="
SET "JOB_COMMAND="
SET "LOG_DIR=%~dp0logs"
SET "KEEP_LOG_DAYS=30"
SET "DOCKER_WAIT_SECONDS=180"
SET "START_DOCKER_DESKTOP=0"
SET "DOCKER_DESKTOP_EXE=%ProgramFiles%\Docker\Docker\Docker Desktop.exe"

REM Run timestamp, locale-independent. Set before config.bat is loaded, so
REM settings there can use %STAMP% (e.g. to name output files).
FOR /F %%T IN ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss"') DO SET "STAMP=%%T"

IF NOT EXIST "%~dp0config.bat" (
    ECHO ERROR: config.bat not found. Copy config.example.bat to config.bat first.
    EXIT /B 11
)
CALL "%~dp0config.bat"

REM --- log file: one per run -------------------------------------------------
IF NOT EXIST "%LOG_DIR%" MKDIR "%LOG_DIR%"
SET "LOG_FILE=%LOG_DIR%\%CONTAINER_NAME%_%STAMP%.log"
SET "RC=0"

CALL :log "START image=%IMAGE% container=%CONTAINER_NAME%"

REM --- 1. start Docker Desktop if asked to, then wait for the engine ----------
IF "%START_DOCKER_DESKTOP%"=="1" CALL :start_docker_desktop
SET /A WAITED=0
:wait_docker
docker info >NUL 2>&1
IF NOT ERRORLEVEL 1 GOTO docker_ready
IF %WAITED% GEQ %DOCKER_WAIT_SECONDS% (
    CALL :log "ERROR: Docker engine not reachable after %WAITED% s. Is Docker Desktop running?"
    SET "RC=10"
    GOTO finish
)
powershell -NoProfile -Command "Start-Sleep -Seconds 10"
SET /A WAITED+=10
GOTO wait_docker
:docker_ready
IF %WAITED% GTR 0 CALL :log "Docker engine ready after %WAITED% s"

REM --- 2. skip if the previous run is still going; clear a stale container ---
SET "RUNNING="
FOR /F %%C IN ('docker ps -q --filter "name=^%CONTAINER_NAME%$"') DO SET "RUNNING=%%C"
IF DEFINED RUNNING (
    CALL :log "SKIP: container %CONTAINER_NAME% is still running from an earlier start"
    GOTO finish
)
docker rm -f "%CONTAINER_NAME%" >NUL 2>&1

REM --- 3. run the job ----------------------------------------------------------
CALL :log "RUN docker run --rm --name %CONTAINER_NAME% %DOCKER_ARGS% %IMAGE% %JOB_COMMAND%"
docker run --rm --name "%CONTAINER_NAME%" %DOCKER_ARGS% %IMAGE% %JOB_COMMAND% >>"%LOG_FILE%" 2>&1
SET "RC=%ERRORLEVEL%"
IF "%RC%"=="0" (
    CALL :log "OK: job finished"
) ELSE (
    CALL :log "ERROR: job exited with code %RC%"
)

:finish
REM --- 4. rotate logs ----------------------------------------------------------
FORFILES /P "%LOG_DIR%" /M *.log /D -%KEEP_LOG_DAYS% /C "cmd /c del @path" >NUL 2>&1
CALL :log "END exit=%RC%"
EXIT /B %RC%

REM --- helper: start Docker Desktop unless it's already running ----------------
REM No fixed sleep afterwards: the caller's wait loop polls "docker info" until
REM the engine answers or DOCKER_WAIT_SECONDS runs out.
:start_docker_desktop
tasklist /FI "IMAGENAME eq Docker Desktop.exe" /NH | findstr /I /C:"Docker Desktop.exe" >NUL
IF NOT ERRORLEVEL 1 EXIT /B 0
IF NOT EXIST "%DOCKER_DESKTOP_EXE%" GOTO no_docker_desktop
CALL :log "Docker Desktop not running: starting it"
START "" "%DOCKER_DESKTOP_EXE%"
EXIT /B 0
:no_docker_desktop
CALL :log "WARN: Docker Desktop not found at %DOCKER_DESKTOP_EXE%"
EXIT /B 0

REM --- helper: timestamped line to the log file and the console ---------------
:log
ECHO [%DATE% %TIME%] %~1
>>"%LOG_FILE%" ECHO [%DATE% %TIME%] %~1
EXIT /B 0
