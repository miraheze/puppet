# class: mediawiki
class mediawiki(
    $branch = undef,
    $branch_mw_config = undef,
    $php7_2 = hiera('mediawiki::use_php_7_2', false)
) {
    include mediawiki::favicons
    include mediawiki::cron
    include mediawiki::nginx
    include mediawiki::packages
    include mediawiki::logging
    include mediawiki::extensionsetup
    include mediawiki::memcached
    include mediawiki::monitoring

    if $php7_2 {
        include mediawiki::php7_2
    } else {
        include mediawiki::php7
    }

    if hiera(jobrunner) {
        include mediawiki::jobrunner
    }

    if hiera(mwdumps) {
        include mediawiki::dumps
    }

    file { [ 
        '/srv/mediawiki', 
        '/srv/mediawiki/dblist', 
        '/srv/mediawiki/cdb-config', 
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
        timeout            => '550',
        recurse_submodules => true,
        require            => File['/srv/mediawiki'],
    }

    file { '/srv/mediawiki/robots.txt':
        ensure  => 'present',
        source  => 'puppet:///modules/mediawiki/robots.txt',
        require => File['/srv/mediawiki'],
    }

    file { '/srv/mediawiki/w/LocalSettings.php':
        ensure  => 'link',
        target  => '/srv/mediawiki/config/LocalSettings.php',
        owner   => 'www-data',
        group   => 'www-data',
        require => [ Git::Clone['MediaWiki config'], Git::Clone['MediaWiki core'] ],
    }

    if $php7_2 {
        file { '/var/log/php7.2-fpm.log':
            ensure  => 'present',
            owner   => 'www-data',
            group   => 'www-data',
            mode    => '0755',
        }
    } else {
        file { '/var/log/php7.0-fpm.log':
            ensure  => 'present',
            owner   => 'www-data',
            group   => 'www-data',
            mode    => '0755',
        }
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

    file { '/srv/mediawiki/config/PrivateSettings.php':
        ensure  => 'present',
        content => template('mediawiki/PrivateSettings.php'),
        require => Git::Clone['MediaWiki config'],
    }

    file { '/usr/local/bin/foreachwikiindblist':
        ensure => 'present',
        mode   => '0755',
        source => 'puppet:///modules/mediawiki/bin/foreachwikiindblist',
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
