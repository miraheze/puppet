# define: irc::relaybot
define irc::relaybot (
    String $instance,
    String $dotnet_version
) {
    $install_path = "/srv/${instance}"

    $bot_token = lookup("passwords::irc::${instance}::bot_token")
    $irc_password = lookup("passwords::irc::${instance}::irc_password")

    $http_proxy = lookup('http_proxy', {'default_value' => undef})
    if $http_proxy and !defined(File['/etc/apt/apt.conf.d/01irc']) {
        file { '/etc/apt/apt.conf.d/01irc':
            ensure  => present,
            content => template('irc/aptproxy.erb'),
            before  => Package['packages-microsoft-prod'],
        }
    }

    if !defined(Package['packages-microsoft-prod']) {
        file { '/opt/packages-microsoft-prod.deb':
            ensure => present,
            source => 'puppet:///modules/irc/packages-microsoft-prod.deb',
        }

        package { 'packages-microsoft-prod':
            ensure   => installed,
            provider => dpkg,
            source   => '/opt/packages-microsoft-prod.deb',
            require  => File['/opt/packages-microsoft-prod.deb'],
        }
    }

    if !defined(Package["dotnet-sdk-${dotnet_version}"]) {
        package { "dotnet-sdk-${dotnet_version}":
            ensure  => installed,
            require => Package['packages-microsoft-prod'],
        }
    }

    file { $install_path:
        ensure => 'directory',
        owner  => 'irc',
        group  => 'irc',
        mode   => '0755',
    }

    git::clone { "IRC-Discord-Relay-${instance}":
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
        require => Git::Clone["IRC-Discord-Relay-${instance}"],
    }

    file { "${install_path}/.nuget/NuGet/NuGet.Config":
        ensure  => present,
        owner   => 'irc',
        group   => 'irc',
        mode    => '0644',
        source  => 'puppet:///modules/irc/NuGet.Config',
        before  => Exec["${instance}-build"],
        require => [
            File["${install_path}/.nuget"],
            File["${install_path}/.nuget/NuGet"],
        ],
    }

    exec { "${instance}-build":
        command     => 'dotnet build --configuration Release',
        creates     => "${install_path}/bin",
        unless      => "test -d ${install_path}/bin/Release/net${dotnet_version}",
        cwd         => $install_path,
        path        => '/usr/bin',
        environment => [
            "HOME=${install_path}",
            'HTTP_PROXY=http://bastion.wikitide.net:8080',
        ],
        user        => 'irc',
        require     => Git::Clone["IRC-Discord-Relay-${instance}"],
    }

    file { [
        "${install_path}/bin/Release/net${dotnet_version}/.nuget",
        "${install_path}/bin/Release/net${dotnet_version}/.nuget/NuGet"
    ]:
        ensure  => directory,
        owner   => 'irc',
        group   => 'irc',
        mode    => '0644',
        require => Exec["${instance}-build"],
    }

    file { "${install_path}/bin/Release/net${dotnet_version}/.nuget/NuGet/NuGet.Config":
        ensure  => present,
        owner   => 'irc',
        group   => 'irc',
        mode    => '0644',
        source  => 'puppet:///modules/irc/NuGet.Config',
        require => [
            File["${install_path}/bin/Release/net${dotnet_version}/.nuget"],
            File["${install_path}/bin/Release/net${dotnet_version}/.nuget/NuGet"],
        ],
    }

    file { "${install_path}/config.ini":
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => template("irc/relaybot/config-${instance}.ini.erb"),
        require => Git::Clone["IRC-Discord-Relay-${instance}"],
        notify  => Service[$instance],
    }

    systemd::service { $instance:
        ensure  => present,
        content => systemd_template('relaybot'),
        restart => true,
        require => [
            Git::Clone["IRC-Discord-Relay-${instance}"],
            Package["dotnet-sdk-${dotnet_version}"],
            File["${install_path}/config.ini"],
        ],
    }

    if !defined(Monitoring::Nrpe['IRC-Discord Relay Bot']) {
        monitoring::nrpe { 'IRC-Discord Relay Bot':
            command => '/usr/lib/nagios/plugins/check_procs -a relaybot -c 4:4'
        }
    }
}
