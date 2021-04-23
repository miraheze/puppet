# role: irc
class role::irc {
    include irc::irclogbot

    class { 'irc::ircrcbot':
        nickname     => 'MirahezeRC',
        network      => 'chat.freenode.net',
        network_port => '6697',
        channel      => '#miraheze-feed',
        udp_port     => '5070',
    }
 
    $firewallRulesIrc = query_facts('Class[Role::Mediawiki]', ['ipaddress', 'ipaddress6'])
    $firewallRulesIrc.each |$key, $value| {
        ufw::allow { "ircrcbot port ${value['ipaddress']} IPv4":
            proto => 'udp',
            port  => 5070,
            from  => $value['ipaddress'],
        }

        ufw::allow { "ircrcbot port ${value['ipaddress6']} IPv6":
            proto => 'udp',
            port  => 5070,
            from  => $value['ipaddress6'],
        }
    }

    class { 'irc::irclogserverbot':
        nickname     => 'MirahezeLSBot',
        network      => 'chat.freenode.net',
        network_port => '6697',
        channel      => '#miraheze-sre',
        port         => '5071',
    }

    $firewallall = query_facts('Class[Base]', ['ipaddress', 'ipaddress6'])
    $firewallall.each |$key, $value| {
        ufw::allow { "irclogserverbot port ${value['ipaddress']} IPv4":
            proto => 'udp',
            port  => 5071,
            from  => $value['ipaddress'],
        }

        ufw::allow { "irclogserverbot port ${value['ipaddress6']} IPv6":
            proto => 'udp',
            port  => 5071,
            from  => $value['ipaddress6'],
        }
    }

    motd::role { 'role::irc':
        description => 'IRC bots server',
    }
}
