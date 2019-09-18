# == Class: glusters

class gluster {

    require_package('glusterfs-server')

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
            source => 'puppet:///ssl/ca/GlobalSign.crt',
            path   => '/etc/ssl/glusterfs.ca',
            owner  => 'root',
            group  => 'root',
        }
    }

    if !defined(File['/var/lib/glusterd/secure-access']) {
        file { '/var/lib/glusterd/secure-access':
            ensure  => present,
            content => '',
            require => Package['glusterfs-server'],
        }
    }

    service { 'glusterd':
        ensure   => running,
        enable   => true,
        provider => 'systemd',
        require  => [
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
    
    $monotoring = loadyaml("${module_path}/data/monotoring.yaml")

    $monotoring.each |$key, $value| {
        $value.each |$port| {
            monitoring::services { "GlusterFS: host ${key} on port ${port}":
                check_command => 'tcp',
                vars          => {
                    tcp_port    => $port,
                },
            }
        }
    }

    if hiera('gluster_client', false) {
        $gluster_volume_backup = hiera('gluster_volume_backup', 'glusterfs2.miraheze.org:/prodvol')
        gluster::mount { '/mnt/mediawiki-static':
          ensure    => present,
          volume    => hiera('gluster_volume', 'glusterfs1.miraheze.org:/prodvol'),
          transport => 'tcp',
          atboot    => false,
          dump      => 0,
          pass      => 0,
          options   => "backup-volfile-servers=${gluster_volume_backup}",
        }
    }
}
