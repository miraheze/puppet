class role::salt (
    String $salt_state_roots    = '/srv/salt'
    String $salt_file_roots     = '/srv/salt'
    String $salt_pillar_roots   = '/srv/pillars'
    String $salt_module_roots   = '/srv/salt/_modules'
    String $salt_returner_roots = '/srv/salt/_returners'
) {

    class { '::salt':
        salt_interface      => '::',
        salt_runner_dirs    => '/srv/runners',
        salt_file_roots     => $salt_file_roots,
        salt_pillar_roots   => $salt_pillar_roots,
        salt_worker_threads => '5',
        salt_state_roots    => $salt_state_roots,
        salt_module_roots   => $salt_module_roots,
        salt_returner_roots => $salt_returner_roots,
    }
 
    motd::role { 'role::salt':
        description => 'Host the salt master (salt-ssh)',
    }
}
