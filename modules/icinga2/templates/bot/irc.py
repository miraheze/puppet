#!/usr/bin/python3

import socket
import ssl
import time

## Settings
### IRC
server = "chat.freenode.net"
port = 6697
channel = "#miraheze"
botnick = "icinga-miraheze"

### Tail
tail_files = [
    '/var/log/icinga2/irc.log'
]

irc_C = socket.socket(socket.AF_INET, socket.SOCK_STREAM) #defines the socket
irc = ssl.wrap_socket(irc_C)

print("Establishing connection to [%s]" % (server))
# Connect
irc.connect((server, port))
irc.setblocking(False)
irc.send(bytes("USER "+ botnick +" "+ botnick +" "+ botnick +" :Miraheze\n", "UTF-8"))
irc.send(bytes("NICK "+ botnick +"\n", "UTF-8"))
irc.send(bytes("NICKSERV IDENTIFY mirahezebots <%= @mirahezebots_password %>\n", "UTF-8"))
irc.send(bytes("JOIN "+ channel +"\n", "UTF-8"))


tail_line = []
for i, tail in enumerate(tail_files):
    tail_line.append('')


while True:
    time.sleep(2)

    # Tail Files
    for i, tail in enumerate(tail_files):
        try:
            f = open(tail, 'r')
            line = f.readlines()[-1]
            f.close()
            if tail_line[i] != line:
                tail_line[i] = line
                irc.send(bytes("PRIVMSG %s :%s" % (channel, line), "UTF-8"))
        except Exception as e:
            print("Error with file %s" % (tail))
            print(e)

    try:
        text=irc.recv(2040)
        print(text)

        # Prevent Timeout
        if text.find('PING') != -1:
            irc.send(bytes('PONG ' + text.split() [1] + '\r\n', "UTF-8"))
    except Exception:
        continue
