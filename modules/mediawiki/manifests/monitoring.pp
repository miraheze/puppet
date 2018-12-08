# MediaWiki monitoring
class mediawiki::monitoring {

    monitoring::services { 'MediaWiki Rendering':
        check_command => 'check_mediawiki',
        vars          => {
            host    => 'login.miraheze.org',
            address => 'host.address',
        },
    }

    monitoring::services { 'php7.2-fpm':
        check_command => 'nrpe',
        vars          => {
            nrpe_command => 'check_php_fpm_7_2',
        },
    }
}
