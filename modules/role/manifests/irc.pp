class role::irc {
    class { 'irc::ircrcbot':
        nickname    => 'MirahezeRC',
        network     => 'chat.freenode.net',
        channel     => '#miraheze-feed',
        port        => '5070',
        sleeptime   => '0.5',
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
