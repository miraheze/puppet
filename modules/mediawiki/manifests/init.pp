# class: mediawiki
class mediawiki(
    Optional[String] $branch = undef,
    Optional[String] $branch_mw_config = undef,
    Optional[Boolean] $use_memcached = undef,
) {
    include mediawiki::favicons
    include mediawiki::nginx
    include mediawiki::packages
    include mediawiki::logging
    include mediawiki::php
    include mediawiki::servicessetup


    include mediawiki::monitoring

    if lookup(jobrunner) {
        include mediawiki::jobqueue::runner
    }

    if lookup(jobchron) {
        include mediawiki::jobqueue::chron
    }
    
    if lookup(mediawiki::remote_sync) {
        users::user { 'www-data':
            ensure   => present,
            uid      => 33,
            gid      => 33,
            system   => true,
            homedir  => '/var/www',
            shell    => '/bin/bash',
            ssh_keys => [
                'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDktIRXHBi4hDZvb6tBrPZ0Ag6TxLbXoQ7CkisQqOY6V MediaWikiDeploy'
            ],
        }
        file { '/var/www/.ssh':
            ensure => directory,
            owner  => 'www-data',
            group  => 'www-data',
            mode   => '0400',
        }
        file { '/var/www/.ssh/authorized_keys':
            ensure => file,
            owner  => 'www-data',
            group  => 'www-data',
            mode   => '0400',
        }
    }
    
    if lookup(mediawiki::is_canary) {
        file { '/srv/mediawiki-staging/deploykey.pub':
            ensure => present,
            content => 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDktIRXHBi4hDZvb6tBrPZ0Ag6TxLbXoQ7CkisQqOY6V MediaWikiDeploy',
            owner  => 'www-data',
            group  => 'www-data',
            mode   => '0400',
        }

        file { '/srv/mediawiki-staging/deploykey':
            ensure => present,
            source => 'puppet:///private/mediawiki/mediawiki-deploy-key-private',
            owner  => 'www-data',
            group  => 'www-data',
            mode   => '0400',
        }
    }

    if lookup(mediawiki::use_staging) {
        include mediawiki::extensionsetup
        file { '/srv/mediawiki-staging':
            ensure => 'directory',
            owner  => 'www-data',
            group  => 'www-data',
            mode   => '0755',
        }

        git::clone { 'MediaWiki config':
            ensure    => 'latest',
            directory => '/srv/mediawiki-staging/config',
            origin    => 'https://github.com/miraheze/mw-config.git',
            branch    => $branch_mw_config,
            owner     => 'www-data',
            group     => 'www-data',
            mode      => '0755',
            require   => File['/srv/mediawiki'],
        }

        git::clone { 'MediaWiki core':
            ensure             => present,
            directory          => '/srv/mediawiki-staging/w',
            origin             => 'https://github.com/miraheze/mediawiki.git',
            branch             => $branch,
            owner              => 'www-data',
            group              => 'www-data',
            mode               => '0755',
            timeout            => '1500',
            depth              => '5',
            recurse_submodules => true,
            require            => File['/srv/mediawiki'],
        }

        git::clone { 'landing':
            ensure             => 'latest',
            directory          => '/srv/mediawiki-staging/landing',
            origin             => 'https://github.com/miraheze/landing.git',
            branch             => 'master',
            owner              => 'www-data',
            group              => 'www-data',
            mode               => '0755',
            require            => File['/srv/mediawiki'],
        }

        git::clone { 'ErrorPages':
            ensure             => 'latest',
            directory          => '/srv/mediawiki-staging/ErrorPages',
            origin             => 'https://github.com/miraheze/ErrorPages.git',
            branch             => 'master',
            owner              => 'www-data',
            group              => 'www-data',
            mode               => '0755',
            require            => File['/srv/mediawiki'],
        }

        file { '/usr/local/bin/deploy-mediawiki':
            ensure => 'present',
            mode   => '0755',
            source => 'puppet:///modules/mediawiki/bin/deploy-mediawiki.py',
        }

        file { '/usr/local/bin/mwupgradetool':
            ensure => 'present',
            mode   => '0755',
            source => 'puppet:///modules/mediawiki/bin/mwupgradetool.py',
        }

        exec { 'MediaWiki Config Sync':
            command     => "/usr/local/bin/deploy-mediawiki --config --servers=${lookup(mediawiki::default_sync)}",
            cwd         => '/srv/mediawiki-staging',
            refreshonly => true,
            user        => www-data,
            subscribe   => Git::Clone['MediaWiki config'],
        }

        exec { 'Landing Sync':
            command     => "/usr/local/bin/deploy-mediawiki --landing --servers=${lookup(mediawiki::default_sync)} --no-log",
            cwd         => '/srv/mediawiki-staging',
            refreshonly => true,
            user        => www-data,
            subscribe   => Git::Clone['landing'],
        }

        exec { 'ErrorPages Sync':
            command     => "/usr/local/bin/deploy-mediawiki --errorpages --servers=${lookup(mediawiki::default_sync)} --no-log",
            cwd         => '/srv/mediawiki-staging',
            refreshonly => true,
            user        => www-data,
            subscribe   => Git::Clone['ErrorPages'],
        }
        
        cron { 'l10n-modern-deploy':
        ensure  => present,
        command => 'deploy-mediawiki --l10nupdate --servers=${lookup(mediawiki::default_sync)}',
        user    => 'www-data',
        minute  => '0',
        hour    => '23',
        }
        
    }
    
    cron {'update.php for LocalisationUpdate':
        ensure = absent,
    }

    file { [
        '/srv/mediawiki',
        '/srv/mediawiki/w',
        '/srv/mediawiki/config',
        '/srv/mediawiki/cache',
    ]:
        ensure => 'directory',
        owner  => 'www-data',
        group  => 'www-data',
        mode   => '0755',
    }

    include ::imagemagick::install

    file { '/srv/mediawiki/robots.php':
        ensure  => 'present',
        source  => 'puppet:///modules/mediawiki/robots.php',
        require => File['/srv/mediawiki'],
    }

    file { '/srv/mediawiki/sitemap.php':
        ensure  => 'present',
        source  => 'puppet:///modules/mediawiki/sitemap.php',
        require => File['/srv/mediawiki'],
    }

    file { '/srv/mediawiki/w/LocalSettings.php':
        ensure  => 'link',
        target  => '/srv/mediawiki/config/LocalSettings.php',
        owner   => 'www-data',
        group   => 'www-data',
        require => [ File['/srv/mediawiki/w'], File['/srv/mediawiki/config'] ],
    }

    $wikiadmin_password    = lookup('passwords::db::wikiadmin')
    $mediawiki_password    = lookup('passwords::db::mediawiki')
    $redis_password        = lookup('passwords::redis::master')
    $noreply_password      = lookup('passwords::mail::noreply')
    $mediawiki_upgradekey  = lookup('passwords::mediawiki::upgradekey')
    $mediawiki_secretkey   = lookup('passwords::mediawiki::secretkey')
    $recaptcha_secretkey   = lookup('passwords::recaptcha::secretkey')
    $matomotoken           = lookup('passwords::mediawiki::matomotoken')
    $ldap_password         = lookup('passwords::mediawiki::ldap_password')

    $global_discord_webhook_url = lookup('mediawiki::global_discord_webhook_url')

    file { '/srv/mediawiki/config/PrivateSettings.php':
        ensure  => 'present',
        content => template('mediawiki/PrivateSettings.php'),
        require => File['/srv/mediawiki/config'],
    }

    file { '/usr/local/bin/fileLockScript.sh':
        ensure => 'present',
        mode   => '0755',
        source => 'puppet:///modules/mediawiki/bin/fileLockScript.sh',
    }

    file { '/usr/local/bin/foreachwikiindblist':
        ensure => 'present',
        mode   => '0755',
        source => 'puppet:///modules/mediawiki/bin/foreachwikiindblist',
    }
    
    file { '/usr/local/bin/mwscript':
        ensure => 'present',
        mode   => '0755',
        source => 'puppet:///modules/mediawiki/bin/mwscript.py',
    }
    $cookbooks = ['disable-puppet', 'enable-puppet', 'cycle-puppet', 'check-read-only']
    $cookbooks.each |$cookbook| {
        file {"/usr/local/bin/${cookbook}":
            ensure => 'present',
            mode   => '0755',
            source => "puppet:///modules/mediawiki/cookbooks/${cookbook}.py",
        }
    }
    
    file { '/srv/mediawiki/config/OAuth2.key':
        ensure  => present,
        mode    => '0755',
        source  => 'puppet:///private/mediawiki/OAuth2.key',
        require => File['/srv/mediawiki/config'],
    }

    require_package('vmtouch')

    file { '/usr/local/bin/generateVmtouch.py':
        ensure => 'present',
        mode   => '0755',
        source => 'puppet:///modules/mediawiki/bin/generateVmtouch.py',
    }

    systemd::service { 'vmtouch':
        ensure  => present,
        content => systemd_template('vmtouch'),
        restart => true,
    }

    cron { 'vmtouch':
        ensure  => present,
        command => '/usr/bin/python3 /usr/local/bin/generateVmtouch.py',
        user    => 'root',
        minute  => '0',
        hour    => '*/1',
    }

    sudo::user { 'www-data_sudo_itself':
        user       => 'www-data',
        privileges => [
            'ALL = (www-data) NOPASSWD: ALL',
        ],
    }
}
