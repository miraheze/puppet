class role::salt {

    class { '::salt': }

    motd::role { 'role::salt':
        description => 'Host the salt master (salt-ssh)',
    }
}
