@ECHO OFF
REM Start a throw-away TensorFlow Jupyter container as root with sudo enabled,
REM so system packages (e.g. a Java runtime for tabula-py) can be installed from the notebook terminal.

docker run -it --rm -p 8888:8888 --user root -e GRANT_SUDO=yes jupyter/tensorflow-notebook:latest

REM ---- Reference only: Dockerfile instructions for building a custom image (not batch commands) ----
CMD ["bash", "-c", "apt-get update && apt-get install -y default-jre"]

RUN pip install nasdaq-data-link
RUN pip install yfinance
RUN pip install tabula-py