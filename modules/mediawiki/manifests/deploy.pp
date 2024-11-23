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

        users::user { 'www-data':
            ensure   => present,
            uid      => 33,
            gid      => 33,
            system   => true,
            homedir  => '/var/www',
            shell    => '/bin/bash',
            before   => Service['nginx'],
            ssh_keys => [
                'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFEak8evb6DAVAeYTl8Gyg0uCrcMAfPt9CUm++4NO8fb MediaWikiDeploy',
            ],
        }
    }

    stdlib::ensure_packages(
        'langcodes',
        {
            ensure   => '3.3.0',
            provider => 'pip3',
            install_options => [ '--break-system-packages' ],
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
        ensure    => present,
        directory => '/srv/mediawiki-staging/config',
        origin    => 'https://github.com/miraheze/mw-config',
        branch    => 'master',
        owner     => 'www-data',
        group     => 'www-data',
        mode      => '0755',
        require   => File['/srv/mediawiki-staging'],
    }

    git::clone { 'landing':
        ensure    => present,
        directory => '/srv/mediawiki-staging/landing',
        origin    => 'https://github.com/miraheze/landing',
        branch    => 'master',
        owner     => 'www-data',
        group     => 'www-data',
        mode      => '0755',
        require   => File['/srv/mediawiki-staging'],
    }

    git::clone { 'ErrorPages':
        ensure    => present,
        directory => '/srv/mediawiki-staging/ErrorPages',
        origin    => 'https://github.com/miraheze/ErrorPages',
        branch    => 'master',
        owner     => 'www-data',
        group     => 'www-data',
        mode      => '0755',
        require   => File['/srv/mediawiki-staging'],
    }

    exec { 'MediaWiki Config Sync':
        ensure      => absent,
        command     => "/usr/local/bin/mwdeploy --config --servers=${lookup(mediawiki::default_sync)}",
        cwd         => '/srv/mediawiki-staging',
        refreshonly => true,
        user        => www-data,
        subscribe   => Git::Clone['MediaWiki config'],
        require     => File['/usr/local/bin/mwdeploy'],
    }

    exec { 'Landing Sync':
        ensure      => absent,
        command     => "/usr/local/bin/mwdeploy --landing --servers=${lookup(mediawiki::default_sync)} --no-log",
        cwd         => '/srv/mediawiki-staging',
        refreshonly => true,
        user        => www-data,
        subscribe   => Git::Clone['landing'],
        require     => File['/usr/local/bin/mwdeploy'],
    }

    exec { 'ErrorPages Sync':
        ensure      => absent,
        command     => "/usr/local/bin/mwdeploy --errorpages --servers=${lookup(mediawiki::default_sync)} --no-log",
        cwd         => '/srv/mediawiki-staging',
        refreshonly => true,
        user        => www-data,
        subscribe   => Git::Clone['ErrorPages'],
        require     => File['/usr/local/bin/mwdeploy'],
    }

    # This is outside of the is_canary if so that test* also pulls
    # the certificate, as that server has use_staging to true but not
    # is_canary
    file { '/srv/mediawiki-staging/mwdeploy-client-cert.key':
        ensure => present,
        source => 'puppet:///ssl-keys/mwdeploy.key',
        owner  => 'www-data',
        group  => 'www-data',
        mode   => '0444',
        before => File['/usr/local/bin/mwdeploy'],
    }
}
