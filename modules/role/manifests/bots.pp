# role: bots
class role::bots {
    include base
    include bots::cvtbot
    include bots::irclogbot
    include bots::salbot

    users::user { 'pywikibot':
        ensure => present,
        uid    => 3200,
        shell  => '/bin/bash',
    }

    include bots::pywikibot

    bots::relaybot { 'relaybot':
        dotnet_version => '10.0',
    }

    class { 'bots::irclogserverbot':
        nickname     => 'MirahezeLSBot',
        network      => 'irc.libera.chat',
        channel      => '#miraheze-tech-ops',
        network_port => 6697,
        udp_port     => 5071,
    }

    bots::ircrcbot { 'RCBot1':
        nickname     => 'MirahezeRC',
        network      => 'irc.libera.chat',
        channel      => '#miraheze-feed',
        network_port => 6697,
        udp_port     => 5070,
    }

    bots::ircrcbot { 'RCBot2':
        nickname     => 'MirahezeRC2',
        network      => 'irc.libera.chat',
        channel      => '#miraheze-feed',
        network_port => 6697,
        udp_port     => 5072,
    }

    $subquery = @("PQL")
    (resources { type = 'Class' and title = 'Role::Mediawiki' } or
    resources { type = 'Class' and title = 'Role::Mediawiki_task' } or
    resources { type = 'Class' and title = 'Role::Mediawiki_beta' })
    | PQL
    $firewall_irc_rules_str = vmlib::generate_firewall_ip($subquery)

    firewall::service { 'ircrcbot':
        proto  => 'udp',
        port   => 5070,
        srange => "(${firewall_irc_rules_str})",
    }

    firewall::service { 'ircrcbot2':
        proto  => 'udp',
        port   => 5072,
        srange => "(${firewall_irc_rules_str})",
    }

    $subquery_2 = @("PQL")
    resources { type = 'Class' and title = 'Base' }
    | PQL
    $firewall_all_rules_str = vmlib::generate_firewall_ip($subquery_2)

    firewall::service { 'irclogserverbot':
        proto  => 'udp',
        port   => 5071,
        srange => "(${firewall_all_rules_str})",
    }

    system::role { 'bots':
        description => 'Bots server',
    }
}
