# define: irc::relaybot
define irc::relaybot (
    String        $dotnet_version,
    VMlib::Ensure $ensure = present,
) {
    $install_path = "/srv/${title}"

    $bot_token = lookup("passwords::irc::${title}::bot_token")
    $irc_password = lookup("passwords::irc::${title}::irc_password")

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

    if $ensure == present {
        file { $install_path:
            ensure => ensure_directory($ensure),
            owner  => 'irc',
            group  => 'irc',
            mode   => '0755',
            before => Git::Clone["IRC-Discord-Relay-${title}"],
        }
    }

    $repo_ensure = $ensure ? {
        present => latest,
        default => $ensure,
    }

    git::clone { "IRC-Discord-Relay-${title}":
        ensure    => $repo_ensure,
        origin    => 'https://github.com/miraheze/IRC-Discord-Relay',
        directory => $install_path,
        owner     => 'irc',
        group     => 'irc',
        mode      => '0755',
    }

    file { [
        "${install_path}/.nuget",
        "${install_path}/.nuget/NuGet"
    ]:
        ensure  => ensure_directory($ensure),
        owner   => 'irc',
        group   => 'irc',
        mode    => '0644',
        require => Git::Clone["IRC-Discord-Relay-${title}"],
    }

    file { "${install_path}/.nuget/NuGet/NuGet.Config":
        ensure  => $ensure,
        owner   => 'irc',
        group   => 'irc',
        mode    => '0644',
        source  => 'puppet:///modules/irc/NuGet.Config',
        before  => Exec["${title}-build"],
        require => [
            File["${install_path}/.nuget"],
            File["${install_path}/.nuget/NuGet"],
        ],
    }

    if $ensure == present {
        exec { "${title}-build":
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
            require     => Git::Clone["IRC-Discord-Relay-${title}"],
        }
    } else {
        exec { "${title}-build":
            noop    => true,
            command => '/usr/bin/true',  # Do nothing but maintain the resource for below require
        }
    }

    file { [
        "${install_path}/bin/Release/net${dotnet_version}/.nuget",
        "${install_path}/bin/Release/net${dotnet_version}/.nuget/NuGet"
    ]:
        ensure  => ensure_directory($ensure),
        owner   => 'irc',
        group   => 'irc',
        mode    => '0644',
        require => Exec["${title}-build"],
    }

    file { "${install_path}/bin/Release/net${dotnet_version}/.nuget/NuGet/NuGet.Config":
        ensure  => $ensure,
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
        ensure  => $ensure,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => template("irc/relaybot/config-${title}.ini.erb"),
        require => Git::Clone["IRC-Discord-Relay-${title}"],
        notify  => Service[$title],
    }

    systemd::service { $title:
        ensure  => $ensure,
        content => systemd_template('relaybot'),
        restart => true,
        require => [
            Git::Clone["IRC-Discord-Relay-${title}"],
            Package["dotnet-sdk-${dotnet_version}"],
            File["${install_path}/config.ini"],
        ],
    }

    monitoring::nrpe { "IRC-Discord Relay Bot ${title}":
        ensure  => $ensure,
        command => "/usr/lib/nagios/plugins/check_procs -a ${title}/ -c 2:2",
    }
}
