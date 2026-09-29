@ECHO OFF
REM Start the official TensorFlow Jupyter image on http://localhost:8888
REM (use the tokenised URL printed below). Requires Docker Desktop.
docker run -p 8888:8888 jupyter/tensorflow-notebook