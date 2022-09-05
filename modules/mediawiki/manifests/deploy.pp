# === Class mediawiki::deploy
#
# MediaWiki deploy files
class mediawiki::deploy {
    include mediawiki::extensionsetup

    if lookup(mediawiki::is_canary) {
        file { '/srv/mediawiki-staging/deploykey.pub':
            ensure  => present,
            content => 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDktIRXHBi4hDZvb6tBrPZ0Ag6TxLbXoQ7CkisQqOY6V MediaWikiDeploy',
            owner   => 'www-data',
            group   => 'www-data',
            mode    => '0400',
            before  => File['/usr/local/bin/deploy-mediawiki'],
        }

        file { '/srv/mediawiki-staging/deploykey':
            ensure => present,
            source => 'puppet:///private/mediawiki/mediawiki-deploy-key-private',
            owner  => 'www-data',
            group  => 'www-data',
            mode   => '0400',
            before => File['/usr/local/bin/deploy-mediawiki'],
        }

        file { '/var/www/.ssh':
            ensure => directory,
            owner  => 'www-data',
            group  => 'www-data',
            mode   => '0400',
            before => File['/usr/local/bin/deploy-mediawiki'],
        }

        file { '/var/www/.ssh/known_hosts':
            content => template('mediawiki/mw-user-known-hosts.erb'),
            owner   => 'www-data',
            group   => 'www-data',
            mode    => '0644',
            require => File['/var/www/.ssh'],
        }
    }

    ensure_packages(
        'langcodes',
        {
            ensure   => '3.3.0',
            provider => 'pip3',
            before   => File['/usr/local/bin/deploy-mediawiki'],
            require  => Package['python3-pip'],
	},
    )

    file { '/srv/mediawiki-staging':
        ensure => 'directory',
        owner  => 'www-data',
        group  => 'www-data',
        mode   => '0755',
    }

    file { '/usr/local/bin/deploy-mediawiki':
        ensure  => 'present',
        mode    => '0755',
        source  => 'puppet:///modules/mediawiki/bin/deploy-mediawiki.py',
        require => [ File['/srv/mediawiki'], File['/srv/mediawiki-staging'] ],
    }

    file { '/usr/local/bin/mwupgradetool':
        ensure  => 'present',
        mode    => '0755',
        source  => 'puppet:///modules/mediawiki/bin/mwupgradetool.py',
        require => File['/usr/local/bin/deploy-mediawiki'],
    }

    git::clone { 'MediaWiki config':
        ensure    => 'latest',
        directory => '/srv/mediawiki-staging/config',
        origin    => 'https://github.com/miraheze/mw-config.git',
        branch    => $branch_mw_config,
        owner     => 'www-data',
        group     => 'www-data',
        mode      => '0755',
        require   => File['/srv/mediawiki-staging'],
    }

    git::clone { 'MediaWiki core':
        ensure             => 'present',
        directory          => '/srv/mediawiki-staging/w',
        origin             => 'https://github.com/miraheze/mediawiki.git',
        branch             => $branch,
        owner              => 'www-data',
        group              => 'www-data',
        mode               => '0755',
        timeout            => '1500',
        depth              => '5',
        recurse_submodules => true,
        require            => File['/srv/mediawiki-staging'],
    }

    git::clone { 'landing':
        ensure    => 'latest',
        directory => '/srv/mediawiki-staging/landing',
        origin    => 'https://github.com/miraheze/landing.git',
        branch    => 'master',
        owner     => 'www-data',
        group     => 'www-data',
        mode      => '0755',
        require   => File['/srv/mediawiki-staging'],
    }

    git::clone { 'ErrorPages':
        ensure    => 'latest',
        directory => '/srv/mediawiki-staging/ErrorPages',
        origin    => 'https://github.com/miraheze/ErrorPages.git',
        branch    => 'master',
        owner     => 'www-data',
        group     => 'www-data',
        mode      => '0755',
        require   => File['/srv/mediawiki-staging'],
    }

    exec { 'MediaWiki Config Sync':
        command     => "/usr/local/bin/deploy-mediawiki --config --servers=${lookup(mediawiki::default_sync)}",
        cwd         => '/srv/mediawiki-staging',
        refreshonly => true,
        user        => www-data,
        subscribe   => Git::Clone['MediaWiki config'],
        require     => File['/usr/local/bin/deploy-mediawiki'],
    }

    exec { 'Landing Sync':
        command     => "/usr/local/bin/deploy-mediawiki --landing --servers=${lookup(mediawiki::default_sync)} --no-log",
        cwd         => '/srv/mediawiki-staging',
        refreshonly => true,
        user        => www-data,
        subscribe   => Git::Clone['landing'],
        require     => File['/usr/local/bin/deploy-mediawiki'],
    }

    exec { 'ErrorPages Sync':
        command     => "/usr/local/bin/deploy-mediawiki --errorpages --servers=${lookup(mediawiki::default_sync)} --no-log",
        cwd         => '/srv/mediawiki-staging',
        refreshonly => true,
        user        => www-data,
        subscribe   => Git::Clone['ErrorPages'],
        require     => File['/usr/local/bin/deploy-mediawiki'],
    }
}
