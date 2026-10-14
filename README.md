# Automation & Workflow

Patterns and examples for automating repetitive technical work: containerized environments, API integration, document processing, device setup and scheduling.

> **Credentials must be supplied by the user:** scripts that need keys or passwords read them from environment variables. See each folder's `.env.example`. No real credentials are stored in this repo.

## Structure

| Folder | Contents |
|---|---|
| `docker/jupyter-datascience/` | One-command Jupyter + TensorFlow environments from the official Docker images: launch scripts plus notes on root/sudo, HTTPS and extra packages |
| `docker/docker-cleanup.md` | Cheat sheet for checking Docker disk usage and cleaning up containers, images, volumes and build cache, with the destructive commands flagged |
| `environment-setup/` | Reproducible Python virtual environments on Windows (virtualenv, pip bootstrap, `requirements.txt`) |
| `apis/chemspider-lookup/` | Tkinter tool that batch-queries the ChemSpider API, downloads structures and spectra, and builds CSV reports. 🔑 API key required |
| `apis/soap-client-example/` | Calling a SOAP/WSDL service with `suds` (the API pattern still common in legacy enterprise systems). *Adapted from a suds tutorial example* |
| `apis/telnet-client/` | Scripted Telnet login + command for devices with only a Telnet console. *Adapted from the Python `telnetlib` docs example*. Python ≤ 3.12 |
| `document-automation/` | Merging numbered PDFs with `pypdf` and PyMuPDF (`pip install pypdf pymupdf`), with table-of-contents output |
| `raspberry-pi-setup/` | Runbook for a Raspberry Pi control host: display, LAMP/WordPress web interface, CGI endpoints, GUI autostart and `@reboot` cron jobs. Credentials are placeholders |
| `scheduling/docker-task-scheduler/` | Run a containerized Python job on a schedule with Windows Task Scheduler: Docker Compose and plain `docker run` wrappers, an importable task definition, a registration script and a scheduled-report notebook example |
| `logging/` | Logging framework setups and best practices. *Planned* |

## Philosophy

Automation here is treated as a workflow-continuity problem, not just a scripting exercise. The goal is systems that are reliable, observable through logging, and easy to hand off or reproduce.

## Status

🚧 Under active development.
