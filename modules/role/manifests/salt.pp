class role::salt {

    class { '::salt': }

    motd::role { 'role::salt':
        description => 'Salt master (salt-ssh)',
    }
}
