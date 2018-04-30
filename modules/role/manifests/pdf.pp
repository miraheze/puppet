# role: pdf
class role::pdf {
    include ::pdf

    motd::role { 'role::pdf':
        description => 'Offline content generator server',
    }
}
