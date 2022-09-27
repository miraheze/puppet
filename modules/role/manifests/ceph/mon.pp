# Class: role::ceph::mon
#
# This role configures Ceph monitor hosts with the mon and mgr daemons, also installs mds.
class role::ceph::mon(
    Hash[String,Hash]          $mon_hosts           = lookup('role::ceph::mon::hosts'),
    Hash[String,Hash]          $osd_hosts           = lookup('role::ceph::osd::hosts'),
    Hash[String,Hash]          $mds_hosts           = lookup('role::ceph::mds::hosts'),
    String                     $fsid                = lookup('role::ceph::fsid'),
    Ceph::Auth::Conf           $ceph_auth_conf      = lookup('role::ceph::keyring:mon')
) {

    class { 'ceph::auth::load_all':
        configuration => $ceph_auth_conf,
    }

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

    ferm::service { 'ceph_mgr_and_mds':
        proto  => 'tcp',
        port   => '6800:7300',
        srange => "(${firewall_rules_str})",
        before => Class['ceph::common'],
    }

    ferm::service { 'ceph_mon_peers_v1':
        proto  => 'tcp',
        port   => 6789,
        srange => "(${firewall_rules_str})",
        before => Class['ceph::common'],
    }

    ferm::service { 'ceph_mon_peers_v2':
        proto  => 'tcp',
        port   => 3300,
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

    class { 'ceph::mon':
        fsid       => $fsid,
        admin_auth => $ceph_auth_conf['admin'],
        mon_auth   => $ceph_auth_conf["mon.${::hostname}"],
    }

    Class['ceph::mon'] -> Class['ceph::mgr']

    class { 'ceph::mgr':
        mgr_auth => $ceph_auth_conf["mgr.${::hostname}"],
    }
}
