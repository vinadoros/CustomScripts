#!/usr/bin/env python3
import socket

sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.settimeout(2)                                      #2 Second Timeout
result = sock.connect_ex(('127.0.0.1',8384))
if result == 0:
  print('port OPEN')
else:
  print('port CLOSED, connect_ex returned: '+str(result))
