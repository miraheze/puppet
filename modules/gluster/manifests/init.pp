# == Class: glusters

class gluster {

    require_package('glusterfs-server')

    service { 'glusterd':
        ensure   => running,
        enable   => true,
        provider => 'systemd',
        require  => [
            Package['glusterfs-server'],
        ],
    }

    $module_path = get_module_path($module_name)

    $firewall = loadyaml("${module_path}/data/firewall.yaml")

    $firewall.each |$key, $value| {
        ufw::allow { "glusterfs ${key} ${value}":
            proto => 'tcp',
            port  => $value,
            from  => $key,
        }

        monitoring::services { "GlusterFS ip ${key} on port ${value}":
            check_command => 'tcp',
            vars          => {
                tcp_port    => $value,
            },
        }
    }
}
