# class: irc::cvtbot
class irc::cvtbot {
    $install_path = '/srv/cvtbot'

    # FIXME: should be cvtbot, using relaybot for now
    $irc_password = lookup('passwords::irc::relaybot::irc_password')

    stdlib::ensure_packages('mono-complete')

    file { $install_path:
        ensure    => 'directory',
        owner     => 'irc',
        group     => 'irc',
        mode      => '0644',
        recurse   => true,
        max_files => 1500,
    }

    git::clone { 'CVTBot':
        ensure    => present,
        origin    => 'https://github.com/Universal-Omega/CVTBot',
        directory => $install_path,
        owner     => 'irc',
        group     => 'irc',
        mode      => '0644',
        require   => File[$install_path],
    }

    file { [
        "${install_path}/src/CVTBot.ini",
        "${install_path}/src/CVTBot-sample.ini"
    ]:
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => template('irc/cvtbot/CVTBot.ini.erb'),
        require => Git::Clone['CVTBot'],
        notify  => Service['cvtbot'],
    }

    systemd::service { 'cvtbot':
        ensure  => present,
        content => systemd_template('cvtbot'),
        restart => true,
        require => [
            Git::Clone['CVTBot'],
            Package['mono-complete'],
            File["${install_path}/src/CVTBot.ini"],
        ],
    }

    monitoring::nrpe { 'CVT Bot':
        command => '/usr/lib/nagios/plugins/check_procs -a cvtbot -c 2:2'
    }
}
