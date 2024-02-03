# class: irc::relaybot
class irc::relaybot {
    $install_path = '/srv/relaybot'

    $bot_token = lookup('passwords::irc::relaybot::bot_token')
    $irc_password = lookup('passwords::irc::relaybot::irc_password')

    $http_proxy = lookup('http_proxy', {'default_value' => undef})
    if $http_proxy {
        file { '/etc/apt/apt.conf.d/01irc':
            ensure  => present,
            content => template('irc/relaybot/aptproxy.erb'),
            before  => Package['packages-microsoft-prod'],
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

    package { 'dotnet-sdk-6.0':
        ensure  => installed,
        require => Package['packages-microsoft-prod'],
    }

    file { $install_path:
        ensure => 'directory',
        owner  => 'irc',
        group  => 'irc',
        mode   => '0755',
    }

    git::clone { 'IRC-Discord-Relay':
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
        require => Git::Clone['IRC-Discord-Relay'],
    }

    file { "${install_path}/.nuget/NuGet/NuGet.Config":
        ensure  => present,
        owner   => 'irc',
        group   => 'irc',
        mode    => '0644',
        source  => 'puppet:///modules/irc/cvtbot/NuGet.Config',
        before  => Exec['relaybot-build'],
        require => [
            File["${install_path}/.nuget"],
            File["${install_path}/.nuget/NuGet"],
        ],
    }

    exec { 'relaybot-build':
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
        require     => Git::Clone['IRC-Discord-Relay'],
    }

    file { [
        "${install_path}/bin/Release/net6.0/.nuget",
        "${install_path}/bin/Release/net6.0/.nuget/NuGet"
    ]:
        ensure  => directory,
        owner   => 'irc',
        group   => 'irc',
        mode    => '0644',
        require => Exec['relaybot-build'],
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
        content => template('irc/relaybot/config.ini.erb'),
        require => Git::Clone['IRC-Discord-Relay'],
        notify  => Service['relaybot'],
    }

    systemd::service { 'relaybot':
        ensure  => present,
        content => systemd_template('relaybot'),
        restart => true,
        require => [
            Git::Clone['IRC-Discord-Relay'],
            Package['dotnet-sdk-6.0'],
            File["${install_path}/config.ini"],
        ],
    }

    monitoring::nrpe { 'IRC-Discord Relay Bot':
        command => '/usr/lib/nagios/plugins/check_procs -a relaybot -c 2:2'
    }
}
