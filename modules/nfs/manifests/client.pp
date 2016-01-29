# NFS Client
class nfs::client {
    package { 'nfs-common':
        ensure => present,
    }
}
