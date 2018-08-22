#!/usr/bin/env python3
"""Create an SSH tunnel."""

# Includes
import argparse
import socket
import subprocess
import time
from random import randint

print("Running {0}".format(__file__))

# Get arguments
parser = argparse.ArgumentParser(description='Opens an ssh tunnel for use by a command.')
parser.add_argument("-s", "--server", help='Server to connect to.')
parser.add_argument("-p", "--sshport", type=int, help='SSH port to connect to.', default="22")
parser.add_argument("-d", "--destport", type=int, help='Port on destination machine to map to this machine.', default="5900")
parser.add_argument("-l", "--localport", type=int, help='Open port on local machine (do not set if open random port is desired).')
parser.add_argument("-r", "--destserver", help='Server on the destination side to connect to.', default="localhost")
parser.add_argument("-c", "--command", help='Run commands (none=0, vnc=1, ssh=2)', type=int, default="0")

# Save arguments.
args = parser.parse_args()
print("Server:{0}, SSH Port: {1}, Destination Port: {2}".format(args.server, args.sshport, args.destport))


### Functions ###
def checkifportisopen(port):
    """Check to see if a particluar port on the localhost is open or closed."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    # Use 2 second timeout
    sock.settimeout(2)
    # If the port is open (taken), the result will be 0. Result is non-zero if closed (available for use).
    sock_result = sock.connect_ex(('localhost', port))
    if sock_result is 0:
        return True
    else:
        return False


def getrandomport():
    """Generate a random port and test it for availability."""
    # Run until a port is found to be closed (available).
    while True:
        # Get a random number between 50000 and 60000
        randomport = randint(50000, 60000)
        # Check to see if the port is open.
        open_result = checkifportisopen(randomport)
        if open_result is False:
            print('Port {0} is available on this machine.'.format(randomport))
            break
    return randomport


### Begin code. ###
# Get a local open or random port.
if args.localport:
    networkport = args.localport
else:
    networkport = getrandomport()
p = subprocess.Popen('ssh -N {0} -p {1} -L {2}:{4}:{3}'.format(args.server, args.sshport, networkport, args.destport, args.destserver).split(), stdout=subprocess.PIPE)
# Wait for forwarding to take effect.
time.sleep(1)
# Wait until the port is open.
print("Waiting until the port is open.")
while True:
    result = checkifportisopen(networkport)
    # Exit this loop if the port is open (used by ssh in this case)
    if result is True:
        break
# Process command switches.
if args.command is 0:
    print("""
    If accessing a website at the local port:
    http://localhost:{0}
    https://localhost:{0}
    """.format(networkport))
if args.command is 1:
    subprocess.run('{0} localhost:{1}'.format("vncviewer", networkport), shell=True)
if args.command is 2:
    subprocess.run('ssh localhost -p {0}'.format(networkport), shell=True)
input("Press Enter to stop ssh.")
# Stop ssh tunnel.
p.terminate()
