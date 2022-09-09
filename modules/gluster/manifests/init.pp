# == Class: glusters

class gluster {
    include gluster::apt

    ssl::wildcard { 'gluster wildcard': }

    package { 'glusterfs-server':
        ensure  => installed,
        require => Class['gluster::apt'],
    }

    if !defined(File['glusterfs.pem']) {
        file { 'glusterfs.pem':
            ensure => 'present',
            source => 'puppet:///ssl/certificates/wildcard.miraheze.org-2020-2.crt',
            path   => '/usr/lib/ssl/glusterfs.pem',
            owner  => 'root',
            group  => 'root',
        }
    }

    if !defined(File['glusterfs.key']) {
        file { 'glusterfs.key':
            ensure => 'present',
            source => 'puppet:///ssl-keys/wildcard.miraheze.org-2020-2.key',
            path   => '/usr/lib/ssl/glusterfs.key',
            owner  => 'root',
            group  => 'root',
            mode   => '0660',
        }
    }

    if !defined(File['glusterfs.ca']) {
        file { 'glusterfs.ca':
            ensure => 'present',
            source => 'puppet:///ssl/ca/Sectigo.crt',
            path   => '/usr/lib/ssl/glusterfs.ca',
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

    file { '/etc/glusterfs/glusterd.vol':
        ensure  => present,
        content => template('gluster/glusterd.vol.erb'),
        require => Package['glusterfs-server'],
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

    monitoring::nrpe { 'glusterd':
        command => '/usr/lib/nagios/plugins/check_procs -a /usr/sbin/glusterd -c 1:'
    }

    monitoring::nrpe { 'glusterd Volume':
        command => '/usr/lib/nagios/plugins/check_procs -a /usr/sbin/glusterfsd -c 1:'
    }

    if lookup('gluster_client', {'default_value' => false}) {
        if !defined(Gluster::Mount['/mnt/mediawiki-static']) {
            gluster::mount { '/mnt/mediawiki-static':
              ensure => mounted,
              volume => lookup('gluster_volume', {'default_value' => 'gluster101.miraheze.org:/static'}),
            }
        }

        monitoring::nrpe { 'Gluster Disk Space':
            command => '/usr/lib/nagios/plugins/check_disk -w 10% -c 5% -p /mnt/mediawiki-static'
        }
    }

    $syslog_daemon = lookup('base::syslog::syslog_daemon', {'default_value' => 'syslog_ng'})
    if $syslog_daemon == 'syslog_ng' {
        gluster::logging { 'glusterd':
            file_source_options => [
                '/var/log/glusterfs/glusterd.log',
                { 'flags' => 'no-parse' }
            ],
            program_name        => 'glusterd',
        }
    } else {
        rsyslog::input::file { 'glusterd':
            path              => '/var/log/glusterfs/glusterd.log',
            syslog_tag_prefix => '',
            use_udp           => true,
        }
    }

    logrotate::conf { 'glusterfs-common':
        ensure => present,
        source => 'puppet:///modules/gluster/glusterfs-common.logrotate.conf',
    }

    include prometheus::exporter::gluster
}
