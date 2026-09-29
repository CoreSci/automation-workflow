"""ChemSpider compound lookup and report builder (Tkinter GUI).

Problem: gathering identifiers and properties for a list of compounds (formula,
masses, logP estimates, SMILES, structures, spectra) by hand, one web search at
a time, is slow and error-prone.

How it works: a small Tkinter window with four actions:
  * **Browse Molecule** - search ChemSpider by name/formula and print name,
    monoisotopic mass, formula and ChemSpider ID for every hit.
  * **Add ChemSpi ID** - look up one ID (or type ``list`` to batch-process the names
    in ``Projects/moleculeList.csv``), add its properties to a working list, and save
    its JCAMP spectrum, 2D/3D/raw MOL files and PNG image under ``Projects/``.
  * **Create / Append Report** - write the working list to ``Projects/reports/<name>.csv``.
  * **Empty Working List** - reset.

Setup: ``pip install chemspipy`` and set ``CHEMSPIDER_API_KEY`` (see ``.env.example``).
Create the output folders first: ``Projects/{spectrums,mol2d,mol3d,molraw,images,reports}``.

Compatibility note: written against the legacy ChemSpider web services with
chemspipy 1.x (``alogp``, ``xlogp``, ``spectra`` and ``mol_raw`` attributes). The current
RSC Compounds API and chemspipy 2.x drop some of these fields.
"""
from chemspipy import ChemSpider
from tkinter import *
from tkinter import messagebox
import os

# Output root; sub-folders: spectrums, mol2d, mol3d, molraw, images, reports
PROJECT_DIR = "Projects"


def processMoleculeList():
    """Read compound names (one per line) from Projects/moleculeList.csv for batch lookup."""
    moleculeList = []
    file = os.path.join(PROJECT_DIR, "moleculeList.csv")
    readFile = open(file, 'r')

    for line in readFile:
        moleculeList.append(line[0:len(line)-1])

    readFile.close()
    print(moleculeList)

    return moleculeList


class ChemSpider_Environment(Tk):

    def __init__(self):

        super().__init__()

        self.title("Scientific Software Prototype")
        self.resizable(width=False, height=False)

        self.frame1 = Frame(self)
        self.frame1.grid(column=0,columnspan=8,row=0, rowspan=4)

        self.surface5 = Canvas(self.frame1, bd=0, bg='white', width=600)
        self.surface5.grid(column=0, columnspan=8, row=0, rowspan=8)

        self.entry1 = Entry(self.frame1)
        self.entry1.grid(column=2, columnspan=4, row=0, rowspan=1,sticky=W+E)
        self.entry2 = Entry(self.frame1)
        self.entry2.grid(column=2, columnspan=4, row=1, rowspan=1,sticky=W+E)
        self.entry3 = Entry(self.frame1)
        self.entry3.grid(column=2, columnspan=4, row=2, rowspan=1,sticky=W+E)

        self.button1a = Button(self.frame1, text="Browse Molecule : ", command=self.button_response1)
        self.button1a.grid(column=0, columnspan=2, row=0, rowspan=1, sticky=W+E)
        self.button2a = Button(self.frame1, text="Add ChemSpi ID : ", command=self.button_response2)
        self.button2a.grid(column=0, columnspan=2, row=1, rowspan=1, sticky=W+E)
        self.button3a = Button(self.frame1, text="Create / Append Report : ", command=self.button_response3)
        self.button3a.grid(column=0, columnspan=2, row=2, rowspan=1, sticky=W+E)
        self.button4a = Button(self.frame1, text="Empty Working List : ", command=self.button_response4)
        self.button4a.grid(column=0, columnspan=2, row=3, rowspan=1, sticky=W+E)

        self.list_molView = []
        print("Working List Empty ...", "\n")

    def ChemSpider_Engine(self):
        # API key comes from an environment variable (see .env.example); never hard-code it.
        #   export CHEMSPIDER_API_KEY=...        (PowerShell: $env:CHEMSPIDER_API_KEY = "...")
        ChemSpi_token = os.environ["CHEMSPIDER_API_KEY"]
        cs = ChemSpider(ChemSpi_token)
        return cs

    def button_response1(self):
        print("Working List : ")
        for element in self.list_molView:
            print(element[0][1])

        print(" ")

        print("Searching Query ...", "\n")

        try:
            value = self.entry1.get()

            cs = self.ChemSpider_Engine()

            for result in cs.search(value):
                c = cs.get_compound(result.csid)

                try:
                    print("molecule name : ", c.common_name)
                except UnicodeEncodeError:  # console can't display the name as-is
                    print("Name contains characters the console can't display; showing UTF-8 bytes")
                    byteName = c.common_name.encode('utf8')
                    print("molecule name : ", byteName)

                print("monoisotopic mass : ", c.monoisotopic_mass)
                print("molecule formula : ", c.molecular_formula)
                print("ChemSpider ID : ", c.csid)
                print(" ")

            print("Search Completed ...", "\n")

        except Exception as exc:  # network, auth or API errors
            print(f"Search failed: {exc}")
            messagebox.showerror("ChemSpider search failed", str(exc))

    def button_response2(self):
        print("Searching ChemSpider ID ...", "\n")

        aList = []

        if self.entry2.get() == "list":
            aList = processMoleculeList()
            print(aList)
        else:
            cs = self.ChemSpider_Engine()
            csid = self.entry2.get()
            c = cs.get_compound(csid)
            aList.append(c.common_name)

        for element in aList:

            print(element)

            try:
                list_temp = []
                cs = self.ChemSpider_Engine()

                for result in cs.search(element):
                    c = cs.get_compound(result.csid)

                    common_name = ("name", c.common_name)
                    molecular_weight = ("molecular weight", c.molecular_weight)
                    molecular_formula = ("molecular formula", c.molecular_formula)
                    alogp = ("alogp", c.alogp)
                    xlogp = ("xlogp", c.xlogp)
                    smiles = ("smiles", c.smiles)
                    csid = ("csid", c.csid)
                    monoisotopic_mass = ("monoisotopic mass", c.monoisotopic_mass)
                    molecule_image = ("molecule image", c.image_url)

                    list_temp.append(common_name)
                    list_temp.append(molecular_weight)
                    list_temp.append(molecular_formula)
                    list_temp.append(alogp)
                    list_temp.append(xlogp)
                    list_temp.append(smiles)
                    list_temp.append(csid)
                    list_temp.append(monoisotopic_mass)
                    list_temp.append(molecule_image)

                    self.list_molView.append(list_temp)
                    print("Added to working list ...", "\n")

            except Exception as exc:
                print(f"Lookup failed for {element!r}: {exc}")

            try:
                query = c.common_name

                fileSpectrum = open(os.path.join(PROJECT_DIR, "spectrums", query+"_spectrum.jdx"), 'a')
                fileSpectrum.write(c.spectra[0].data)
                fileSpectrum.close()

                fileMol2D = open(os.path.join(PROJECT_DIR, "mol2d", query+"_mol2D.mol"), 'a')
                fileMol2D.write(c.mol_2d)
                fileMol2D.close()

                fileMol3D = open(os.path.join(PROJECT_DIR, "mol3d", query+"_mol3D.mol"), 'a')
                fileMol3D.write(c.mol_3d)
                fileMol3D.close()

                fileMolraw = open(os.path.join(PROJECT_DIR, "molraw", query+"_molraw.mol"), 'a')
                fileMolraw.write(c.mol_raw)
                fileMolraw.close()

                fileImage = open(os.path.join(PROJECT_DIR, "images", query+".png"), 'wb')
                fileImage.seek(0)
                fileImage.truncate()
                fileImage.write(c.image)
                fileImage.close()

            except Exception as exc:  # some records have no spectra / 3D structure
                print(f"Could not save structure/spectrum files: {exc}")

    def button_response3(self):

        print("Create / Append Report ...", "\n")

        report_name = self.entry3.get()

        file = os.path.join(PROJECT_DIR, "reports", report_name + ".csv")
        writeFile = open(file, 'a')



        i = 0
        while i < len(self.list_molView):

            j=0
            while j <(len(self.list_molView[i])):
                writeFile.write(str(self.list_molView[i][j][0]))
                writeFile.write(', ')
                writeFile.write(' : ')
                writeFile.write(', ')

                try:
                   writeFile.write(str(self.list_molView[i][j][1]))

                except UnicodeEncodeError:

                    byteChaine = self.list_molView[i][j][1].encode('utf8')

                    writeFile.write(str(byteChaine))

                    print("Stored non-ASCII value as UTF-8 bytes:", byteChaine)

                writeFile.write(', ')
                writeFile.write("\n")
                j = j + 1

            # blank separator line between compounds
            writeFile.write(', ')
            writeFile.write("\n")

            i = i + 1

        writeFile.close()

        print("Report Created / Modified ...")
        print(" ")

    def button_response4(self):

        self.list_molView = []

        print("Working List Empty ...")
        print(" ")

if __name__ =="__main__":
    ChemSpider_Environment().mainloop()
