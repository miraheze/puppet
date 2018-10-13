# MediaWiki monitoring
class mediawiki::monitoring {

    icinga2::custom::services { 'MediaWiki Rendering':
        check_command => 'check_mediawiki',
        vars          => {
            host    => 'login.miraheze.org',
            address => 'host.address',
        },
    }

    icinga2::custom::services { 'php7.2-fpm':
        check_command => 'nrpe',
        vars          => {
            nrpe_command => 'check_php_fpm_7_2',
        },
    }
}
