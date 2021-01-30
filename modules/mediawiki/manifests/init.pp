# class: mediawiki
class mediawiki(
    Optional[String] $branch = undef,
    Optional[String] $branch_mw_config = undef,
    Optional[Boolean] $use_memcached = undef,
) {
    include mediawiki::favicons
    include mediawiki::cron
    if lookup('mwservices', {'default_value' => false}) {
        include mediawiki::services_cron
    }
    include mediawiki::nginx
    include mediawiki::packages
    include mediawiki::logging
    include mediawiki::php
    include mediawiki::extensionsetup
    include mediawiki::servicessetup


    include mediawiki::monitoring

    if lookup(jobrunner) {
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
        depth              => '5',
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
        require => [ Git::Clone['MediaWiki config'], Git::Clone['MediaWiki core'] ],
    }

    $wikiadmin_password    = lookup('passwords::db::wikiadmin')
    $mediawiki_password    = lookup('passwords::db::mediawiki')
    $redis_password        = lookup('passwords::redis::master')
    $noreply_password      = lookup('passwords::mail::noreply')
    $mediawiki_upgradekey  = lookup('passwords::mediawiki::upgradekey')
    $mediawiki_secretkey   = lookup('passwords::mediawiki::secretkey')
    $recaptcha_sitekey     = lookup('passwords::recaptcha::sitekey')
    $recaptcha_secretkey   = lookup('passwords::recaptcha::secretkey')
    $matomotoken           = lookup('passwords::mediawiki::matomotoken')
    $yandextranslation_key = lookup('passwords::mediawiki::yandextranslationkey')
    $ldap_password         = lookup('passwords::mediawiki::ldap_password')

    $global_discord_webhook_url = lookup('mediawiki::global_discord_webhook_url')

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
        command     => 'nice -n 15 php /srv/mediawiki/w/maintenance/mergeMessageFileList.php --wiki loginwiki --output /srv/mediawiki/config/ExtensionMessageFiles.php',
        creates     => '/srv/mediawiki/config/ExtensionMessageFiles.php',
        cwd         => '/srv/mediawiki/config',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mediawiki/config',
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }
}
