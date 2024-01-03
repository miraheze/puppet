# === Class mediawiki::deploy
#
# MediaWiki deploy files
class mediawiki::deploy {
    if lookup(mediawiki::is_canary) {
        file { '/srv/mediawiki-staging/deploykey.pub':
            ensure  => present,
            content => 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFEak8evb6DAVAeYTl8Gyg0uCrcMAfPt9CUm++4NO8fb MediaWikiDeploy',
            owner   => 'www-data',
            group   => 'www-data',
            mode    => '0400',
            before  => File['/usr/local/bin/mwdeploy'],
        }

        file { '/srv/mediawiki-staging/deploykey':
            ensure => present,
            source => 'puppet:///private/mediawiki/mediawiki-deploy-key-private',
            owner  => 'www-data',
            group  => 'www-data',
            mode   => '0400',
            before => File['/usr/local/bin/mwdeploy'],
        }

        file { '/var/www/.ssh':
            ensure => directory,
            owner  => 'www-data',
            group  => 'www-data',
            mode   => '0400',
            before => File['/usr/local/bin/mwdeploy'],
        }

        file { '/var/www/.ssh/known_hosts':
            content => template('mediawiki/mw-user-known-hosts.erb'),
            owner   => 'www-data',
            group   => 'www-data',
            mode    => '0644',
            require => File['/var/www/.ssh'],
        }
    }

    stdlib::ensure_packages(
        'langcodes',
        {
            ensure   => '3.3.0',
            provider => 'pip3',
            before   => File['/usr/local/bin/mwdeploy'],
            require  => Package['python3-pip'],
        },
    )

    file { '/srv/mediawiki-staging':
        ensure => 'directory',
        owner  => 'www-data',
        group  => 'www-data',
        mode   => '0755',
    }

    file { '/usr/local/bin/mwdeploy':
        ensure  => 'present',
        mode    => '0755',
        source  => 'puppet:///modules/mediawiki/bin/mwdeploy.py',
        require => [ File['/srv/mediawiki'], File['/srv/mediawiki-staging'] ],
    }

    file { '/usr/local/bin/deploy-mediawiki':
        ensure  => 'link',
        target  => '/usr/local/bin/mwdeploy',
        mode    => '0755',
        require => File['/usr/local/bin/mwdeploy'],
    }

    git::clone { 'MediaWiki config':
        ensure    => 'latest',
        directory => '/srv/mediawiki-staging/config',
        origin    => 'https://github.com/miraheze/mw-config',
        branch    => 'master',
        owner     => 'www-data',
        group     => 'www-data',
        mode      => '0755',
        require   => File['/srv/mediawiki-staging'],
        }

    git::clone { 'landing':
        ensure    => 'latest',
        directory => '/srv/mediawiki-staging/landing',
        origin    => 'https://github.com/miraheze/landing',
        branch    => 'master',
        owner     => 'www-data',
        group     => 'www-data',
        mode      => '0755',
        require   => File['/srv/mediawiki-staging'],
    }

    git::clone { 'ErrorPages':
        ensure    => 'latest',
        directory => '/srv/mediawiki-staging/ErrorPages',
        origin    => 'https://github.com/miraheze/ErrorPages',
        branch    => 'master',
        owner     => 'www-data',
        group     => 'www-data',
        mode      => '0755',
        require   => File['/srv/mediawiki-staging'],
    }

    exec { 'MediaWiki Config Sync':
        command     => "/usr/local/bin/mwdeploy --config --servers=${lookup(mediawiki::default_sync)}",
        cwd         => '/srv/mediawiki-staging',
        refreshonly => true,
        user        => www-data,
        subscribe   => Git::Clone['MediaWiki config'],
        require     => File['/usr/local/bin/mwdeploy'],
    }

    exec { 'Landing Sync':
        command     => "/usr/local/bin/mwdeploy --landing --servers=${lookup(mediawiki::default_sync)} --no-log",
        cwd         => '/srv/mediawiki-staging',
        refreshonly => true,
        user        => www-data,
        subscribe   => Git::Clone['landing'],
        require     => File['/usr/local/bin/mwdeploy'],
    }

    exec { 'ErrorPages Sync':
        command     => "/usr/local/bin/mwdeploy --errorpages --servers=${lookup(mediawiki::default_sync)} --no-log",
        cwd         => '/srv/mediawiki-staging',
        refreshonly => true,
        user        => www-data,
        subscribe   => Git::Clone['ErrorPages'],
        require     => File['/usr/local/bin/mwdeploy'],
    }
}
