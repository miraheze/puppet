# role: mathoid
class role::mathoid {
    include ::mathoid

    motd::role { 'role::mathoid':
        description => 'Mediawiki Mathoid Service',
    }
}
