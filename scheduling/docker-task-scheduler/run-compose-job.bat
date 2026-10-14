@ECHO OFF
REM ---------------------------------------------------------------------------
REM run-compose-job.bat - run a job inside a long-running Docker Compose service.
REM
REM The sibling of run-container.bat, for when the environment should stay up
REM between runs (a service with its dependencies already installed and
REM warm) instead of a fresh container per run. Each run:
REM
REM   1. Loads settings from config.bat (copy config.example.bat to start).
REM   2. Optionally starts Docker Desktop, then waits for the engine
REM      (same logic as run-container.bat).
REM   3. "docker compose up -d --wait": starts the service if it isn't running,
REM      and waits until it is (no fixed sleep).
REM   4. "docker compose exec -T": runs EXEC_COMMAND inside the service,
REM      appending all output to a timestamped log.
REM   5. Optionally stops the service again (COMPOSE_DOWN_AFTER=1).
REM   6. Deletes old logs and exits with the job's exit code.
REM
REM The example service (compose.yaml) runs notebooks/scheduled-report.ipynb
REM with "jupyter nbconvert --execute": a scheduled, headless notebook run.
REM
REM Exit codes: 0 = success, 10 = Docker engine not reachable, 11 = config.bat
REM missing, 12 = the service didn't start, anything else = from the job.
REM
REM Self-contained on purpose: this file shares its helpers' logic with
REM run-container.bat, so either one can be copied on its own.
REM ---------------------------------------------------------------------------
SETLOCAL EnableExtensions
CD /D "%~dp0"

REM --- defaults (override any of these in config.bat) ------------------------
SET "COMPOSE_FILE=%~dp0compose.yaml"
SET "COMPOSE_SERVICE=notebook"
SET "EXEC_ARGS="
SET "EXEC_COMMAND="
SET "COMPOSE_DOWN_AFTER=0"
SET "JOB_NAME=compose-job"
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
SET "LOG_FILE=%LOG_DIR%\%JOB_NAME%_%STAMP%.log"
SET "RC=0"
SET "COMPOSE=docker compose -f "%COMPOSE_FILE%""

CALL :log "START service=%COMPOSE_SERVICE% job=%JOB_NAME%"

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

REM --- 2. make sure the service is up ------------------------------------------
REM --wait returns once the service is running (or healthy, if it defines a
REM healthcheck), so no guessed "timeout /t 10" is needed.
%COMPOSE% up -d --wait %COMPOSE_SERVICE% >>"%LOG_FILE%" 2>&1
IF ERRORLEVEL 1 (
    CALL :log "ERROR: service %COMPOSE_SERVICE% did not start, see the compose output above"
    SET "RC=12"
    GOTO finish
)

REM --- 3. run the job inside it --------------------------------------------------
REM -T: no pseudo-terminal. Scheduled runs have no console to attach one to.
REM EXEC_ARGS go before the service name (e.g. -e VAR=value).
CALL :log "RUN exec %EXEC_ARGS% %COMPOSE_SERVICE% %EXEC_COMMAND%"
%COMPOSE% exec -T %EXEC_ARGS% %COMPOSE_SERVICE% %EXEC_COMMAND% >>"%LOG_FILE%" 2>&1
SET "RC=%ERRORLEVEL%"
IF "%RC%"=="0" (
    CALL :log "OK: job finished"
) ELSE (
    CALL :log "ERROR: job exited with code %RC%"
)

REM --- 4. optionally stop the service again --------------------------------------
IF "%COMPOSE_DOWN_AFTER%"=="1" %COMPOSE% down >>"%LOG_FILE%" 2>&1

:finish
REM --- 5. rotate logs ----------------------------------------------------------
FORFILES /P "%LOG_DIR%" /M *.log /D -%KEEP_LOG_DAYS% /C "cmd /c del @path" >NUL 2>&1
CALL :log "END exit=%RC%"
EXIT /B %RC%

REM --- helper: start Docker Desktop unless it's already running ----------------
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
