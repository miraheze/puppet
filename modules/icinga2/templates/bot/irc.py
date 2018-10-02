#!/usr/bin/python3

import socket
import sys
import time

## Settings
### IRC
server = "chat.freenode.net"
port = 6697
channel = "#miraheze"
botnick = "icinga-miraheze"
botnickpass = "mirahezebots"
botpass = "<%= @mirahezebots_password %>"

### Tail
tail_files = [
    '/var/log/icinga2/irc.log'
]

tail_line = []
for i, tail in enumerate(tail_files):
    tail_line.append('')

class IRC:
 
    irc = socket.socket()
  
    def __init__(self):  
        self.irc = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
 
    def send(self, chan, msg):
        self.irc.send(bytes("PRIVMSG " + chan + " " + msg + "n", "UTF-8"))
 
    def connect(self, server, port, channel, botnick, botpass, botnickpass):
        # defines the socket
        print("connecting to: " + server)

        # connects to the server
        self.irc.connect((server, port))
        # user authentication
        self.irc.send(bytes("USER " + botnick + " " + botnick +" " + botnick + " :Miraheze\n", "UTF-8"))
        self.irc.send(bytes("NICK " + botnick + "\n", "UTF-8"))
        self.irc.send(bytes("NICKSERV IDENTIFY " + botnickpass + " " + botpass + "\n", "UTF-8"))
        time.sleep(5)
        # join the chan
        self.irc.send(bytes("JOIN " + channel + "\n", "UTF-8"))
 
    def get_text(self):
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

        # receive the text
        text = self.irc.recv(2040).decode("UTF-8")
 
        if text.find('PING') != -1:                      
            self.irc.send(bytes('PONG ' + text.split()[1].decode("UTF-8") + '\r\n', "UTF-8")) 
 
        return text

irc = IRC()
irc.connect(server, port, channel, botnick, botpass, botnickpass)
 
 
while 1:
    irc.get_text()
 
    if "PRIVMSG" in text and channel in text and "hello" in text:
        irc.send(channel, "Hello!")
