# MediaWiki monitoring
class mediawiki::monitoring (
    Boolean $php7_2 = hiera('mediawiki::use_php_7_2', false),
) {

    icinga2::custom::services { 'MediaWiki Rendering':
        check_command => 'check_mediawiki',
        vars          => {
            host    => 'login.miraheze.org',
            address => 'host.address',
        },
    }

    if $php7_2 {
        icinga2::custom::services { 'php7.2-fpm':
            check_command => 'nrpe',
            vars          => {
                nrpe_command => 'check_php_fpm_7_2',
            },
        }
    } else {
        icinga2::custom::services { 'php7.0-fpm_7':
            check_command => 'nrpe',
            vars          => {
                nrpe_command => 'check_php_fpm_7',
            },
        }
    }
}
