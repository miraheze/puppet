class salt (
    Optional[String] $salt_interface      = undef,
    Optional[String] $salt_worker_threads = undef,
    String $salt_runner_dirs              = '/srv/runners',
    String $salt_file_roots               = '/srv/salt',
    String $salt_pillar_roots             = '/srv/pillar',
    Hash $salt_ext_pillar                 = {},
    String $salt_reactor_root             = '/srv/reactors',
    Hash $salt_reactor                    = {},
    Hash $salt_peer                       = {},
    Hash $salt_peer_run                   = {},
    Hash $salt_nodegroups                 = {},
    String $salt_state_roots              = '/srv/salt',
    String $salt_module_roots             = '/srv/salt/_modules',
    String $salt_returner_roots           = '/srv/salt/_returners',
) {
    package { 'salt-ssh':
        ensure  => 'absent',
    }

    $host = query_nodes("domain='$domain'", 'fqdn')
    file { '/etc/salt/roster':
        content => template('salt/roster.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        require => Package['salt-ssh'],
    }
}
