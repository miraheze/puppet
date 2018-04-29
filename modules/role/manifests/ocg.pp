# role: ocg
class role::ocg {
    include ::ocg

    motd::role { 'role::ocg':
        description => 'Offline content generator server',
    }
}
