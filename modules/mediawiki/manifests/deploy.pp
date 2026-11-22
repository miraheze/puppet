# === Class mediawiki::deploy
#
# MediaWiki deploy files
class mediawiki::deploy {
    users::user { 'mwdeploy':
        ensure   => present,
        uid      => 40,
        gid      => 33,
        system   => true,
        homedir  => '/var/lib/mwbuild',
        shell    => '/bin/bash',
        before   => Service['nginx'],
        ssh_keys => [],
    }
    if lookup(mediawiki::is_canary) {
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
        
        file { '/srv/mediawiki-staging/deploykey.pub':
            ensure  => present,
            content => 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFEak8evb6DAVAeYTl8Gyg0uCrcMAfPt9CUm++4NO8fb MediaWikiDeploy',
            owner   => 'mwdeploy',
            group   => 'www-data',
            mode    => '0400',
            before  => File['/usr/local/bin/mwdeploy'],
        }

        file { '/srv/mediawiki-staging/deploykey':
            ensure => present,
            source => 'puppet:///private/mediawiki/mediawiki-deploy-key-private',
            owner  => 'mwdeploy',
            group  => 'www-data',
            mode   => '0400',
            before => File['/usr/local/bin/mwdeploy'],
        }

        file { '/var/lib/mwbuild/.ssh':
            ensure => directory,
            owner  => 'mwdeploy',
            group  => 'www-data',
            mode   => '0400',
            before => File['/usr/local/bin/mwdeploy'],
        }

        file { '/var/lib/mwbuild/.ssh/known_hosts':
            content => epp('mediawiki/mw-user-known-hosts.epp'),
            owner   => 'mwdeploy',
            group   => 'www-data',
            mode    => '0600',
            require => File['/var/lib/mwbuild/.ssh'],
        }
    }

    stdlib::ensure_packages(
        'langcodes',
        {
            ensure   => '3.5.1',
            provider => 'pip3',
            install_options => [
                '--break-system-packages',
                { '--proxy' => 'http://bastion.fsslc.wtnet:8080' },
            ],
            before   => File['/usr/local/bin/mwdeploy'],
            require  => Package['python3-pip'],
        },
    )

    file { '/srv/mediawiki-staging':
        ensure => 'directory',
        owner  => 'mwdeploy',
        group  => 'www-data',
        mode   => '0744',
    }

    file { '/srv/mediawiki-staging/patches':
        ensure  => 'directory',
        owner   => 'mwdeploy',
        group   => 'www-data',
        mode    => '0744',
        require => File['/srv/mediawiki-staging'],
    }

    file { '/srv/mediawiki-staging/patches/public.json':
        ensure  => 'file',
        owner   => 'mwdeploy',
        group   => 'www-data',
        mode    => '0644',
        source  => 'puppet:///mediawiki-repos/patches/public.json',
        require => File['/srv/mediawiki-staging/patches'],
    }

    file { '/srv/mediawiki-staging/patches/private.json':
        ensure  => 'file',
        owner   => 'mwdeploy',
        group   => 'www-data',
        mode    => '0644',
        source  => 'puppet:///mediawiki-repos/patches/private/private.json',
        require => File['/srv/mediawiki-staging/patches'],
    }

    file { '/srv/mediawiki-staging/patches/public':
        ensure  => 'directory',
        owner   => 'mwdeploy',
        group   => 'www-data',
        mode    => '0755',
        source  => 'puppet:///mediawiki-repos/patches/public',
        purge   => true,
        recurse => true,
        require => File['/srv/mediawiki-staging/patches'],
    }

    file { '/srv/mediawiki-staging/patches/private':
        ensure  => 'directory',
        owner   => 'mwdeploy',
        group   => 'www-data',
        mode    => '0755',
        source  => 'puppet:///mediawiki-repos/patches/private/patches',
        purge   => true,
        recurse => true,
        require => File['/srv/mediawiki-staging/patches'],
    }

    file { '/usr/local/bin/mwdeploy':
        ensure  => 'present',
        mode    => '0755',
        source  => 'puppet:///modules/mediawiki/bin/mwdeploy.py',
        require => [ File['/srv/mediawiki'], File['/srv/mediawiki-staging'] ],
    }

    git::clone { 'MediaWiki config':
        ensure    => present,
        directory => '/srv/mediawiki-staging/config',
        origin    => 'https://github.com/miraheze/mw-config',
        branch    => 'main',
        owner     => 'mwdeploy',
        group     => 'www-data',
        mode      => '0744',
        require   => File['/srv/mediawiki-staging'],
    }

    git::clone { 'landing':
        ensure    => present,
        directory => '/srv/mediawiki-staging/landing',
        origin    => 'https://github.com/miraheze/landing',
        branch    => 'main',
        owner     => 'mwdeploy',
        group     => 'www-data',
        mode      => '0744',
        require   => File['/srv/mediawiki-staging'],
    }

    git::clone { 'ErrorPages':
        ensure    => present,
        directory => '/srv/mediawiki-staging/ErrorPages',
        origin    => 'https://github.com/miraheze/ErrorPages',
        branch    => 'main',
        owner     => 'mwdeploy',
        group     => 'www-data',
        mode      => '0744',
        require   => File['/srv/mediawiki-staging'],
    }

    # This is outside of the is_canary if so that test* also pulls
    # the certificate, as that server has use_staging to true but not
    # is_canary
    file { '/srv/mediawiki-staging/mwdeploy-client-cert.key':
        ensure => present,
        source => 'puppet:///ssl-keys/mwdeploy.key',
        owner  => 'mwdeploy',
        group  => 'mwdeploy',
        mode   => '0440',
        before => File['/usr/local/bin/mwdeploy'],
    }
}
