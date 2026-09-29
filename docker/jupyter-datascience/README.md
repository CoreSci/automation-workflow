# Jupyter data-science stack in Docker

**Problem:** A local Python + TensorFlow + Java setup is fragile and slow to rebuild on a new machine. Running Jupyter from the official Docker images gives the same environment everywhere in one command.

## Quick start (Windows)

| Script | What it does |
|---|---|
| `run-tensorflow-notebook.bat` | Starts `jupyter/tensorflow-notebook` on <http://localhost:8888> as the default notebook user. |
| `run-notebook-with-sudo.bat` | Starts the same image as root with `GRANT_SUDO=yes`, so you can `apt-get` system packages (e.g. Java for `tabula-py`) from the notebook terminal. The lines after the `docker run` are Dockerfile instructions kept as a reference for a custom image. They are not batch commands. |

Open the URL with the token that Docker prints in the console.

## Image choices

```bash
# General data-science image (pandas, scikit-learn, matplotlib, R, Julia)
docker run -p 8888:8888 jupyter/datascience-notebook:latest

# TensorFlow image (used by the forecasting notebooks)
docker run -p 8888:8888 jupyter/tensorflow-notebook:latest
```

## Root access, sudo and HTTPS

```bash
# Throw-away container with sudo inside the notebook terminal
docker run -it --rm -p 8888:8888 --user root -e GRANT_SUDO=yes jupyter/tensorflow-notebook:latest

# Same, plus a self-signed certificate (HTTPS) and the default users group
docker run -it --rm -p 8888:8888 --user root -e NB_GID=100 -e GEN_CERT=yes -e GRANT_SUDO=yes jupyter/tensorflow-notebook:latest
```

## Extra packages used by the notebooks

Run these inside the container, from a notebook terminal:

```bash
sudo apt-get update
sudo apt install default-jre        # Java runtime, required by tabula-py
java -version

pip install --upgrade pip
pip install -r requirements.txt     # or install individually:
pip install nasdaq-data-link yfinance tabula-py nltk opencv-python
```

## Sanity checks

```bash
pip list
pip show tensorflow
python -c "import tensorflow as tf; print(tf.__version__)"
```
