@ECHO OFF
REM ---------------------------------------------------------------------------
REM register-task.bat - register a launcher as a scheduled task.
REM
REM Usage:  register-task.bat [TASK_NAME] [SCRIPT]
REM         TASK_NAME  default: DockerScheduledJob
REM         SCRIPT     default: run-container.bat (or run-compose-job.bat)
REM
REM Reads task-definition.xml, replaces __SCRIPT_DIR__ with this folder and
REM __SCRIPT__ with the launcher's file name, and
REM registers the task for the current user with Register-ScheduledTask.
REM Passing the XML as a string avoids the file-encoding pitfalls of
REM "schtasks /Create /XML" (which expects the file saved as UTF-16).
REM Re-running it updates the existing task (-Force).
REM
REM Remove the task:  schtasks /Delete /TN "DockerScheduledJob" /F
REM Run it now:       schtasks /Run /TN "DockerScheduledJob"
REM ---------------------------------------------------------------------------
SETLOCAL
SET "TASK_NAME=%~1"
IF "%TASK_NAME%"=="" SET "TASK_NAME=DockerScheduledJob"
SET "SCRIPT=%~2"
IF "%SCRIPT%"=="" SET "SCRIPT=run-container.bat"
IF NOT EXIST "%~dp0%SCRIPT%" (
    ECHO ERROR: %SCRIPT% not found next to register-task.bat.
    EXIT /B 1
)
SET "SCRIPT_DIR=%~dp0"
SET "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$xml = (Get-Content -Raw -LiteralPath '%SCRIPT_DIR%\task-definition.xml') -replace '__SCRIPT_DIR__', $env:SCRIPT_DIR -replace '__SCRIPT__', $env:SCRIPT;" ^
  "Register-ScheduledTask -TaskName $env:TASK_NAME -Xml $xml -Force | Out-Null;" ^
  "Get-ScheduledTask -TaskName $env:TASK_NAME | Format-List TaskName, State, @{n='Action';e={$_.Actions.Execute}}"
IF ERRORLEVEL 1 (
    ECHO ERROR: registration failed.
    EXIT /B 1
)
ECHO Registered "%TASK_NAME%". Check it in Task Scheduler or run: schtasks /Query /TN "%TASK_NAME%" /V /FO LIST
