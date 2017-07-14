# role: piwik
class role::piwik {
    include ::piwik

    motd::role { 'role::piwik':
        description => 'central analytics server',
    }
}
