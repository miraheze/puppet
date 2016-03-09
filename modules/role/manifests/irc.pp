class role::irc {
    class { 'irc::ircrcbot':
        nickname     => 'MirahezeRC',
        network      => 'chat.freenode.net',
        network_port => '6667',
        channel      => '#miraheze-feed',
        udp_port     => '5070',
        sleeptime    => '0.5',
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
}
