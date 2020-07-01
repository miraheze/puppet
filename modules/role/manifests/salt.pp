class role::salt (
    String $salt_state_roots    = '/srv/salt',
    String $salt_file_roots     = '/srv/salt',
    String $salt_pillar_roots   = '/srv/pillars',
    String $salt_module_roots   = '/srv/salt/_modules',
    String $salt_returner_roots = '/srv/salt/_returners',
) {

    class { '::salt': }
 
    motd::role { 'role::salt':
        description => 'Host the salt master (salt-ssh)',
    }
}
