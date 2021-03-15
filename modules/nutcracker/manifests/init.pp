# == Class: nutcracker
#
# nutcracker (AKA twemproxy) is a fast and lightweight proxy
# for memcached and redis. It was primarily built to reduce the
# connection count on the backend caching servers.
#
# === Parameters
#
# [*verbosity*]
#   Set logging level (default: 4, min: 0, max: 11).
#
# === Examples
#
#  class { '::nutcracker': }
#
class nutcracker(
    VMlib::Ensure $ensure = present,
    Integer $verbosity = 4,
) {

    require_package('nutcracker')

    file { '/etc/nutcracker/nutcracker.yml':
        ensure  => $ensure,
        content => template('nutcracker/nutcracker.yml.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        notify  => Service['nutcracker'],
        require => Package['nutcracker'],
    }

    File['/etc/nutcracker/nutcracker.yml'] {
      validate_cmd => '/usr/sbin/nutcracker --test-conf --conf-file %',
    }

    file { '/etc/default/nutcracker':
        ensure  => $ensure,
        content => template('nutcracker/default.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        notify  => Service['nutcracker'],
    }

    file { '/etc/init/nutcracker.override':
        ensure  => $ensure,
        content => "limit nofile 64000 64000\n",
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        notify  => Service['nutcracker'],
    }

    file { '/run/nutcracker':
        ensure  => directory,
        owner   => 'nutcracker',
        group   => 'nutcracker',
        require => Package['nutcracker'],
        notify  => Service['nutcracker'],
    }

    service { 'nutcracker':
        ensure  => ensure_service($ensure),
        enable  => true,
        require => File['/run/nutcracker'],
    }
}
