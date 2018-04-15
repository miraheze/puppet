class role::salt::masters {

    $salt_state_roots    = { 'base' => ['/srv/salt'] }
    $salt_file_roots     = { 'base' => ['/srv/salt'] }
    $salt_pillar_roots   = { 'base' => ['/srv/pillars'] }
    $salt_module_roots   = { 'base' => ['/srv/salt/_modules'] }
    $salt_returner_roots = { 'base' => ['/srv/salt/_returners'] }

    class { 'salt::master':
        salt_runner_dir     => '/srv/runners',
        salt_file_roots     => $salt_file_roots,
        salt_pillar_roots   => $salt_pillar_roots,
        salt_worker_threads => '50',
        salt_state_roots    => $salt_state_roots,
        salt_module_roots   => $salt_module_roots,
        salt_returner_roots => $salt_returner_roots,
        salt_auto_accept    => true,
    }

    include ::salt::master::key

    ufw::allow { 'salt-master 1':
        proto => 'tcp',
        port  => 4505,
    }

    ufw::allow { 'salt-master 2':
        proto => 'tcp',
        port  => 4506,
    }

    motd::role { 'role::salt::masters':
        description => 'Host the salt master',
    }
}
