# class: mediawiki
class mediawiki(
    Optional[String] $branch = undef,
    Optional[String] $branch_mw_config = undef,
    Optional[Boolean] $use_memcached = undef,
) {
    # Configure cgroups used by MediaWiki
    class { '::mediawiki::cgroup': }

    include mediawiki::favicons
    include mediawiki::nginx
    include mediawiki::packages
    include mediawiki::logging
    include mediawiki::php
    include mediawiki::monitoring
    include mediawiki::firejail
    include mediawiki::deploy
    include ::nodejs

    if lookup(jobrunner) {
        include mediawiki::jobqueue::runner
    }

    if lookup(jobchron) {
        include mediawiki::jobqueue::chron
    }

    if lookup(mediawiki::use_shellbox) {
        include mediawiki::shellbox
    }

    file { '/etc/mathoid':
        ensure  => directory,
    }

    file { '/etc/mathoid/config.yaml':
        ensure  => present,
        source  => 'puppet:///modules/mediawiki/config.yaml',
        require => File['/etc/mathoid'],
    }

    git::clone { 'mathoid':
        ensure             => 'latest',
        directory          => '/srv/mathoid',
        origin             => 'https://github.com/miraheze/mathoid-deploy.git',
        branch             => 'master',
        owner              => 'www-data',
        group              => 'www-data',
        mode               => '0755',
        recurse_submodules => true,
        require            => Package['librsvg2-dev'],
    }

    git::clone { '3d2png':
        ensure             => 'latest',
        directory          => '/srv/3d2png',
        origin             => 'https://github.com/miraheze/3d2png-deploy.git',
        branch             => 'master',
        owner              => 'www-data',
        group              => 'www-data',
        mode               => '0755',
        recurse_submodules => true,
        require            => Package['libjpeg-dev'],
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

    $wikiadmin_password         = lookup('passwords::db::wikiadmin')
    $mediawiki_password         = lookup('passwords::db::mediawiki')
    $redis_password             = lookup('passwords::redis::master')
    $noreply_password           = lookup('passwords::mail::noreply')
    $mediawiki_upgradekey       = lookup('passwords::mediawiki::upgradekey')
    $mediawiki_secretkey        = lookup('passwords::mediawiki::secretkey')
    $recaptcha_secretkey        = lookup('passwords::recaptcha::secretkey')
    $shellbox_secretkey         = lookup('passwords::shellbox::secretkey')
    $matomotoken                = lookup('passwords::mediawiki::matomotoken')
    $ldap_password              = lookup('passwords::mediawiki::ldap_password')
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

    cron { 'vmtouch':
        ensure  => absent,
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
