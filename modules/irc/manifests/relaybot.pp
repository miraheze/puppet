class irc::relaybot {
    $apt_transport_package = 'apt-transport-https'
    $gpg_file = '/etc/apt/trusted.gpg.d/microsoft.gpg'
    $install_path = '/srv/relaybot'

    $bot_token = lookup('passwords::irc::relaybot::bot_token')
    $irc_password = lookup('passwords::irc::relaybot::irc_password')

    package { $apt_transport_package:
        ensure => installed,
    }

    file { $gpg_file:
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
        require  => [
            File[$gpg_file],
            Package[$apt_transport_package],
        ],
        notify   => Exec['apt_update'],
    }

    package { 'dotnet-sdk-6.0':
        ensure => installed,
        require => Apt::Source['microsoft'],
    }

    git::clone { 'IrcToDiscordRelay':
        ensure     => latest,
        source     => 'https://github.com/Universal-Omega/IrcToDiscordRelay',
        target     => $install_path,
        user       => 'irc',
        group      => 'irc',
        target_dir => '',
    }

    file { "${install_path}/config.ini":
        ensure  => file,
        owner   => 'irc',
        group   => 'irc',
        mode    => '0644',
        content => template('irc/relaybot/config.ini.erb'),
        require => Git::Clone['IrcToDiscordRelay'],
    }

    systemd::service { 'relaybot':
        ensure  => present,
        content => systemd_template('irc/relaybot.service.erb'),
        restart => true,
        require => [
            Git::Clone[$install_path],
            Package['dotnet-sdk-6.0'],
            File["${install_path}/config.ini"],
        ],
        environment => ['HOME=/home/irc'],
    }
}
