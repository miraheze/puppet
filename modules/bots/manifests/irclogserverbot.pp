# class: bots::irclogserverbot
class bots::irclogserverbot(
    String       $nickname,
    String       $channel,
    Stdlib::Host $network,
    Stdlib::Port $network_port,
    Stdlib::Port $udp_port,
) {
    include bots

    $mirahezebots_password = lookup('passwords::irc::mirahezebots')

    file { '/usr/local/bin/irclogserverbot.py':
        ensure  => present,
        content => epp('bots/ircrcbot.py.epp', {
            'nickname'              => $nickname,
            'mirahezebots_password' => $mirahezebots_password,
            'channel'               => $channel,
            'network'               => $network,
            'network_port'          => $network_port,
            'udp_port'              => $udp_port,
        }),
        mode    => '0755',
        notify  => Service['irclogserverbot'],
    }

    systemd::service { 'irclogserverbot':
        ensure  => present,
        content => systemd_template('irclogserverbot'),
        restart => true,
    }

    monitoring::nrpe { 'IRC Log Server Bot':
        command => '/usr/lib/nagios/plugins/check_procs -a irclogserverbot.py -c 1:1',
    }
}
