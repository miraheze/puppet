# class: irc::relaybot2
class irc::relaybot2 {
    $install_path = '/srv/relaybot2'

    $bot_token = lookup('passwords::irc::relaybot2::bot_token')
    $irc_password = lookup('passwords::irc::relaybot2::irc_password')

    file { $install_path:
        ensure => 'directory',
        owner  => 'irc',
        group  => 'irc',
        mode   => '0755',
    }

    git::clone { 'IRC-Discord-Relay-2':
        ensure    => latest,
        origin    => 'https://github.com/Universal-Omega/IRC-Discord-Relay',
        directory => $install_path,
        owner     => 'irc',
        group     => 'irc',
        mode      => '0755',
        require   => File[$install_path],
    }

    file { [
        "${install_path}/.nuget",
        "${install_path}/.nuget/NuGet"
    ]:
        ensure  => directory,
        owner   => 'irc',
        group   => 'irc',
        mode    => '0644',
        require => Git::Clone['IRC-Discord-Relay-2'],
    }

    file { "${install_path}/.nuget/NuGet/NuGet.Config":
        ensure  => present,
        owner   => 'irc',
        group   => 'irc',
        mode    => '0644',
        source  => 'puppet:///modules/irc/cvtbot/NuGet.Config',
        before  => Exec['relaybot-build-2'],
        require => [
            File["${install_path}/.nuget"],
            File["${install_path}/.nuget/NuGet"],
        ],
    }

    exec { 'relaybot-build-2':
        command     => 'dotnet build --configuration Release',
        creates     => "${install_path}/bin",
        unless      => "test -d ${install_path}/bin/Release/net6.0",
        cwd         => $install_path,
        path        => '/usr/bin',
        environment => [
            "HOME=${install_path}",
            'HTTP_PROXY=http://bastion.wikitide.net:8080',
        ],
        user        => 'irc',
        require     => Git::Clone['IRC-Discord-Relay-2'],
    }

    file { [
        "${install_path}/bin/Release/net6.0/.nuget",
        "${install_path}/bin/Release/net6.0/.nuget/NuGet"
    ]:
        ensure  => directory,
        owner   => 'irc',
        group   => 'irc',
        mode    => '0644',
        require => Exec['relaybot-build-2'],
    }

    file { "${install_path}/bin/Release/net6.0/.nuget/NuGet/NuGet.Config":
        ensure  => present,
        owner   => 'irc',
        group   => 'irc',
        mode    => '0644',
        source  => 'puppet:///modules/irc/cvtbot/NuGet.Config',
        require => [
            File["${install_path}/bin/Release/net6.0/.nuget"],
            File["${install_path}/bin/Release/net6.0/.nuget/NuGet"],
        ],
    }

    file { "${install_path}/config.ini":
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => template('irc/relaybot/config2.ini.erb'),
        require => Git::Clone['IRC-Discord-Relay-2'],
        notify  => Service['relaybot2'],
    }

    systemd::service { 'relaybot2':
        ensure  => present,
        content => systemd_template('relaybot'),
        restart => true,
        require => [
            Git::Clone['IRC-Discord-Relay-2'],
            File["${install_path}/config.ini"],
        ],
    }

    monitoring::nrpe { 'IRC-Discord Relay Bot (2)':
        command => '/usr/lib/nagios/plugins/check_procs -a relaybot2 -c 2:2'
    }
}
