# Python virtual environment setup (Windows)

**Problem:** Installing TensorFlow and Jupyter into the system Python causes version conflicts between projects. A per-project virtual environment keeps each project's dependencies isolated and reproducible.

## Find which Python you're using

```python
>>> import os, sys
>>> os.path.dirname(sys.executable)
```

Per-user installs live under `%LOCALAPPDATA%\Programs\Python\PythonXY` (for example `Python37`, `Python38-32`).

## Bootstrap pip and virtualenv for that interpreter

```bat
cd %LOCALAPPDATA%\Programs\Python\Python37
curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
python get-pip.py
pip install virtualenv
```

## Create, use and leave the environment

```bat
virtualenv --system-site-packages -p python3 ./venv
.\venv\Scripts\activate

pip install --upgrade pip
pip install tensorflow jupyter
pip list          :: packages installed in this environment

deactivate        :: leave the environment when you're done
```

## Reproduce the environment elsewhere

```bat
pip freeze > requirements.txt
pip install -r requirements.txt
```
