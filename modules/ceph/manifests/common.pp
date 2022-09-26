# Class: ceph::common
#
# This class configures the host for the ceph-common package.
#
class ceph::common {

    group { 'ceph':
        ensure => present,
        system => true,
    }

    user { 'ceph':
        ensure     => present,
        gid        => 'ceph',
        shell      => '/usr/sbin/nologin',
        comment    => 'Ceph storage service',
        home       => '/var/lib/ceph',
        managehome => false,
        system     => true,
        require    => Group['ceph'],
    }

    # Ceph common package used for all services and clients
    ensure_packages([
      'ceph-common',
      # fio is used for performance tests and debugging
      'fio',
    ])
    User['ceph'] -> Package['ceph-common']


    file { '/var/lib/ceph':
        ensure => directory,
        mode   => '0750',
        owner  => 'ceph',
        group  => 'ceph',
    }

    file { '/var/lib/ceph/bootstrap-osd':
        ensure => directory,
        mode   => '0750',
        owner  => 'ceph',
        group  => 'ceph',
    }

    file { '/var/log/ceph':
        ensure => directory,
        mode   => '0755',
        owner  => 'ceph',
        group  => 'ceph',
    }

    file { '/var/run/ceph':
        ensure => directory,
        mode   => '0750',
        owner  => 'ceph',
        group  => 'ceph',
    }
}
