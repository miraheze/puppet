# type: irc::ircrcbot
define irc::ircrcbot(
    $nickname     = undef,
    $network      = undef,
    $network_port = '6697',
    $channel      = undef,
    $udp_port     = '5070',
) {
    include ::irc

    $mirahezebots_password = lookup('passwords::irc::mirahezebots')

    file { "/usr/local/bin/ircrcbot-${nickname}.py":
            ensure  => present,
            content => epp('irc/ircrcbot.py.epp', { 'network' => $network, 'nickname' => $nickname, 'mirahezebots_password' => $mirahezebots_password, 'channel' => $channel, 'udp_port' => $udp_port, 'network_port' => $network_port }),
            mode    => '0755',
            notify  => Service["ircrcbot-${nickname}"],
        }

    systemd::service { "ircrcbot-${nickname}":
        ensure  => present,
        content => systemd_template('ircrcbot', { 'nickname' => $nickname }),
        restart => true,
    }

    monitoring::nrpe { "IRC RC Bot ${nickname}":
        command => "/usr/lib/nagios/plugins/check_procs -a ircrcbot-${nickname}.py -c 1:1"
    }
}
