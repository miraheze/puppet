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

    $firewall_irc_rules_str = join(
        query_facts('Class[Role::Mediawiki] or Class[Role::Mediawiki_task] or Class[Role::Mediawiki_beta]', ['networking'])
        .map |$key, $value| {
            if ( $value['networking']['interfaces']['ens19'] and $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens19']['ip']} ${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } elsif ( $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } else {
                "${value['networking']['ip']} ${value['networking']['ip6']}"
            }
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )
    ferm::service { 'ircrcbot':
        proto  => 'udp',
        port   => '5070',
        srange => "(${firewall_irc_rules_str})",
    }

    ferm::service { 'ircrcbot2':
        proto  => 'udp',
        port   => '5072',
        srange => "(${firewall_irc_rules_str})",
    }

    $firewall_all_rules_str = join(
        query_facts('Class[Base]', ['networking'])
        .map |$key, $value| {
            if ( $value['networking']['interfaces']['ens19'] and $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens19']['ip']} ${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } elsif ( $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } else {
                "${value['networking']['ip']} ${value['networking']['ip6']}"
            }
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )
    ferm::service { 'irclogserverbot':
        proto  => 'udp',
        port   => '5071',
        srange => "(${firewall_all_rules_str})",
    }

    system::role { 'irc':
        description => 'IRC bots server',
    }
}
