# Class: role::ceph::osd
#
# This role configures Ceph object storage hosts with the osd daemon
class role::ceph::osd(
    Hash[String[1],Hash]       $mon_hosts                       = lookup('role::ceph::mon::hosts'),
    Hash[String[1],Hash]       $osd_hosts                       = lookup('role::ceph::osd::hosts'),
    Hash[String,Hash]          $mds_hosts                       = lookup('role::ceph::mds::hosts'),
    String[1]                  $fsid                            = lookup('role::ceph::fsid'),
    Ceph::Auth::Conf           $keyring_mon                     = lookup('role::ceph::keyring:mon')
) {

    # We don't want to type this so we don't have it in the constructor.
    $keyring_mon_private = lookup('role::ceph::keyring:mon_private')
    $ceph_auth_conf = deep_merge($keyring_mon, $keyring_mon_private)

    class { 'ceph::auth::deploy':
        configuration  => $ceph_auth_conf,
        selected_creds => true,
    }

    if ! defined(Ceph::Auth::Keyring['admin']) {
        notify{'profile::ceph::osd: Admin keyring not defined, things might not work as expected.': }
    }
    if ! defined(Ceph::Auth::Keyring['bootstrap-osd']) {
        notify{'profile::ceph::osd: bootstrap-osd keyring not defined, things might not work as expected.': }
    }

    ensure_packages(['ceph-osd'])

    $firewall_rules_str = join(
        query_facts('Class[Role::Mediawiki] or Class[Role::Ceph::Mon] or Class[Role::Ceph::Osd] or Class[Role::Icinga2] or Class[Role::Prometheus]', ['ipaddress', 'ipaddress6'])
        .map |$key, $value| {
            "${value['ipaddress']} ${value['ipaddress6']}"
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )

    ferm::service { 'ceph_osd_range':
        proto  => 'tcp',
        port   => '6800:7100',
        srange => "(${firewall_rules_str})",
        before => Class['ceph::common'],
    }

    class { 'ceph::common': }

    class { 'ceph::config':
        enable_v2_messenger => true,
        fsid                => $fsid,
        mon_hosts           => $mon_hosts,
        osd_hosts           => $osd_hosts,
        mds_hosts           => $mds_hosts,
    }
}
