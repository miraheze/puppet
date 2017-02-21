#! /usr/bin/python
from twisted.internet.protocol import DatagramProtocol
from twisted.internet import reactor
from twisted.words.protocols import irc
from twisted.internet import protocol
import sys
import time
 
recver = None
 
class RCBot(irc.IRCClient):
    nickname = "<%= @nickname %>"
    password = "mirahezebots:<%= @mirahezebots_password %>"
    channel = "<%= @channel %>"
    def signedOn(self):
        global recver
        self.join(self.channel)
        print "Signed on as %s." % (self.nickname,)
        recver = self
 
    def joined(self, channel):
        print "Joined %s." % (channel,)
 
    def gotUDP(self, broadcast):
        self.msg(self.channel, broadcast)
        time.sleep(<%= @sleeptime %>)
 
class RCFactory(protocol.ClientFactory):
    protocol = RCBot
 
    def clientConnectionLost(self, connector, reason):
        print "Lost connection (%s), reconnecting." % (reason,)
        connector.connect()
 
    def clientConnectionFailed(self, connector, reason):
        print "Could not connect: %s" % (reason,)
 
class Echo(DatagramProtocol):
 
    def datagramReceived(self, data, (host, port)):
        global recver
        recver.gotUDP(data)

reactor.listenUDP(<%= @udp_port %>, Echo())
reactor.connectTCP("<%= @network %>", <%= @network_port %>, RCFactory())
reactor.run()
