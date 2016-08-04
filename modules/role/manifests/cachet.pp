class role::cachet {
    include ::cachet

    motd::role { 'role::cachet':
        description => 'status page server',
    }
}
