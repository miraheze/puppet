# role: matomo
class role::matomo {
    include ::matomo

    motd::role { 'role::matomo':
        description => 'central analytics server',
    }
}
