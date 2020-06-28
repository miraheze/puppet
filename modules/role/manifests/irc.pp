# role: irc
class role::irc {
    include irc::irclogbot

    class { 'irc::ircrcbot':
        nickname     => 'MirahezeRC',
        network      => 'chat.freenode.net',
        network_port => '6697',
        channel      => '#miraheze-feed',
        udp_port     => '5070',
        sleeptime    => '1',
    }
    
    ufw::allow { 'ircrcbot port mw4 ipv4':
        proto => 'udp',
        port  => '5070',
        from  => '51.89.160.128',
    }

    ufw::allow { 'ircrcbot port mw4 ipv6':
        proto => 'udp',
        port  => '5070',
        from  => '2001:41d0:800:1056::3',
    }

    ufw::allow { 'ircrcbot port mw5 ipv4':
        proto => 'udp',
        port  => '5070',
        from  => '51.89.160.133',
    }

    ufw::allow { 'ircrcbot port mw5 ipv6':
        proto => 'udp',
        port  => '5070',
        from  => '2001:41d0:800:1056::8',
    }

    ufw::allow { 'ircrcbot port mw6 ipv4':
        proto => 'udp',
        port  => '5070',
        from  => '51.89.160.136',
    }

    ufw::allow { 'ircrcbot port mw6 ipv6':
        proto => 'udp',
        port  => '5070',
        from  => '2001:41d0:800:105a::4',
    }

    ufw::allow { 'ircrcbot port mw7 ipv4':
        proto => 'udp',
        port  => '5070',
        from  => '51.89.160.137',
    }

    ufw::allow { 'ircrcbot port mw7 ipv6':
        proto => 'udp',
        port  => '5070',
        from  => '2001:41d0:800:105a::5',
    }

    ufw::allow { 'ircrcbot port test2 ipv4':
        proto => 'udp',
        port  => '5070',
        from  => '51.77.107.211',
    }

    ufw::allow { 'ircrcbot port test2 ipv6':
        proto => 'udp',
        port  => '5070',
        from  => '2001:41d0:800:105a::3',
    }

    motd::role { 'role::irc':
        description => 'IRC bots server',
    }
}
