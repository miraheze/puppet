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
        dotnet_version => '6.0',
    }

    class { 'irc::ircrcbot':
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

    $subquery = @("PQL")
    (resources { type = 'Class' and title = 'Role::Mediawik' } or
    resources { type = 'Class' and title = 'Role::Mediawiki_task' } or
    resources { type = 'Class' and title = 'Role::Mediawiki_beta' })
    | PQL
    $firewall_irc_rules_str = vmlib::generate_firewall_ip($subquery)

    ferm::service { 'ircrcbot':
        proto  => 'udp',
        port   => '5070',
        srange => "(${firewall_irc_rules_str})",
    }

    $firewall_all_rules_str = vmlib::generate_firewall_ip()

    ferm::service { 'irclogserverbot':
        proto  => 'udp',
        port   => '5071',
        srange => "(${firewall_all_rules_str})",
    }

    system::role { 'irc':
        description => 'IRC bots server',
    }
}
