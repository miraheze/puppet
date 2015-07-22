class role::ganglia {

    motd::role { 'role::ganglia':
        description => 'central Ganglia server',
    }
}
