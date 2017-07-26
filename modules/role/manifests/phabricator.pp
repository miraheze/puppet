# role: phabricator
class role::phabricator {
    include ::phabricator

    motd::role { 'role::phabricator':
        description => 'phabricator instance',
    }
}
