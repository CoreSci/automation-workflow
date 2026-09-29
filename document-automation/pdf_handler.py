"""Merge numbered PDFs with PyMuPDF and report the table of contents.

Problem: same goal as ``pdf_merger.py``, rebuilt on PyMuPDF, which is faster and
keeps document structure such as bookmarks.

How it works: loads ``formats/0.pdf``, ``formats/1.pdf``, ... until one is
missing, appends documents 1..n into document 0, saves ``formats/output.pdf``
and prints the merged table of contents. Pass ``--text`` to also print the
merged text.

Usage: create a ``formats`` folder with numbered PDFs and run
``python pdf_handler.py [--text]``. Requires ``pymupdf``.
"""
from __future__ import annotations

import os
import sys

try:
    import pymupdf as fitz  # PyMuPDF >= 1.24.3
except ImportError:  # older releases only provide the `fitz` name
    import fitz

FOLDER = "formats"


def load_numbered_pdfs(folder: str = FOLDER) -> list:
    """Open folder/0.pdf, folder/1.pdf, ... until the next number is missing."""
    documents = []
    i = 0
    while True:
        # bug fix: os.path.join instead of a hard-coded Windows "formats\\" prefix
        filename = os.path.join(folder, f"{i}.pdf")
        if not os.path.isfile(filename):
            print(f"File {i} doesn't exist, stopping")
            break
        documents.append(fitz.open(filename))
        print(f"File {i} exists")
        i = i + 1
    return documents


def main() -> None:
    listeDocuments = load_numbered_pdfs()
    if not listeDocuments:
        raise SystemExit(f"No input PDFs found (expected {FOLDER}/0.pdf, {FOLDER}/1.pdf, ...)")

    # Append documents 1..n into document 0 and save the merged file
    for doc in listeDocuments[1:]:
        listeDocuments[0].insert_pdf(doc)
    output = os.path.join(FOLDER, "output.pdf")
    listeDocuments[0].save(output)
    print(f"\nSaved {output} ({listeDocuments[0].page_count} pages)")

    toc = listeDocuments[0].get_toc()
    print("TABLE of CONTENT : ", toc)

    if "--text" in sys.argv:
        print("Text Content : ")
        for page in listeDocuments[0]:
            print(page.get_text("text"))


if __name__ == "__main__":
    main()
