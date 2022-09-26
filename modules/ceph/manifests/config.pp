# Class: ceph::config
#
# This class manages the Ceph common packages and configuration
#
# Parameters
#    - $mon_hosts
#        Hash that defines the ceph monitor host's public and private IPv4 information
#    - $fsid
#        Ceph filesystem ID
#    - $enable_v2_messenger
#        Enables Ceph messenger version 2 ( >= Nautilus release)
#    - $osd_hosts [Optional]
#        Hash that defines the ceph object storage hosts, and public and private IPv4 information
#    - $mds_hosts [Optional]
#        Hash that defines the ceph mds hosts, and public and private IPv4 information
#
class ceph::config (
    Boolean                     $enable_v2_messenger,
    Hash[String,Hash]           $mon_hosts,
    String                      $fsid,
    Optional[Hash[String,Hash]] $osd_hosts = {},
    Optional[Hash[String,Hash]] $mds_hosts = {},
) {

    Class['ceph::common'] -> Class['ceph::config']

    # Ceph configuration file used for all services and clients
    file { '/etc/ceph/ceph.conf':
        ensure  => present,
        mode    => '0444',
        owner   => 'root',
        group   => 'root',
        content => epp('ceph/ceph.conf.epp', {
            enable_v2_messenger          =>$enable_v2_messenger,
            mon_hosts                    =>$mon_hosts,
            fsid                         =>$fsid,
            osd_hosts                    =>$osd_hosts,
            mds_hosts                    =>$mds_hosts,
        }),
        require => Package['ceph-common'],
    }
}
