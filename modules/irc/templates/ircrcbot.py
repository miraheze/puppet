#!/usr/bin/python3

import socket
import ssl
import time

## Settings
### IRC
server = "<%= @network %>"
port = <%= @network_port %>
channel = "<%= @channel %>"
botnick = "<%= @nickname %>"

# Create a UDP socket
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

irc_C = socket.socket(socket.AF_INET, socket.SOCK_STREAM) #defines the socket
irc = ssl.wrap_socket(irc_C)

print("Establishing connection to [%s]" % (server))

# Bind the socket to the port
server_address = ('185.52.1.76', 5070)
sock.bind(server_address)

# Connect
irc.connect((server, port))

irc.setblocking(False)

irc.send(bytes("USER "+ botnick +" "+ botnick +" "+ botnick +" :Miraheze\n", "UTF-8"))

irc.send(bytes("NICK "+ botnick +"\n", "UTF-8"))

time.sleep(3)

irc.send(bytes("NICKSERV IDENTIFY mirahezebots <%= @mirahezebots_password %>\n", "UTF-8"))

time.sleep(3)

irc.send(bytes("JOIN "+ channel +"\n", "UTF-8"))


while True:
    time.sleep(2)

    data, address = sock.recvfrom(4096)

    irc.send(bytes("PRIVMSG %s :%s" % (channel, data.decode("UTF-8")), "UTF-8"))

    try:
        text = irc.recv(2040).decode("UTF-8")
        print(text)

        # Prevent Timeout
        if text.find('PING :') != -1:
            irc.send(bytes('PONG ' + channel + '\r\n', "UTF-8"))
    except Exception:
        continue
