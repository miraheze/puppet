# role: mailman3
class role::mailman {
    include ::mailman

    motd::role { 'role::mailman':
        description => 'Mail List',
    }
}
