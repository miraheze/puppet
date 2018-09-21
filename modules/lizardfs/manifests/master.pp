# == Class: lizardfs::master

class lizardfs::master(
    String $master_server = hiera('lizardfs_master_server', '185.52.3.121'),
) {

    require_package('lizardfs-master')

    file { '/var/lib/lizardfs/metadata.mfs':
        ensure  => 'present',
        replace => 'no',
        content => 'MFSM NEW',
        require => Package['lizardfs-master'],
    }

    file { '/etc/lizardfs/mfsmaster.cfg':
        ensure  => present,
        content => template('lizardfs/mfsmaster.cfg.erb'),
        require => Package['lizardfs-master'],
        notify  => Service['lizardfs-master'],
    }

    $module_path = get_module_path($module_name)
    $storage_ip = loadyaml("${module_path}/data/config.yaml")

    file { '/etc/lizardfs/mfsexports.cfg':
        ensure  => present,
        content => template('lizardfs/mfsexports.cfg.erb'),
        require => Package['lizardfs-master'],
        notify  => Service['lizardfs-master'],
    }
    
    service { 'lizardfs-master':
        ensure => running,
    }

    $firewall = loadyaml("${module_path}/data/storage_firewall.yaml")

    $firewall.each |$firewall_key, $firewall_value| {
        # storage access master
        ufw::allow { "lizardfs ${firewall_key} 9419":
            proto => 'tcp',
            port  => 9419,
            from  => $firewall_value,
        }

        # storage access master
        ufw::allow { "lizardfs ${firewall_key} 9420":
            proto => 'tcp',
            port  => 9420,
            from  => $firewall_value,
        }

        # clients access master
        ufw::allow { "lizardfs ${firewall_key} 9421":
            proto => 'tcp',
            port  => 9421,
            from  => $firewall_value,
        }
    }

    icinga2::custom::services { 'Lizardfs Master Port 1':
        check_command => 'tcp',
        vars          => {
            tcp_port    => '9419',
        },
    }

    icinga2::custom::services { 'Lizardfs Master Port 2':
        check_command => 'tcp',
        vars          => {
            tcp_port    => '9420',
        },
    }

    icinga2::custom::services { 'Lizardfs Master Port 3':
        check_command => 'tcp',
        vars          => {
            tcp_port    => '9421',
        },
    }
}
