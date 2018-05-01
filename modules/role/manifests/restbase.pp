# role: restbase
class role::restbase {
    include ::restbase

    motd::role { 'role::restbase':
        description => 'Mediawiki RESTBase Service',
    }
}
