# type: bots::ircrcbot
define bots::ircrcbot(
    String $nickname,
    String $network,
    String $channel,
    Stdlib::Port $network_port,
    Stdlib::Port $udp_port,
) {
    include bots

    $mirahezebots_password = lookup('passwords::irc::mirahezebots')

    file { "/usr/local/bin/ircrcbot-${nickname}.py":
        ensure  => present,
        content => epp('bots/ircrcbot.py.epp', {
            'network'               => $network,
            'nickname'              => $nickname,
            'mirahezebots_password' => $mirahezebots_password,
            'channel'               => $channel,
            'network_port'          => $network_port,
            'udp_port'              => $udp_port,
        }),
        mode    => '0755',
        notify  => Service["ircrcbot-${nickname}"],
    }

    systemd::service { "ircrcbot-${nickname}":
        ensure  => present,
        content => systemd_template('ircrcbot', { 'nickname' => $nickname }),
        restart => true,
    }

    monitoring::nrpe { "IRC RC Bot ${nickname}":
        command => "/usr/lib/nagios/plugins/check_procs -a ircrcbot-${nickname}.py -c 1:1",
    }
}
