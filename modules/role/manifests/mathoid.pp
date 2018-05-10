# role: mathoid
class role::mathoid {
    include ::mathoid

    ufw::allow { 'mathoid monitoring':
        proto => 'tcp',
        port  => 10044,
        from  => '185.52.1.76',
    }

    motd::role { 'role::mathoid':
        description => 'Mediawiki Mathoid Service',
    }
}
