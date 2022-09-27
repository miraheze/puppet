# README:
#  what is going on in this class is described in the upstream docs:
#  https://docs.ceph.com/en/latest/mgr/administrator/#manual-setup
#
class ceph::mgr (
    Ceph::Auth::ClientAuth $mgr_auth
) {
    $client = "mgr.${::hostname}"

    if ! defined(Ceph::Auth::Keyring[$client]) {
        fail("missing ceph::auth::keyring[${client}], check hiera 'role::ceph::keyring:mon'")
    }

    if defined(Ceph::Auth::Keyring['admin']) {
        Ceph::Auth::Keyring['admin'] -> Class['ceph::mgr']
    } else {
        notify {'ceph::mgr: Admin keyring not defined, things might not work as expected.': }
    }

    file { "/var/lib/ceph/mgr/ceph-${::hostname}":
        ensure => 'directory',
        owner  => 'ceph',
        group  => 'ceph',
        mode   => '0750',
    }

    $keyring_path = ceph::auth::get_keyring_path($client, $mgr_auth['keyring_path'])

    # If the daemon hasn't been setup yet, first verify we can connect to the ceph cluster
    exec { 'ceph-mgr-check':
        command => '/usr/bin/ceph -s',
        onlyif  => "/usr/bin/test ! -e ${keyring_path}",
        require => File["/var/lib/ceph/mgr/ceph-${::hostname}"],
    }

    if defined(Ceph::Auth::Keyring['admin']) {
        Ceph::Auth::Keyring['admin'] -> Exec['ceph-mgr-check']
    }

    service { "ceph-mgr@${::hostname}":
        ensure    => running,
        enable    => true,
        require   => Ceph::Auth::Keyring[$client],
        subscribe => File['/etc/ceph/ceph.conf'],
    }
}
