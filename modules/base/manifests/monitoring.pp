# base::monitoring
class base::monitoring {
    $nagios_packages = [ 'nagios-plugins', 'nagios-nrpe-server', ]
    package { $nagios_packages:
        ensure => present,
    }

    file { '/etc/nagios/nrpe.cfg':
        ensure  => present,
        content => template('base/icinga/nrpe.cfg.erb'),
        require => Package['nagios-nrpe-server'],
        notify  => Service['nagios-nrpe-server'],
    }

    $puppetmaster_version = hiera('puppetmaster_version', 4)
    file { '/usr/lib/nagios/plugins/check_puppet_run':
        ensure => present,
        source => 'puppet:///modules/base/icinga/check_puppet_run',
        mode   => '0555',
    }

    service { 'nagios-nrpe-server':
        ensure     => 'running',
        hasrestart => true,
    }

    ufw::allow { 'prometheus access all hosts':
        proto => 'tcp',
        port  => 9100,
        from  => '81.4.127.174',
    }

    ufw::allow { 'prometheus access php-fpm for all hosts':
        proto => 'tcp',
        port  => 9253,
        from  => '81.4.127.174',
    }

    if os_version('debian == stretch') {
        apt::pin { 'debian_stretch_backports_prometheus_node_exporter':
            priority   => 740,
            originator => 'Debian',
            release    => 'stretch-backports',
            packages   => 'prometheus-node-exporter',
        }
    }

    require_package('prometheus-node-exporter')

    service { 'prometheus-node-exporter':
        ensure    => running,
        enable    => true,
        require   => Package['prometheus-node-exporter'],
    }

    # SUDO FOR NRPE
    sudo::user { 'nrpe_sudo':
        user       => 'nagios',
        privileges => [ 'ALL = NOPASSWD: /usr/lib/nagios/plugins/check_puppet_run', ],
    }

    monitoring::hosts { $::hostname: }

    monitoring::services { 'Disk Space':
        check_command => 'nrpe',
        vars          => {
            nrpe_command => 'check_disk',
        },
    }

    monitoring::services { 'Current Load':
        check_command => 'nrpe',
        vars          => {
            nrpe_command => 'check_load',
        },
    }

    monitoring::services { 'Puppet':
        check_command => 'nrpe',
        vars          => {
            nrpe_command => 'check_puppet_run',
        },
    }

    monitoring::services { 'SSH':
        check_command => 'ssh',
    }
}
