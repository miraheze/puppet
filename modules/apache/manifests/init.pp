# apache
#
# Example
#
# apache::site { 'url':
#     ensure => present,
#     source => 'puppet:///modules/url/config.conf',
# }
#
class apache {
    include apache::mpm
    $available_dirs = '/etc/apache2/sites-available'
    $enabled_dirs   = '/etc/apache2/sites-enabled'

    package { 'apache2':
        ensure => present,
    }

    service { 'apache2':
        ensure     => running,
        enable     => true,
        provider   => 'debian',
        hasrestart => true,
        restart    => '/usr/sbin/service apache2 reload',
        require    => Package['apache2'],
    }

    exec { 'apache2_test_config_and_restart':
        command     => '/usr/sbin/apache2ctl configtest',
        notify      => Exec['apache2_hard_restart'],
        before      => Service['apache2'],
        refreshonly => true,
    }

    exec { 'apache2_hard_restart':
        command     => '/usr/sbin/service apache2 restart',
        refreshonly => true,
        before      => Service['apache2'],
    }

    file { $available_dirs:
        ensure  => directory,
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
        require => Package['apache2'],
    }

    file { $enabled_dirs:
        ensure  => directory,
        owner   => 'root',
        group   => 'root',
        mode    => '0755',
        recurse => true,
        purge   => true,
        notify  => Service['apache2'],
        require => Package['apache2'],
    }

    apache::site { 'dummy':
        source   => 'puppet:///modules/apache/dummy.conf',
        priority => 0,
    }
}
