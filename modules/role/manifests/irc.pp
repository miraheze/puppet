# role: irc
class role::irc {
    include irc::irclogbot

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
        channel      => '#miraheze-sre',
        udp_port     => '5071',
    }

    $firewall_irc_rules = query_facts('Class[Role::Mediawiki', ['ipaddress', 'ipaddress6'])
    $firewall_irc_rules_mapped = $firewall_irc_rules.map |$key, $value| { "${value['ipaddress']} ${value['ipaddress6']}" }
    $firewall_irc_rules_str = join($firewall_irc_rules_mapped, ' ')
    ferm::service { 'ircrcbot':
        proto  => 'tcp',
        port   => '5070',
        srange => "(${firewall_irc_rules_str})",
    }

    $firewall_all_rules = query_facts('Class[Role::Mediawiki', ['ipaddress', 'ipaddress6'])
    $firewall_all_rules_mapped = $firewall_all_rules.map |$key, $value| { "${value['ipaddress']} ${value['ipaddress6']}" }
    $firewall_all_rules_str = join($firewall_all_rules_mapped, ' ')
    ferm::service { 'irclogserverbot':
        proto  => 'tcp',
        port   => '5071',
        srange => "(${firewall_all_rules_str})",
    }

    motd::role { 'role::irc':
        description => 'IRC bots server',
    }
}
