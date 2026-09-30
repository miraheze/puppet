# type: bots::ircrcbot
define bots::ircrcbot(
    $nickname     = undef,
    $network      = undef,
    $network_port = '6697',
    $channel      = undef,
    $udp_port     = '5070',
) {
    include bots

    $mirahezebots_password = lookup('passwords::bots::mirahezebots')

    file { "/usr/local/bin/ircrcbot-${nickname}.py":
            ensure  => present,
            content => template('bots/ircrcbot.py'),
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
