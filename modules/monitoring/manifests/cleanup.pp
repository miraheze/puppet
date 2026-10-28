# class: monitoring::cleanup
class monitoring::cleanup {
    # TODO: remove once puppet runs
    systemd::service { 'ircecho':
        ensure  => absent,
        content => '',
    }

    systemd::service { 'grafana-webhook':
        ensure  => absent,
        content => '',
    }

    file { [
        '/usr/local/bin/ircecho',
        '/usr/local/lib/python3.13/dist-packages/ib3_auth.py',
        '/etc/default/ircecho',
        '/etc/default/ircecho_password',
        '/usr/local/bin/grafana-webhook.py',
        '/etc/icinga2/scripts/irc-host-notification.sh',
        '/etc/icinga2/scripts/irc-service-notification.sh',
        '/var/log/icinga2/irc.log',
    ]:
        ensure => absent,
    }

    monitoring::nrpe { 'IRCEcho':
        ensure  => absent,
        command => '/bin/true',
    }
}
