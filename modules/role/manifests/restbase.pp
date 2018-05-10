# role: restbase
class role::restbase {
    include ::restbase

    ufw::allow { 'restbase monitoring':
        proto => 'tcp',
        port  => 7231,
        from  => '185.52.1.76',
    }

    motd::role { 'role::restbase':
        description => 'Mediawiki RESTBase Service',
    }
}
