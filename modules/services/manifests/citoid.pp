# == Class: services::citoid

class services::citoid {

    include ::services

    group { 'citoid':
        ensure => present,
    }

    user { 'citoid':
        ensure     => present,
        gid        => 'citoid',
        shell      => '/bin/false',
        home       => '/srv/citoid',
        managehome => false,
        system     => true,
    }

    git::clone { 'zotero':
        ensure             => present,
        directory          => '/srv/zotero',
        origin             => 'https://github.com/wikimedia/mediawiki-services-zotero.git',
        branch             => 'master',
        owner              => 'citoid',
        group              => 'citoid',
        mode               => '0755',
        timeout            => '550',
        recurse_submodules => true,
        require            => [
            User['citoid'],
            Group['citoid']
        ],
    }

    git::clone { 'citoid':
        ensure             => present,
        directory          => '/srv/citoid',
        origin             => 'https://github.com/wikimedia/citoid.git',
        branch             => 'master',
        owner              => 'citoid',
        group              => 'citoid',
        mode               => '0755',
        timeout            => '550',
        recurse_submodules => true,
        require            => [
            User['citoid'],
            Group['citoid']
        ],
    }

    exec { 'zotero_npm':
        command     => 'npm install --cache /tmp/npm_cache_citoid',
        creates     => '/srv/zotero/node_modules',
        cwd         => '/srv/zotero',
        path        => '/usr/bin',
        environment => 'HOME=/srv/zotero',
        user        => 'citoid',
        require     => [
            Git::Clone['zotero'],
            Package['nodejs']
        ],
    }

    exec { 'citoid_npm':
        command     => 'npm install --cache /tmp/npm_cache_citoid',
        creates     => '/srv/citoid/node_modules',
        cwd         => '/srv/citoid',
        path        => '/usr/bin',
        environment => 'HOME=/srv/citoid',
        user        => 'citoid',
        require     => [
            Git::Clone['citoid'],
            Package['nodejs']
        ],
    }

    file { '/etc/mediawiki/citoid':
        ensure  => directory,
        require => File['/etc/mediawiki'],
    }

    $wikis = loadyaml('/etc/puppetlabs/puppet/services/services.yaml')

    file { '/etc/mediawiki/citoid/config.yaml':
        ensure  => present,
        content => template('services/citoid/config.yaml.erb'),
        require => File['/etc/mediawiki/citoid'],
        notify  => Service['citoid'],
    }

    systemd::service { 'zotero':
        ensure  => present,
        content => systemd_template('zotero'),
        restart => true,
        require => Git::Clone['zotero'],
    }

    systemd::service { 'citoid':
        ensure  => present,
        content => systemd_template('citoid'),
        restart => true,
        require => Git::Clone['citoid'],
    }

    monitoring::services { 'zotero':
        check_command => 'tcp',
        vars          => {
            tcp_port    => '1969',
        },
    }

    monitoring::services { 'citoid':
        check_command => 'tcp',
        vars          => {
            tcp_port    => '6927',
        },
    }
}
