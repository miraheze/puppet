# role: mediawiki
class role::mediawiki {
    include ::mediawiki

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

    package { 'nfs-common':
        ensure => purged,
    }
}
