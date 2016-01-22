class role::surveys {
    include ::limesurvey

    motd::role { 'role::surveys':
        description => 'surveys server',
    }
}
