# === Class mediawiki::monitoring
class mediawiki::monitoring {
    monitoring::services { 'MediaWiki Rendering':
        check_command => 'check_mediawiki',
        vars          => {
            host    => 'login.miraheze.org',
            address => $facts['ipaddress'],
        },
    }

    monitoring::services { 'php-fpm':
        check_command => 'nrpe',
        vars          => {
            nrpe_command => 'check_php_fpm',
        },
    }
}
