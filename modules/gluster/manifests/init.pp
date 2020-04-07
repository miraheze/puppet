# == Class: glusters

class gluster {

    include gluster::apt
    
    package { 'glusterfs-server':
        ensure   => installed,
        require  => Class['gluster::apt'],
    }

    if !defined(File['glusterfs.pem']) {
        file { 'glusterfs.pem':
            ensure => 'present',
            source => 'puppet:///ssl/certificates/wildcard.miraheze.org.crt',
            path   => '/etc/ssl/glusterfs.pem',
            owner  => 'root',
            group  => 'root',
        }
    }

    if !defined(File['glusterfs.key']) {
        file { 'glusterfs.key':
            ensure => 'present',
            source => 'puppet:///ssl-keys/wildcard.miraheze.org.key',
            path   => '/etc/ssl/glusterfs.key',
            owner  => 'root',
            group  => 'root',
            mode   => '0660',
        }
    }

    if !defined(File['glusterfs.ca']) {
        file { 'glusterfs.ca':
            ensure => 'present',
            source => 'puppet:///ssl/ca/Sectigo.crt',
            path   => '/etc/ssl/glusterfs.ca',
            owner  => 'root',
            group  => 'root',
        }
    }

    if !defined(File['/var/lib/glusterd/secure-access']) {
        file { '/var/lib/glusterd/secure-access':
            ensure  => present,
            source  => 'puppet:///modules/gluster/secure-access',
            require => Package['glusterfs-server'],
        }
    }

    service { 'glusterd':
        ensure     => running,
        enable     => true,
        hasrestart => true,
        hasstatus  => true,
        require    => [
            File['/var/lib/glusterd/secure-access'],
        ],
    }

    $module_path = get_module_path($module_name)

    $firewall = loadyaml("${module_path}/data/firewall.yaml")

    $firewall.each |$key, $value| {
        $value.each |$port| {
            ufw::allow { "glusterfs ${key} ${port}":
                proto => 'tcp',
                port  => $port,
                from  => $key,
            }
        }
    }

    [24007, 49152].each |$port| {
        monitoring::services { "GlusterFS port ${port}":
            check_command => 'tcp',
            vars          => {
                tcp_port    => $port,
            },
        }
    }

    if lookup('gluster_client', false) {
        # $gluster_volume_backup = lookup('gluster_volume_backup', 'glusterfs2.miraheze.org:/prodvol')
        # backup-volfile-servers=
        if !defined(Gluster::Mount['/mnt/mediawiki-static']) {
            gluster::mount { '/mnt/mediawiki-static':
              ensure    => mounted,
              volume    => lookup('gluster_volume', 'gluster1.miraheze.org:/mvol'),
            }
        }
    }

    include prometheus::gluster_exporter
}
