# == Class: restbase

class restbase {
    include nginx

    include nodejs

    group { 'restbase':
        ensure => present,
    }

    user { 'restbase':
        ensure     => present,
        gid        => 'restbase',
        shell      => '/bin/false',
        home       => '/srv/restbase',
        managehome => false,
        system     => true,
    }

    git::clone { 'restbase_deploy':
        ensure             => present,
        directory          => '/srv/restbase',
        origin             => 'https://github.com/wikimedia/mediawiki-services-restbase-deploy.git',
        branch             => 'master',
        owner              => 'restbase',
        group              => 'restbase',
        mode               => '0755',
        timeout            => '550',
        recurse_submodules => true,
        require            => [User['restbase'], Group['restbase']],
    }

    include ssl::wildcard

    nginx::site { 'restbase':
        ensure  => present,
        source  => 'puppet:///modules/restbase/nginx/restbase',
        monitor => false,
    }

    require_package('libsqlite3-dev')

    file { '/etc/mediawiki/restbase':
        ensure => directory,
    }

    $wikis = loadyaml('/etc/puppet/parsoid/parsoid.yaml')

    file { '/etc/mediawiki/restbase/config.yaml':
        ensure  => present,
        content => template('restbase/config.yaml'),
        require => File['/etc/mediawiki/restbase'],
    }

    file { '/var/log/restbase':
        ensure  => directory,
        owner   => 'restbase',
        group   => 'restbase',
        require => [User['restbase'], Group['restbase']],
    }

    exec { 'restbase reload systemd':
        command     => '/bin/systemctl daemon-reload',
        refreshonly => true,
    }

    file { '/etc/systemd/system/restbase.service':
        ensure => present,
        source => 'puppet:///modules/restbase/restbase.systemd',
        notify => Exec['restbase reload systemd'],
    }

    service { 'restbase':
        ensure     => running,
        require    => [
            File['/etc/systemd/system/restbase.service'],
            Git::Clone['restbase_deploy'],
        ],
    }

    logrotate::conf { 'restbase':
        ensure => present,
        source => 'puppet:///modules/restbase/logrotate.conf',
    }
}
