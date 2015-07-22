class role::mediawiki {
    include ::mediawiki
    include hhvm

    ufw::allow { 'http port tcp':
        proto => 'tcp',
        port  => 80,
    }

    ufw::allow { 'https port tcp':
        proto => 'tcp',
        port  => 443,
    }

    motd::role { 'role::mediawiki':
        description => 'MediaWiki server',
    }
}
