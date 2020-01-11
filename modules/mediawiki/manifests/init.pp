# class: mediawiki
class mediawiki(
    Optional[String] $branch = undef,
    Optional[String] $branch_mw_config = undef,
    Optional[Boolean] $use_memcached = undef,
    Optional[Boolean] $use_redis = undef,
) {
    host { 'mediawiki-internal-db-master.miraheze.org':
        ensure => present,
        ip => '81.4.109.166'
    }

    host { 'mediawiki-internal-db-master-db5.miraheze.org':
        ensure => present,
        ip => '185.52.1.89'
    }

    include mediawiki::favicons
    include mediawiki::cron
    if hiera('mwservices', false) {
        include mediawiki::services_cron
    }
    include mediawiki::nginx
    include mediawiki::packages
    include mediawiki::logging
    include mediawiki::extensionsetup
    include mediawiki::servicessetup
    if $use_memcached {
        include mediawiki::memcached
    }
    if $use_redis {
        class { '::redis':
             password  => hiera('passwords::redis::master'),
             maxmemory => hiera('mediawiki_redis_maxmemory', '200mb'),
         }
    }
    include mediawiki::monitoring

    include mediawiki::php

    if hiera(jobrunner) {
        include mediawiki::jobrunner
    }

    file { [
        '/srv/mediawiki',
        '/srv/mediawiki/dblist',
    ]:
        ensure => 'directory',
        owner  => 'www-data',
        group  => 'www-data',
        mode   => '0755',
    }

    include ::imagemagick::install

    git::clone { 'MediaWiki config':
        ensure    => 'latest',
        directory => '/srv/mediawiki/config',
        origin    => 'https://github.com/miraheze/mw-config.git',
        branch    => $branch_mw_config,
        owner     => 'www-data',
        group     => 'www-data',
        mode      => '0755',
        require   => File['/srv/mediawiki'],
    }

    git::clone { 'MediaWiki core':
        ensure             => 'latest',
        directory          => '/srv/mediawiki/w',
        origin             => 'https://github.com/miraheze/mediawiki.git',
        branch             => $branch,
        owner              => 'www-data',
        group              => 'www-data',
        mode               => '0755',
        timeout            => '1500',
        recurse_submodules => true,
        require            => File['/srv/mediawiki'],
    }

    git::clone { 'landing':
        ensure             => 'latest',
        directory          => '/srv/mediawiki/landing',
        origin             => 'https://github.com/miraheze/landing.git',
        branch             => 'master',
        owner              => 'www-data',
        group              => 'www-data',
        mode               => '0755',
        timeout            => '550',
        require            => File['/srv/mediawiki'],
    }

    file { '/srv/mediawiki/w/cache/managewiki':
        ensure  => 'directory',
        owner   => 'www-data',
        group   => 'www-data',
        recurse => true,
        require => Git::Clone['MediaWiki core'],
    }

    file { '/srv/mediawiki/robots.php':
        ensure  => 'present',
        source  => 'puppet:///modules/mediawiki/robots.php',
        require => File['/srv/mediawiki'],
    }

    file { '/srv/mediawiki/w/LocalSettings.php':
        ensure  => 'link',
        target  => '/srv/mediawiki/config/LocalSettings.php',
        owner   => 'www-data',
        group   => 'www-data',
        require => [ Git::Clone['MediaWiki config'], Git::Clone['MediaWiki core'] ],
    }

    $wikiadmin_password   = hiera('passwords::db::wikiadmin')
    $mediawiki_password   = hiera('passwords::db::mediawiki')
    $redis_password       = hiera('passwords::redis::master')
    $noreply_password     = hiera('passwords::mail::noreply')
    $mediawiki_upgradekey = hiera('passwords::mediawiki::upgradekey')
    $mediawiki_secretkey  = hiera('passwords::mediawiki::secretkey')
    $recaptcha_sitekey    = hiera('passwords::recaptcha::sitekey')
    $recaptcha_secretkey  = hiera('passwords::recaptcha::secretkey')
    $googlemaps_key       = hiera('passwords::mediawiki::googlemapskey')
    $matomotoken          = hiera('passwords::mediawiki::matomotoken')

    $wiki_discord_hooks_url = hiera('mediawiki::wiki_discord_hooks_url')

    class { '::nutcracker':
        redis_password => $redis_password,
    }

    file { '/srv/mediawiki/config/PrivateSettings.php':
        ensure  => 'present',
        content => template('mediawiki/PrivateSettings.php'),
        require => Git::Clone['MediaWiki config'],
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

    file { '/usr/local/bin/pushServices.sh':
        ensure => 'present',
        mode   => '0755',
        source => 'puppet:///modules/mediawiki/bin/pushServices.sh',
    }

    exec { 'ExtensionMessageFiles':
        command     => 'php /srv/mediawiki/w/maintenance/mergeMessageFileList.php --wiki loginwiki --output /srv/mediawiki/config/ExtensionMessageFiles.php',
        creates     => '/srv/mediawiki/config/ExtensionMessageFiles.php',
        cwd         => '/srv/mediawiki/config',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mediawiki/config',
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }
}
