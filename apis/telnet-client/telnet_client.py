"""Log in to a Telnet server, run a command and print the session output.

Problem: automate a command on a device or host that offers only a Telnet
console (older network gear, embedded controllers, lab or test equipment).

How it works: connects, answers the ``login:`` and ``Password:`` prompts
(the password is read with ``getpass``, so it's never echoed or stored),
sends ``ls`` then ``exit``, and prints everything the server returned.

Adapted from: the Python standard-library documentation, ``telnetlib``
"Telnet Example".

Security note: Telnet sends credentials in clear text. Use it only on isolated
or lab networks; prefer SSH (e.g. ``paramiko``) everywhere else.

Compatibility: ``telnetlib`` is deprecated and was removed in Python 3.13.
Run this with Python <= 3.12, or port it to ``telnetlib3``.

Run: ``python telnet_client.py [HOST] [PORT]`` (defaults: localhost 23).
"""
import getpass
import sys
import telnetlib

if __name__ == "__main__":
    HOST = sys.argv[1] if len(sys.argv) > 1 else "localhost"
    PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 23
    user = input("Enter your remote account: ")
    password = getpass.getpass()

    try:
        tn = telnetlib.Telnet(HOST, PORT, timeout=10)
    except OSError as exc:
        raise SystemExit(f"Could not connect to {HOST}:{PORT}: {exc}")

    tn.read_until(b"login: ")
    tn.write(user.encode('ascii') + b"\n")
    if password:
        tn.read_until(b"Password: ")
        tn.write(password.encode('ascii') + b"\n")

    tn.write(b"ls\n")
    tn.write(b"exit\n")

    print(tn.read_all().decode('ascii'))
