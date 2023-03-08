# class: irc::relaybot
class irc::relaybot {
    $gpg_file = '/etc/apt/trusted.gpg.d/microsoft.gpg'
    $install_path = '/srv/relaybot'

    $bot_token = lookup('passwords::irc::relaybot::bot_token')
    $irc_password = lookup('passwords::irc::relaybot::irc_password')

    file { '/opt/packages-microsoft-prod.deb':
        ensure => present,
        source => 'puppet:///modules/irc/relaybot/packages-microsoft-prod.deb',
    }

    package { 'packages-microsoft-prod':
        ensure   => installed,
        provider => dpkg,
        source   => '/opt/packages-microsoft-prod.deb',
        require  => File['/opt/packages-microsoft-prod.deb'],
        notify   => Exec['apt_update'],
    }

/*    file { $gpg_file:
        ensure => present,
        owner  => 'root',
        group  => 'root',
        mode   => '0444',
        source => 'puppet:///modules/irc/relaybot/microsoft-keyring.gpg',
        notify => Exec['apt_update'],
    }

    apt::source { 'microsoft':
        comment  => 'The official Microsoft package repository',
        location => 'https://packages.microsoft.com/repos/microsoft-debian-bullseye-prod',
        release  => 'bullseye',
        repos    => 'main',
        include  => {
            'deb' => true,
            'src' => false,
        },
        require  => File[$gpg_file],
        notify   => Exec['apt_update'],
    } */

    package { 'dotnet-sdk-6.0':
        ensure => installed,
        require => Package['packages-microsoft-prod'],
    }

    file { $install_path:
        ensure => 'directory',
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
    }

    git::clone { 'IrcToDiscordRelay':
        ensure    => latest,
        origin    => 'https://github.com/Universal-Omega/IrcToDiscordRelay.git',
        directory => $install_path,
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
}
