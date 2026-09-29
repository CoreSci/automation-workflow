# ChemSpider lookup and report builder

A Tkinter tool that looks up compounds on ChemSpider, collects their properties into a working list, downloads structures, images and spectra, and exports a CSV report.

**Problem it solves:** gathering identifiers and properties for a batch of compounds through manual web searches is slow and error-prone. This tool automates the lookup, the file downloads and the report.

> **Credentials must be supplied by the user:** set `CHEMSPIDER_API_KEY` in your environment (template in `.env.example`). No keys are stored in this repo.

## Run

```bash
pip install chemspipy
export CHEMSPIDER_API_KEY="..."        # PowerShell: $env:CHEMSPIDER_API_KEY = "..."
mkdir -p Projects/{spectrums,mol2d,mol3d,molraw,images,reports}
python chemspider_lookup.py
```

For batch mode, put one compound name per line in `Projects/moleculeList.csv`, then type `list` in the ID box.

## Compatibility

Written against the legacy ChemSpider web services (chemspipy 1.x). The current RSC Compounds API (chemspipy 2.x) no longer returns some fields, such as `alogp`, `xlogp`, `spectra` and `mol_raw`.
