# == Class: services::proton
#
# Configures a pdf service using proton.
#
# === Parameters
#
# [*access_key*] A key used to access the pdf.
#
class services::proton {

    include ::services

    require_package('chromium')

    group { 'proton':
        ensure => present,
    }

    user { 'proton':
        ensure     => present,
        gid        => 'proton',
        shell      => '/bin/false',
        home       => '/srv/proton',
        managehome => false,
        system     => true,
    }

    git::clone { 'proton':
        ensure    => present,
        directory => '/srv/proton',
        origin    => 'https://github.com/wikimedia/mediawiki-services-chromium-render',
        branch    => 'master',
        owner     => 'proton',
        group     => 'proton',
        mode      => '0755',
        timeout   => '550',
        before    => Service['proton'],
        require => [
            User['proton'],
            Group['proton']
        ]
    }

    exec { 'proton_npm':
        command     => 'npm install --cache /tmp/npm_cache_proton',
        creates     => '/srv/proton/node_modules',
        cwd         => '/srv/proton',
        path        => '/usr/bin',
        environment => 'HOME=/srv/proton',
        user        => 'proton',
        before      => Service['proton'],
        notify      => Service['proton'],
        require     => [
            Git::Clone['proton'],
            Package['nodejs']
        ]
    }

    file { '/etc/mediawiki/proton':
        ensure  => directory,
        require => File['/etc/mediawiki'],
    }

    file { '/etc/mediawiki/proton/config.yaml':
        ensure  => present,
        source  => 'puppet:///modules/services/proton/config.yaml',
        require => File['/etc/mediawiki/proton'],
        notify  => Service['proton'],
    }

    systemd::service { 'proton':
        ensure  => present,
        content => systemd_template('proton'),
        restart => true,
        require => Git::Clone['proton'],
    }

    monitoring::services { 'proton':
        check_command => 'tcp',
        vars          => {
            tcp_port    => '3030',
        }
    }
}
