# == Class: services::restbase

class services::restbase {

    include ::services

    require_package('libsqlite3-dev')

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

    git::clone { 'restbase':
        ensure             => present,
        directory          => '/srv/restbase',
        origin             => 'https://github.com/wikimedia/restbase.git',
        branch             => 'v1.1.4',
        owner              => 'restbase',
        group              => 'restbase',
        mode               => '0755',
        recurse_submodules => true,
        require            => [
            User['restbase'],
            Group['restbase']
        ],
    }

    exec { 'restbase_npm':
        command     => 'sudo -u root npm install',
        creates     => '/srv/restbase/node_modules',
        cwd         => '/srv/restbase',
        path        => '/usr/bin',
        environment => 'HOME=/srv/restbase',
        user        => 'root',
        require     => [
            Git::Clone['restbase'],
            Package['nodejs']
        ],
    }

    include ::nginx

    include ssl::wildcard

    nginx::site { 'restbase':
        ensure  => present,
        source  => 'puppet:///modules/services/nginx/restbase',
        monitor => false,
    }

    file { '/etc/mediawiki/restbase':
        ensure  => directory,
        require => File['/etc/mediawiki'],
    }

    $wikis = loadyaml('/etc/puppetlabs/puppet/services/services.yaml')

    file { '/etc/mediawiki/restbase/config.yaml':
        ensure  => present,
        content => template('services/restbase/config.yaml.erb'),
        require => File['/etc/mediawiki/restbase'],
        notify  => Service['restbase'],
    }

    file { '/etc/mediawiki/restbase/miraheze_project_v1.yaml':
        ensure  => present,
        source  => 'puppet:///modules/services/restbase/miraheze_project_v1.yaml',
        require => File['/etc/mediawiki/restbase'],
        notify  => Service['restbase'],
    }

    file { '/etc/mediawiki/restbase/miraheze_project_sys.yaml':
        ensure  => present,
        source  => 'puppet:///modules/services/restbase/miraheze_project_sys.yaml',
        require => File['/etc/mediawiki/restbase'],
        notify  => Service['restbase'],
    }

    file { '/etc/mediawiki/restbase/mathoid.yaml':
        ensure  => present,
        source  => 'puppet:///modules/services/restbase/mathoid.yaml',
        require => File['/etc/mediawiki/restbase'],
        notify  => Service['restbase'],
    }

    systemd::service { 'restbase':
        ensure  => present,
        content => systemd_template('restbase'),
        restart => true,
        require => Git::Clone['restbase'],
    }

    monitoring::services { 'restbase':
        check_command => 'tcp',
        vars          => {
            tcp_port    => '7231',
        },
    }
}
