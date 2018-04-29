# == Class: ocg
#
# Node service for the MediaWiki Collection extension providing article
# rendering.
#
# Collections, or books, or individual articles are submitted
# to the service as jobs which are stored in redis. Any node may accept
# a job on behalf of the cluster (providing all nodes share a redis
# instance.) Similarly, any node is then able to pick up the job when it
# is free to work.
#

class ocg (
    $host_name = $::fqdn,
    $decommission = hiera('ocg::decommission', false),
    $service_port = 8000,
    $redis_host = 'localhost',
    $redis_port = 6379,
    $redis_password = hiera('passwords::redis::master'),
    $temp_dir = '/srv/ocg/tmp',
    $output_dir = '/srv/ocg/output',
    $postmortem_dir = '/srv/ocg/postmortem',
    $log_dir = '/srv/ocg/log'
) {
    include nginx

    include nodejs

    file { '/srv/ocg':
        ensure => directory,
        owner  => 'root',
        group  => 'root',
    }

    git::clone { 'OCG':
        ensure             => 'latest',
        directory          => '/srv/ocg/ocg',
        origin             => 'https://github.com/miraheze/mediawiki-services-ocg-collection.git',
        branch             => 'master',
        owner              => 'root',
        group              => 'root',
        mode               => '0755',
        timeout            => '550',
        recurse_submodules => true,
        require            => File['/srv/ocg'],
    }

    group { 'ocg':
        ensure => present,
    }

    user { 'ocg':
        ensure     => present,
        gid        => 'ocg',
        shell      => '/bin/false',
        home       => '/srv/ocg',
        managehome => false,
        system     => true,
    }

    include ssl::wildcard

    nginx::site { 'ocg':
        ensure  => present,
        source  => 'puppet:///modules/ocg/nginx/ocg',
        monitor => false,
    }

    $nodebin = '/usr/bin/nodejs-ocg'
    apparmor::hardlink { $nodebin:
        target => '/usr/bin/nodejs',
    }

    $imagemagick_dir = '/etc/ImageMagick-6'

    include ::imagemagick::install

    package {
        [
            'texlive-xetex',
            'texlive-latex-recommended',
            'texlive-latex-extra',
            'texlive-generic-extra',
            'texlive-fonts-recommended',
            'texlive-fonts-extra',
            'texlive-lang-all',
            'fonts-hosny-amiri',
            'fonts-farsiweb',
            'fonts-nafees',
            'fonts-arphic-uming',
            'fonts-arphic-ukai',
            'fonts-droid-fallback',
            'fonts-baekmuk',
            'latex-xcolor',
            'lmodern',
            'poppler-utils',
            'libjpeg-progs',
            'librsvg2-bin',
            'djvulibre-bin',
            'unzip',
            'zip',
            'g++',
            'gcc',
        ]:
        ensure => present,
        before => Service['ocg']
    }

    if os_version('debian >= jessie') {
        require_package('fonts-deva', 'fonts-mlym', 'fonts-beng', 'fonts-gujr', 'fonts-knda', 'fonts-orya', 'fonts-guru', 'fonts-taml', 'fonts-telu', 'fonts-gujr-extra')
    }

    $ocg_log_grp = 'adm'

    file { '/etc/systemd/system/ocg.service':
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        source  => 'puppet:///modules/ocg/ocg.service',
        require => User['ocg'],
        notify  => Service['ocg'],
    }

    service { 'ocg':
        ensure     => running,
        provider   => 'systemd',
        hasstatus  => false,
        hasrestart => false,
        require    => [
            File['/etc/systemd/system/ocg.service'],
            Git::Clone['OCG'],
        ],
    }

    file { '/etc/ocg':
        ensure => directory,
    }

    file { '/etc/ocg/mw-ocg-service.js':
        ensure  => present,
        owner   => 'ocg',
        group   => 'ocg',
        mode    => '0440',
        content => template('ocg/mw-ocg-service.js.erb'),
        notify  => Service['ocg'],
    }

    # Change this if you change the value of $nodebin
    include apparmor
    $nodebin_dots = regsubst($nodebin, '/', '.', 'G')

    file { "/etc/apparmor.d/${nodebin_dots}":
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0440',
        content => template('ocg/usr.bin.nodejs.apparmor.erb'),
        notify  => Service['apparmor', 'ocg'],
    }


    if $temp_dir == '/srv/ocg/tmp' {
        file { $temp_dir:
            ensure => directory,
            owner  => 'ocg',
            group  => 'ocg',
        }
    } else {
        File[$temp_dir] -> Class['ocg']
    }

    file { $output_dir:
        ensure => directory,
        owner  => 'ocg',
        group  => 'ocg',
    }

    file { $postmortem_dir:
        ensure => directory,
        owner  => 'ocg',
        group  => 'ocg',
    }

    file { $log_dir:
        ensure => directory,
        # matches /var/log
        mode   => '0775',
        owner  => 'root',
        group  => $ocg_log_grp,
    }

    # help unfamiliar sysadmins find the logs
    file { '/var/log/ocg':
        ensure => link,
        target => $log_dir,
    }

    file { '/etc/logrotate.d/ocg':
        ensure => present,
        source => 'puppet:///modules/ocg/logrotate',
        mode   => '0444',
        owner  => 'root',
        group  => 'root',
    }

    # run logrotate hourly, instead of daily, to ensure that log size
    # limits are enforced more-or-less accurately
    file { '/etc/cron.hourly/logrotate.ocg':
        ensure => link,
        target => '/etc/cron.daily/logrotate',
    }

    include ocg::ganglia

    include ocg::nagios
}
