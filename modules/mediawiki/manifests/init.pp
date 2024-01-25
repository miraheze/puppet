# === Class mediawiki
class mediawiki {
    include mediawiki::cgroup
    include mediawiki::favicons
    include mediawiki::nginx
    include mediawiki::packages
    include mediawiki::logging
    include mediawiki::php
    include mediawiki::monitoring

    if lookup(mediawiki::use_staging) {
        include mediawiki::deploy
    } else {
        include mediawiki::rsync
    }

    include mediawiki::multiversion

    if lookup(mediawiki::use_shellbox) {
        include mediawiki::shellbox
    }

    if !lookup('jobrunner::intensive', {'default_value' => false}) {
        cron { 'clean-tmp-files':
            ensure  => absent,
            command => 'find /tmp/ -user www-data -amin +30 \( -iname "magick-*" -or -iname "transform_*" -or -iname "lci_*" -or -iname "svg_* -or -iname "localcopy_*" \) -delete',
            user    => 'www-data',
            special => 'hourly',
        }
    }

    if lookup('jobrunner::intensive', {'default_value' => false}) {
        if ($facts['os']['distro']['codename'] == 'bookworm') {
            stdlib::ensure_packages(['python3-internetarchive'])
        } else {
            stdlib::ensure_packages(
                'internetarchive',
                {
                    ensure   => '3.3.0',
                    provider => 'pip3',
                    before   => File['/usr/local/bin/iaupload'],
                    require  => Package['python3-pip'],
                },
            )
        }

        file { '/usr/local/bin/iaupload':
            ensure => present,
            mode   => '0755',
            source => 'puppet:///modules/mediawiki/bin/iaupload.py',
        }
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
        '/srv/mediawiki/config',
        '/srv/mediawiki/cache',
        '/srv/mediawiki/stopforumspam',
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

    file { '/srv/mediawiki/favicon.php':
        ensure  => 'present',
        source  => 'puppet:///modules/mediawiki/favicon.php',
        require => File['/srv/mediawiki'],
    }

    file { '/srv/mediawiki/touch.php':
        ensure  => 'present',
        source  => 'puppet:///modules/mediawiki/touch.php',
        require => File['/srv/mediawiki'],
    }

    file { '/srv/mediawiki/healthcheck.php':
        ensure  => 'present',
        source  => 'puppet:///modules/mediawiki/healthcheck.php',
        require => File['/srv/mediawiki'],
    }

    file { '/srv/mediawiki/sitemap.php':
        ensure  => 'present',
        source  => 'puppet:///modules/mediawiki/sitemap.php',
        require => File['/srv/mediawiki'],
    }

    $wikiadmin_password         = lookup('passwords::db::wikiadmin')
    $mediawiki_password         = lookup('passwords::db::mediawiki')
    $redis_password             = lookup('passwords::redis::master')
    $mediawiki_upgradekey       = lookup('passwords::mediawiki::upgradekey')
    $mediawiki_secretkey        = lookup('passwords::mediawiki::secretkey')
    $hcaptcha_secretkey         = lookup('passwords::hcaptcha::secretkey')
    $shellbox_secretkey         = lookup('passwords::shellbox::secretkey')
    $matomotoken                = lookup('passwords::mediawiki::matomotoken')
    $ldap_password              = lookup('passwords::mediawiki::ldap_password')
    $discord_experimental_webhook = lookup('mediawiki::discord_experimental_webhook')
    $global_discord_webhook_url = lookup('mediawiki::global_discord_webhook_url')
    $swift_password             = lookup('mediawiki::swift_password')
    $swift_temp_url_key         = lookup('mediawiki::swift_temp_url_key')
    $reports_write_key          = lookup('reports::reports_write_key')
    $google_translate_apikey_meta = lookup('passwords::mediawiki::google_translate_apikey_meta')

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

    file { '/usr/local/bin/getMWVersion':
        ensure => 'present',
        mode   => '0755',
        source => 'puppet:///modules/mediawiki/bin/getMWVersion.php',
    }

    file { '/usr/local/bin/getMWVersions':
        ensure => 'present',
        mode   => '0755',
        source => 'puppet:///modules/mediawiki/bin/getMWVersions.php',
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

    file { '/srv/mediawiki/stopforumspam/listed_ip_90_ipv46_all.txt':
        ensure    => present,
        mode      => '0755',
        source    => 'puppet:///private/mediawiki/listed_ip_90_ipv46_all.txt',
        show_diff => false,
        require   => File['/srv/mediawiki/stopforumspam'],
    }

    sudo::user { 'www-data_sudo_itself':
        user       => 'www-data',
        privileges => [
            'ALL = (www-data) NOPASSWD: ALL',
        ],
    }

    file { '/etc/swift-env.sh':
        ensure  => 'present',
        content => template('mediawiki/swift-env.sh.erb'),
        mode    => '0755',
    }

    file { '/tmp/magick-tmp':
        ensure => directory,
        owner  => 'www-data',
        group  => 'root',
        mode   => '0755',
    }

    tidy { [ '/tmp', '/tmp/magick-tmp' ]:
        matches => [ '*.png', '*.jpg', '*.gif', 'EasyTimeline.*', 'gs_*', 'localcopy_*', 'magick-*', 'transform_*', 'vips-*.v', 'php*', 'shellbox-*' ],
        age     => '2h',
        type    => 'atime',
        backup  => false,
        recurse => 1,
    }
}
