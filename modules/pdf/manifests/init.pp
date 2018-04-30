# == Class: pdf
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

class pdf {
    include nginx

    file { '/srv/ocg':
        ensure => directory,
        owner  => 'root',
        group  => 'root',
    }

    require_package('python-pip')

    package {'mwlib':
        ensure   => present,
        provider => 'pip',
        require  => Package['python-pip']
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

    file { '/srv/ocg/cache':
        ensure => directory,
        owner  => 'ocg',
        group  => 'ocg',
    }

    include ssl::wildcard

    nginx::site { 'pdf':
        ensure  => present,
        source  => 'puppet:///modules/pdf/nginx/pdf',
        monitor => false,
    }

    file { '/etc/systemd/system/pdf.service':
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        source  => 'puppet:///modules/pdf/pdf.service',
        require => User['ocg'],
        notify  => Service['pdf'],
    }

    service { 'pdf':
        ensure     => running,
        provider   => 'systemd',
        hasstatus  => false,
        hasrestart => false,
        require    => [
            File['/etc/systemd/system/pdf.service'],
            Package['mwlib'],
        ],
    }

    file { '/etc/logrotate.d/ocg':
        ensure => absent,
        source => 'puppet:///modules/ocg/logrotate',
        mode   => '0444',
        owner  => 'root',
        group  => 'root',
    }

    # run logrotate hourly, instead of daily, to ensure that log size
    # limits are enforced more-or-less accurately
    file { '/etc/cron.hourly/logrotate.ocg':
        ensure => absent,
        target => '/etc/cron.daily/logrotate',
    }

    include pdf::ganglia

    include pdf::nagios
}
