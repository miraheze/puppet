class role::salt {

    class { '::salt': }

    system::role { 'salt':
        description => 'Salt master (salt-ssh)',
    }
}
