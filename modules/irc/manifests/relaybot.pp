# class: irc::relaybot
class irc::relaybot {
    $gpg_file = '/etc/apt/trusted.gpg.d/microsoft.gpg'
    $install_path = '/srv/relaybot'

    $bot_token = lookup('passwords::irc::relaybot::bot_token')
    $irc_password = lookup('passwords::irc::relaybot::irc_password')

    $http_proxy = lookup('http_proxy', {'default_value' => undef})
    if $http_proxy {
        file { '/etc/apt/apt.conf.d/01irc':
            ensure  => present,
            content => template('irc/relaybot/aptproxy.erb'),
            before  => Apt::Source['microsoft'],
        }
    }

    file { '/opt/packages-microsoft-prod.deb':
        ensure => present,
        source => 'puppet:///modules/irc/relaybot/packages-microsoft-prod.deb',
    }

    package { 'packages-microsoft-prod':
        ensure   => installed,
        provider => dpkg,
        source   => '/opt/packages-microsoft-prod.deb',
        require  => File['/opt/packages-microsoft-prod.deb'],
    }

    Package['packages-microsoft-prod'] -> Exec['apt_update']

    package { 'dotnet-sdk-6.0':
        ensure => installed,
        require => Apt::Source['microsoft'],
    }

    file { $install_path:
        ensure => 'directory',
        owner  => 'irc',
        group  => 'irc',
        mode   => '0755',
    }

    git::clone { 'IrcToDiscordRelay':
        ensure    => latest,
        origin    => 'https://github.com/Universal-Omega/IrcToDiscordRelay.git',
        directory => $install_path,
        owner     => 'irc',
        group     => 'irc',
        mode      => '0755',
        require   => File[$install_path],
    }

    file { "${install_path}/config.ini":
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => template('irc/relaybot/config.ini.erb'),
        require => Git::Clone['IrcToDiscordRelay'],
    }

    systemd::service { 'relaybot':
        ensure  => present,
        content => systemd_template('relaybot'),
        restart => true,
        require => [
            Git::Clone['IrcToDiscordRelay'],
            Package['dotnet-sdk-6.0'],
            File["${install_path}/config.ini"],
        ],
    }

    monitoring::nrpe { 'IRC Relay Bot':
        command => '/usr/lib/nagios/plugins/check_procs -a relaybot -c 2:2'
    }
}
