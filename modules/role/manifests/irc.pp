# role: irc
class role::irc {
    include base
    include irc::irclogbot
    include irc::cvtbot

    users::user { 'pywikibot':
        ensure => present,
        uid    => 3200,
        shell  => '/bin/bash',
    }

    include irc::pywikibot

    irc::relaybot { 'relaybot':
        dotnet_version => '10.0',
    }

    irc::ircrcbot { 'RCBot1' :
        nickname     => 'MirahezeRC',
        network      => 'irc.libera.chat',
        network_port => '6697',
        channel      => '#miraheze-feed',
        udp_port     => '5070',
    }

    class { 'irc::irclogserverbot':
        nickname     => 'MirahezeLSBot',
        network      => 'irc.libera.chat',
        network_port => '6697',
        channel      => '#miraheze-tech-ops',
        udp_port     => '5071',
    }

    irc::ircrcbot { 'RCBot2' :
        nickname     => 'MirahezeRC2',
        network      => 'irc.libera.chat',
        network_port => '6697',
        channel      => '#miraheze-feed',
        udp_port     => '5072',
    }


    firewall::service { 'ircrcbot':
        proto  => 'udp',
        port   => 5070,
        src_sets => ['MEDIAWIKI_HOSTS', 'MEDIAWIKI_TASK_HOSTS', 'MEDIAWIKI_BETA_HOSTS'],
    }

    firewall::service { 'ircrcbot2':
        proto  => 'udp',
        port   => 5072,
        src_sets => ['MEDIAWIKI_HOSTS', 'MEDIAWIKI_TASK_HOSTS', 'MEDIAWIKI_BETA_HOSTS'],
    }


    firewall::service { 'irclogserverbot':
        proto  => 'udp',
        port   => 5071,
        src_sets => ['ALL_HOSTS'],
    }

    system::role { 'irc':
        description => 'IRC bots server',
    }
}
