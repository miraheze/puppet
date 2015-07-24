class role::ganglia {
    include ::ganglia

    motd::role { 'role::ganglia':
        description => 'central Ganglia server',
    }
}
