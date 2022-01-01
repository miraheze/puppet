# role: irc
class role::irc {
    include irc::irclogbot

    $use_new_mon = lookup('use_new_mon', {'default_value' => false})

    if $use_new_mon {
        $interface = '::'
    } else {
        $interface = ''
    }

    class { 'irc::ircrcbot':
        nickname     => 'MirahezeRC',
        network      => 'irc.libera.chat',
        network_port => '6697',
        channel      => '#miraheze-feed',
        udp_port     => '5070',
        interface    => $interface,
    }

    class { 'irc::irclogserverbot':
        nickname     => 'MirahezeLSBot',
        network      => 'irc.libera.chat',
        network_port => '6697',
        channel      => '#miraheze-sre',
        udp_port     => '5071',
    }

    $firewall_irc_rules_str = join(
        query_facts('Class[Role::Mediawiki]', ['ipaddress', 'ipaddress6'])
        .map |$key, $value| {
            "${value['ipaddress']} ${value['ipaddress6']}"
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

    $firewall_all_rules_str = join(
        query_facts('Class[Base]', ['ipaddress', 'ipaddress6'])
        .map |$key, $value| {
            "${value['ipaddress']} ${value['ipaddress6']}"
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

    motd::role { 'role::irc':
        description => 'IRC bots server',
    }
}
