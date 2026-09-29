"""Call a SOAP web service from Python by reading its WSDL with ``suds``.

Problem: many legacy enterprise and lab systems still expose SOAP/WSDL APIs
rather than REST. ``suds`` reads the WSDL and generates the client methods, so
no hand-written XML envelopes are needed.

How it works: builds a client from the WSDL URL and calls the service's
``LetterSolutions`` operation, which finds anagrams of a word.

Adapted from: a suds SOAP-client tutorial that uses the public aonaware.com demo
services. The exact tutorial wasn't recorded, so treat this as a typical
pattern from the suds documentation and community examples.

Note: the aonaware demo services are no longer online. To run this, point
``WSDL_URL`` at any reachable WSDL and call one of its operations.
``print(client)`` lists them.

Run: ``python soap_client_demo.py`` (``pip install suds-community``).
"""
from suds import client

WSDL_URL = "http://services.aonaware.com/CountCheatService/CountCheatService.asmx?WSDL"

if __name__ == "__main__":
    try:
        cheat_client = client.Client(WSDL_URL, timeout=15)
    except Exception as exc:  # DNS failure, timeout, invalid WSDL...
        raise SystemExit(f"Could not load WSDL from {WSDL_URL}: {exc}")
    print(cheat_client.service.LetterSolutions(anagram="Anna"))
