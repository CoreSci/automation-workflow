# Scheduled Docker jobs on Windows: batch launchers + Task Scheduler

A reusable pattern for running containerised jobs on a schedule on a Windows PC, unattended, with a log for every run and an exit code that Task Scheduler understands.

**Problem it solves:** a script that works when you run it by hand often fails silently on a schedule. It starts in the wrong folder, Docker isn't up yet after logon, yesterday's run is still going, or it errors out and nobody sees the message. This pattern handles each of those in small batch files that you can read in one sitting.

Two launchers, for the two common shapes of a scheduled job:

```
 Task Scheduler ──(06:00)──► run-container.bat ───► docker run --rm <image> <command>          fresh container per run
                  or       ► run-compose-job.bat ─► docker compose up -d --wait               long-running service,
                                                    docker compose exec -T <service> <command>  job exec'd into it
        ▲                          │
        └──── exit code ◄──────────┴── logs\<name>_<timestamp>.log   (all output, both launchers)
```

| Use | When |
|---|---|
| `run-container.bat` | Each run should start clean: the image holds everything the job needs, and nothing is kept between runs |
| `run-compose-job.bat` | The environment should stay up between runs: a heavy image, a warm service, or several jobs sharing one container |

## Files

| File | Role |
|---|---|
| `run-container.bat` | One-shot launcher: optionally starts Docker Desktop, waits for the engine, prevents overlapping runs, runs the container, logs everything, rotates old logs, returns the exit code |
| `run-compose-job.bat` | Service launcher: the same start-up, waiting, logging and exit-code handling, but brings a Compose service up (`--wait`) and runs the job inside it with `exec` |
| `config.example.bat` | Settings for both launchers. Copy to `config.bat`, which is git-ignored |
| `compose.yaml` | The example long-running service: a Jupyter image kept alive with no server and no open port |
| `notebooks/scheduled-report.ipynb` | Example job for `run-compose-job.bat`: a notebook executed headless that writes a CSV and a chart from **synthetic** data. Set `FAIL=1` to test the failure path |
| `job/job.py` | Example job for `run-container.bat`: writes one file to `output/`. Set `FAIL=1` to test the failure path |
| `task-definition.xml` | Task Scheduler definition: daily trigger, no overlapping instances, catch-up after missed runs, time limit, retries |
| `register-task.bat` | Registers the XML for the current user, for either launcher |

Each launcher is self-contained, so either one can be copied on its own. That's why they repeat a few helper sections.

## Quick start

```bat
copy config.example.bat config.bat

run-container.bat                         :: one-shot example; read the log in logs\
run-compose-job.bat                       :: notebook example; results in output\

register-task.bat                                         :: schedule run-container.bat (task "DockerScheduledJob")
register-task.bat NotebookReport run-compose-job.bat      :: or schedule the notebook job
schtasks /Run /TN "DockerScheduledJob"
```

Requires Docker Desktop. The one-shot example uses the public `python:3.12-slim` image. The notebook example uses `quay.io/jupyter/scipy-notebook`, a large image (about 3.8 GB) that is pulled once on the first run.

## How the launchers handle unattended runs

| Failure mode on a schedule | What the launchers do |
|---|---|
| Task Scheduler starts in `C:\Windows\System32` | `CD /D "%~dp0"` moves to the script's own folder, so relative paths work |
| Docker Desktop isn't running at all | With `START_DOCKER_DESKTOP=1`, the launcher checks for its process (`tasklist`) and starts it if needed |
| Docker Desktop is still starting after logon, wake or a restart | Polls `docker info` every 10 s for up to `DOCKER_WAIT_SECONDS`, then gives up with exit code 10. No fixed sleep: a fast start isn't delayed, and a slow one isn't cut short |
| The previous run is still going | `run-container.bat` checks for a running container with the same fixed name and skips, logging why. Both rely on Task Scheduler's "do not start a new instance" as well |
| A crashed run left a stopped container behind | `run-container.bat`: `docker rm -f` clears it, so the fixed `--name` is free again |
| The service takes a while to come up | `run-compose-job.bat`: `docker compose up -d --wait` returns once the service is running and healthy, instead of a guessed pause |
| Output scrolls away in a hidden console | Every line, from the script and from the job (stdout **and** stderr), goes to one log file per run |
| `%DATE%` format differs between Windows locales | Log and output file names use a PowerShell timestamp (`yyyyMMdd-HHmmss`), which is the same everywhere. It's set before `config.bat` is loaded, so settings can use `%STAMP%` |
| Logs fill the disk over months | `FORFILES` deletes logs older than `KEEP_LOG_DAYS` |
| Nobody notices a failure | The launchers exit with the job's exit code, which Task Scheduler shows as **Last Run Result** |

Exit codes: `0` success (or skipped, see the log), `10` Docker engine not reachable, `11` `config.bat` missing, `12` the Compose service didn't start. For `run-container.bat`, `125` means `docker run` itself failed (bad image name, bad arguments) and `126`/`127` mean the command inside the image couldn't run. Anything else is the job's own exit code.

A failed one-shot run's log (the example job with `FAIL=1`) looks like this. The line prefixes use the PC's own `%DATE%`/`%TIME%` format:

```
[Tue 09/29/2026 21:27:25.34] START image=python:3.12-slim container=scheduled-job
[Tue 09/29/2026 21:27:26.04] RUN docker run --rm --name scheduled-job -v "C:\jobs\docker-task-scheduler\job:/job:ro" -v "C:\jobs\docker-task-scheduler\output:/output" -e JOB_NAME=example -e FAIL=1 python:3.12-slim python /job/job.py
example: started at 2026-09-30 01:27:26 UTC
example: FAIL=1 set, simulating an error
[Tue 09/29/2026 21:27:26.89] ERROR: job exited with code 3
[Tue 09/29/2026 21:27:26.90] END exit=3
```

And a start that overlaps a run still in progress:

```
[Tue 09/29/2026 21:27:39.16] START image=python:3.12-slim container=scheduled-job
[Tue 09/29/2026 21:27:39.84] SKIP: container scheduled-job is still running from an earlier start
[Tue 09/29/2026 21:27:39.91] END exit=0
```

## Scheduled notebooks: `run-compose-job.bat` + `jupyter nbconvert`

The notebook example keeps a Jupyter image running as a service, and each scheduled run executes a notebook inside it, headless:

```bat
jupyter nbconvert --to notebook --execute --ExecutePreprocessor.timeout=1800 ^
    --output-dir /home/jovyan/output --output scheduled-report_%STAMP% ^
    /home/jovyan/work/scheduled-report.ipynb
```

- `--execute` runs every cell top to bottom, like *Run All*. A cell that raises an exception stops the run and makes `nbconvert` exit non-zero, so a broken notebook shows up as a failed task.
- `--ExecutePreprocessor.timeout` limits how long any one cell may run (seconds). A hung cell fails the run instead of blocking it forever.
- The **executed copy** of the notebook is saved with all its outputs (`scheduled-report_<timestamp>.ipynb`), next to the files it writes. Each run leaves a readable record of exactly what it computed.
- Parameters reach the notebook as environment variables (`EXEC_ARGS=-e RUN_STAMP=%STAMP%`), so the notebook itself never needs editing between runs.

A run's log, and the files it leaves in `output\`:

```
[Wed 09/30/2026 11:33:05.84] START service=notebook job=scheduled-report
 Container docker-task-scheduler-notebook-1  Started
 Container docker-task-scheduler-notebook-1  Healthy
[Wed 09/30/2026 11:33:12.95] RUN exec -e RUN_STAMP=20260930-113305 notebook jupyter nbconvert --to notebook --execute ...
[NbConvertApp] Converting notebook /home/jovyan/work/scheduled-report.ipynb to notebook
[NbConvertApp] Writing 7112 bytes to /home/jovyan/output/scheduled-report_20260930-113305.ipynb
[Wed 09/30/2026 11:33:17.77] OK: job finished
[Wed 09/30/2026 11:33:17.79] END exit=0

output\report_20260930-113305.csv            hourly statistics
output\report_20260930-113305.png            chart
output\scheduled-report_20260930-113305.ipynb   the executed notebook, with outputs
```

With `FAIL=1` in `EXEC_ARGS`, the notebook raises in its first code cell. The log then holds the traceback, followed by `ERROR: job exited with code 1` and `END exit=1`.

`compose.yaml` notes:

- `command: ["sleep", "infinity"]` keeps the container up without starting a notebook server, so no port is opened and there's no token to manage.
- The Jupyter images ship a `HEALTHCHECK` that probes the notebook server. With no server running, `up --wait` would report the container as unhealthy, so the file replaces it with a check that only confirms the container is up. (`healthcheck: disable: true` doesn't work here: `--wait` then fails with "no healthcheck configured".)
- The notebooks folder is mounted read-only, and results go to `output/`. Pin the image tag once the job works, so a new `latest` can't change a scheduled job overnight.
- `COMPOSE_DOWN_AFTER=1` stops the service after each run, trading memory for a slower next start.

## Task Scheduler settings, and why

| Setting | Value | Why |
|---|---|---|
| Logon type | *Run only when user is logged on* (`InteractiveToken`) by default | Simplest and safest: no password is stored in the task, and Docker Desktop is normally already running in your session. See the next section for running while logged off |
| Run level | Least privilege | The job doesn't need admin rights. Keep it that way unless a setup proves otherwise |
| If the task is already running | Do not start a new instance (`IgnoreNew`) | A second layer of overlap protection, on top of the container-name check |
| Run as soon as possible after a missed start | On (`StartWhenAvailable`) | A laptop that was off at 06:00 still runs the job when it's next on |
| Wake the computer to run this task | Off (`WakeToRun`) | Turn it on (`<WakeToRun>true</WakeToRun>`) to run on time from sleep. The PC wakes, runs the job and, with default power settings, goes back to sleep |
| Stop the task if it runs longer than | 2 hours | A hung job doesn't block every later run |
| If the task fails, restart every | 15 minutes, up to 2 times | Rides out a transient problem, e.g. the network not up yet |
| Power | Runs on battery | Change `DisallowStartIfOnBatteries` if the job is heavy |

### Running while nobody is logged on

Docker Desktop is a desktop application: it normally starts when you sign in, and runs in your session. A task set to *Run only when user is logged on* therefore has nothing to talk to after a restart until someone signs in.

A task can still run with nobody signed in. This setup was verified over several weeks on a real weekday task, including mornings after restarts with no sign-in, when the job still ran and completed every time:

1. In Task Scheduler, open the task → *General* → **Run whether user is logged on or not**. Windows asks for your password and stores it with the task (`LogonType` becomes `Password`). In that setup the task also had *Run with highest privileges* ticked; whether it's strictly needed wasn't tested separately.
2. Set `START_DOCKER_DESKTOP=1` in `config.bat`. When Docker Desktop isn't running, the launcher starts it within the task's own session, then waits for the engine as usual. On later runs it finds Docker Desktop already running and goes straight to the job.
3. Check the logs, not just Task Scheduler's *Last Run Result*. Run the job once after a restart without signing in, and confirm the log shows `Docker Desktop not running: starting it` followed by a finished job.

The trade-off is a stored password. If the password changes, the task stops running until you re-enter it in its properties.

### Weekdays only

The shipped XML runs daily. For Monday to Friday, replace the `<ScheduleByDay>` block inside `<CalendarTrigger>` with:

```xml
<ScheduleByWeek>
  <WeeksInterval>1</WeeksInterval>
  <DaysOfWeek>
    <Monday /><Tuesday /><Wednesday /><Thursday /><Friday />
  </DaysOfWeek>
</ScheduleByWeek>
```

Or with `schtasks`: `/SC WEEKLY /D MON,TUE,WED,THU,FRI /ST 07:00`. Other schedules go in the same `<Triggers>` block: `<DaysInterval>7</DaysInterval>` for weekly, or a `<LogonTrigger>` to run at each logon.

### Without the XML: plain `schtasks`

For a simple daily task, one command is enough. It doesn't set the overlap, catch-up or retry options above:

```bat
schtasks /Create /TN "DockerScheduledJob" /SC DAILY /ST 06:00 /TR "\"%CD%\run-container.bat\"" /IT
```

`/IT` gives the same "only when logged on" behaviour. If you edit the XML and register it with `schtasks /Create /XML` instead of `register-task.bat`, save it as UTF-16 first (Notepad: *Save as → Encoding: UTF-16 LE*). `schtasks` expects that encoding.

## Adapting it to a real job

1. Pick the launcher: a fresh container per run (`run-container.bat`) or a job inside a long-running service (`run-compose-job.bat`).
2. Build or pick an image that contains the job's code and dependencies. Mount only what the job needs, and mount inputs read-only (`:ro`).
3. Set the launcher's settings in `config.bat`. Give each scheduled job its own folder, container or service name, and task name.
4. Keep secrets out of `config.bat`, `compose.yaml` and the XML. Put them in a git-ignored env file: `--env-file "%~dp0job.env"` in `DOCKER_ARGS`, or `env_file:` in `compose.yaml`.
5. Make the job itself exit non-zero on failure, so the failure reaches the log and Task Scheduler.
6. Test by hand; then with `FAIL=1`; then with Docker Desktop closed; then, if the task runs while logged off, after a restart without signing in. Check each log.

## Notes / Lessons Learned

- Test the scheduled path, not just the manual one. Most scheduling bugs come from differences in working directory, user, environment and timing, not from the job's code.
- `ERRORLEVEL` inside a parenthesised `IF` block is read when the block is parsed. The launchers save `%ERRORLEVEL%` to `RC` immediately after the job for that reason.
- `docker run --rm` removes the container when the job ends, so the fixed name is free for the next run. That's what makes the "still running?" check reliable.
- Batch files need CRLF line endings, or `GOTO` and `CALL :label` can misbehave. `.gitattributes` enforces that.
- `ECHO ... exit=0>>log` doesn't write "exit=0" to the log. The trailing `0` is parsed as a handle number (`0>>` redirects stdin), so the line is lost. Putting the redirect first, `>>log ECHO ...`, avoids this for any message that ends in a digit.
- Call helper files by full path (`CALL "%~dp0config.bat"`), not by bare name. When `NoDefaultCurrentDirectoryInExePath` is set, cmd doesn't search the current folder, and a bare `config.bat` is "not recognized".

**Mistakes from a first version of a scheduled pipeline script**, all avoided here:

- **A timestamp taken once.** `SET TIMESTAMP=%date% %time%` at the top, then `echo [%TIMESTAMP%] ...` on every line, stamps the *start* time on the whole log, so a 40-minute run looks instantaneous. Expand `%DATE% %TIME%` at the moment each line is written, as `:log` does.
- **A wait loop that never gives up.** `:wait` / `docker info` / `GOTO wait` with no counter hangs forever if Docker never starts. Only Task Scheduler's time limit ends it, hours later, with no log line saying why. Count the attempts and fail with a clear message and exit code.
- **Always exiting 0.** Logging "FAILED" but then reaching the end of the script without `EXIT /B <code>` reports success to Task Scheduler. *Last Run Result* shows `0x0` every day, even on days the job failed. Carry the job's exit code to the end of the script.
- **Unicode box-drawing characters and LF line endings.** A batch file saved from an editor as UTF-8 with `═══` banners and Unix line endings mostly works, until it doesn't. cmd reads the file in the console's code page, so the characters turn to garbage in the log, and LF-only lines can break `GOTO`/`CALL :label`. Keep batch files ASCII with CRLF.
- **A fixed pause instead of a readiness check.** `timeout /t 45` after starting Docker Desktop, and `timeout /t 10` after `docker compose up -d`, are too long on a fast day and too short on a slow one. Poll `docker info`, and use `docker compose up --wait`.
