# role: irc
class role::irc {
    include irc::irclogbot

    class { 'irc::ircrcbot':
        nickname     => 'MirahezeRC',
        network      => 'chat.freenode.net',
        network_port => '6697',
        channel      => '#miraheze-feed',
        udp_port     => '5070',
        sleeptime    => '0.5',
    }

    ufw::allow { 'ircrcbot port lizardfs6':
        proto => 'udp',
        port  => '5070',
        from  => '54.36.165.161',
    }

    ufw::allow { 'ircrcbot port mw1':
        proto => 'udp',
        port  => '5070',
        from  => '185.52.1.75',
    }

    ufw::allow { 'ircrcbot port mw2':
        proto => 'udp',
        port  => '5070',
        from  => '185.52.2.113',
    }

    ufw::allow { 'ircrcbot port mw3':
        proto => 'udp',
        port  => '5070',
        from  => '81.4.121.113',
    }

    ufw::allow { 'ircrcbot port test1':
        proto => 'udp',
        port  => '5070',
        from  => '185.52.2.243',
    }
    
    # new servers
    ufw::allow { 'ircrcbot port mw4':
        proto => 'udp',
        port  => '5070',
        from  => '51.89.160.128',
    }

    ufw::allow { 'ircrcbot port mw4':
        proto => 'udp',
        port  => '5070',
        from  => '2001:41d0:800:1056::3',
    }

    ufw::allow { 'ircrcbot port mw5':
        proto => 'udp',
        port  => '5070',
        from  => '51.89.160.133',
    }

    ufw::allow { 'ircrcbot port mw5':
        proto => 'udp',
        port  => '5070',
        from  => '2001:41d0:800:1056::8',
    }

    ufw::allow { 'ircrcbot port mw6':
        proto => 'udp',
        port  => '5070',
        from  => '51.89.160.136',
    }

    ufw::allow { 'ircrcbot port mw6':
        proto => 'udp',
        port  => '5070',
        from  => '2001:41d0:800:105a::4',
    }

    ufw::allow { 'ircrcbot port mw7':
        proto => 'udp',
        port  => '5070',
        from  => '51.89.160.137',
    }

    ufw::allow { 'ircrcbot port mw7':
        proto => 'udp',
        port  => '5070',
        from  => '2001:41d0:800:105a::5',
    }

    ufw::allow { 'ircrcbot port test2':
        proto => 'udp',
        port  => '5070',
        from  => '51.77.107.211',
    }

    ufw::allow { 'ircrcbot port test2':
        proto => 'udp',
        port  => '5070',
        from  => '2001:41d0:800:105a::3',
    }

    motd::role { 'role::irc':
        description => 'IRC bots server',
    }
}
