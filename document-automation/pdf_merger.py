"""Merge numbered PDF files into a single document.

Problem: combining a batch of scanned or exported PDFs by hand is tedious.

How it works: opens ``1.pdf``, ``2.pdf``, ``3.pdf`` ... from the current folder
until the next number is missing, copies every page in order into a
``PdfWriter``, and writes ``MergedFiles.pdf``.

Usage: put the numbered PDFs next to the script and run ``python pdf_merger.py``.
Requires ``pypdf`` (or ``PyPDF2`` >= 2.0, which uses the same API).
"""
from __future__ import annotations

import os

try:
    from pypdf import PdfReader, PdfWriter
except ImportError:  # PyPDF2 2.x exposes the same classes
    from PyPDF2 import PdfReader, PdfWriter

OUTPUT = 'MergedFiles.pdf'


def numbered_pdfs() -> list[str]:
    """1.pdf, 2.pdf, ... up to the first missing number."""
    files = []
    i = 1
    while os.path.isfile(f"{i}.pdf"):
        files.append(f"{i}.pdf")
        i = i + 1
    return files


def main() -> None:
    files = numbered_pdfs()
    if not files:
        raise SystemExit("No input found: expected 1.pdf, 2.pdf, ... in the current folder")

    # Append every page of every input, in file order
    pdfWriter = PdfWriter()
    for name in files:
        # a corrupt input now raises a clear error instead of silently ending the merge
        for page in PdfReader(name).pages:
            pdfWriter.add_page(page)

    # Write the merged result
    with open(OUTPUT, 'wb') as pdfOutputFile:
        pdfWriter.write(pdfOutputFile)
    print(f"merged {len(files)} files ({len(pdfWriter.pages)} pages) into {OUTPUT}")


if __name__ == "__main__":
    main()
