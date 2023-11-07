#!/usr/bin/python3

from twisted.internet.protocol import DatagramProtocol
from twisted.internet import reactor, ssl
from twisted.words.protocols import irc
from twisted.internet import protocol

import socket

recver = None

# Grab first valid IPv6 address for the supplied domain name
irc_network = str(socket.getaddrinfo("<%= @network %>", None, family=socket.AF_INET6)[0][4][0])


class RCBot(irc.IRCClient):
    nickname = "<%= @nickname %>"
    password = "mirahezebots:<%= @mirahezebots_password %>"
    channel = "<%= @channel %>"
    lineRate = 1

    def signedOn(self):
        global recver
        self.join(self.channel)
        print("Signed on as %s." % (self.nickname,))
        recver = self

    def joined(self, channel):
        print("Joined %s." % (channel,))

    def gotUDP(self, broadcast):
        # We ignore any errors, otherwise it will possibly fail
        # with 'unexpected end of data'.
        self.msg(self.channel, str(broadcast, 'utf-8', 'ignore'))


class RCFactory(protocol.ClientFactory):
    protocol = RCBot

    def clientConnectionLost(self, connector, reason):
        print("Lost connection (%s), reconnecting." % (reason,))
        connector.connect()

    def clientConnectionFailed(self, connector, reason):
        print("Could not connect: %s" % (reason,))


class Echo(DatagramProtocol):

    def datagramReceived(self, data, host_port):
        global recver
        (host, port) = host_port
        if recver:
            recver.gotUDP(data)


reactor.listenUDP(<%= @udp_port %>, Echo(), interface='::')  # noqa: E225,E999
<% if @network_port == '6697' %>  # noqa: E225
reactor.connectSSL(irc_network, <%= @network_port %>, RCFactory(), ssl.ClientContextFactory())  # noqa: E225
<% else %>  # noqa: E225
reactor.connectTCP(irc_network, <%= @network_port %>, RCFactory())  # noqa: E225
<% end %>  # noqa: E225
reactor.run()
