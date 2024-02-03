# class: irc::cvtbot
class irc::cvtbot {
    $install_path = '/srv/cvtbot'

    $password = lookup('passwords::irc::cvtbot')

    file { $install_path:
        ensure    => 'directory',
        owner     => 'irc',
        group     => 'irc',
        mode      => '0644',
        recurse   => true,
        max_files => 5000,
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
        "${install_path}/src/CVTBot/.nuget",
        "${install_path}/src/CVTBot/.nuget/NuGet"
    ]:
        ensure  => directory,
        owner   => 'irc',
        group   => 'irc',
        mode    => '0644',
        require => Git::Clone['CVTBot'],
    }

    file { "${install_path}/src/CVTBot/.nuget/NuGet/NuGet.Config":
        ensure  => present,
        owner   => 'irc',
        group   => 'irc',
        mode    => '0644',
        source  => 'puppet:///modules/irc/cvtbot/NuGet.Config',
        before  => Exec['CVTBot-build'],
        require => [
            File["${install_path}/src/CVTBot/.nuget"],
            File["${install_path}/src/CVTBot/.nuget/NuGet"],
        ],
    }

    exec { 'CVTBot-build':
        command     => 'dotnet build --configuration Release',
        creates     => "${install_path}/src/CVTBot/bin",
        unless      => "test -d ${install_path}/src/CVTBot/bin/Release/net6.0",
        cwd         => "${install_path}/src/CVTBot",
        path        => '/usr/bin',
        environment => [
            "HOME=${install_path}/src/CVTBot",
            'HTTP_PROXY=http://bastion.wikitide.net:8080',
        ],
        user        => 'irc',
        require     => Git::Clone['CVTBot'],
    }

    file { [
        "${install_path}/src/CVTBot/bin/Release/net6.0/.nuget",
        "${install_path}/src/CVTBot/bin/Release/net6.0/.nuget/NuGet"
    ]:
        ensure  => directory,
        owner   => 'irc',
        group   => 'irc',
        mode    => '0644',
        require => Exec['CVTBot-build'],
    }

    file { "${install_path}/src/CVTBot/bin/Release/net6.0/.nuget/NuGet/NuGet.Config":
        ensure  => present,
        owner   => 'irc',
        group   => 'irc',
        mode    => '0644',
        source  => 'puppet:///modules/irc/cvtbot/NuGet.Config',
        require => [
            File["${install_path}/src/CVTBot/bin/Release/net6.0/.nuget"],
            File["${install_path}/src/CVTBot/bin/Release/net6.0/.nuget/NuGet"],
        ],
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
            Exec['CVTBot-build'],
            File["${install_path}/src/CVTBot.ini"],
        ],
    }

    monitoring::nrpe { 'CVT Bot':
        command => '/usr/lib/nagios/plugins/check_procs -a cvtbot -c 2:2'
    }
}
