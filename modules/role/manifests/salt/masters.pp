class role::salt::masters {

    $salt_state_roots    = '/srv/salt'
    $salt_file_roots     = '/srv/salt'
    $salt_pillar_roots   = '/srv/pillars'
    $salt_module_roots   = '/srv/salt/_modules'
    $salt_returner_roots = '/srv/salt/_returners'

    class { 'salt::master':
        salt_interface      => '::',
        salt_runner_dirs    => '/srv/runners',
        salt_file_roots     => $salt_file_roots,
        salt_pillar_roots   => $salt_pillar_roots,
        salt_worker_threads => '5',
        salt_state_roots    => $salt_state_roots,
        salt_module_roots   => $salt_module_roots,
        salt_returner_roots => $salt_returner_roots,
    }

    include ::salt::master::key

    # DO NOT UNDER ANY CIRCUMSTANCES OPEN THIS UP
    $hostips = query_nodes("domain='$domain' and Class[Role::Salt::Minions]", 'ipaddress')
    $hostips.each |$key| {
        ufw::allow { 'salt master port 4505 ipv4':
            proto   => 'tcp',
            port    => 4505,
            from    => $key,
        }

        ufw::allow { 'salt master port 4506 ipv4':
            proto   => 'tcp',
            port    => 4506,
            from    => $key,
        }
     }

    # DO NOT UNDER ANY CIRCUMSTANCES OPEN THIS UP
    $hostips6 = query_nodes("domain='$domain' and Class[Role::Salt::Minions]", 'ipaddress6')
    $hostips6.each |$key| {
        ufw::allow { 'salt master port 4505 ipv6':
            proto   => 'tcp',
            port    => 4505,
            from    => $key,
        }

        ufw::allow { 'salt master port 4506 ipv6':
            proto   => 'tcp',
            port    => 4506,
            from    => $key,
        }
    }
 
    motd::role { 'role::salt::masters':
        description => 'Host the salt master',
    }
}
