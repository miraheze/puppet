# MediaWiki monitoring
class mediawiki::monitoring {
    $php7_2 = hiera('mediawiki::use_php_7_2', false)

    if hiera('base::monitoring::use_icinga2', false) {
        icinga2::custom::services { 'MediaWiki Rendering':
            check_command => 'check_mediawiki',
            vars          => {
                host    => 'meta.miraheze.org',
                address => 'host.address',
            },
        }
    } else {
        icinga::service { 'mediawiki_rendering':
            description   => 'MediaWiki Rendering',
            check_command => 'check_mediawiki!meta.miraheze.org',
        }
    }

    if hiera('base::monitoring::use_icinga2', false) {
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
    } else {
        if $php7_2 {
            icinga::service { 'php7.2-fpm':
                description   => 'php7.2-fpm',
                check_command => 'check_nrpe_1arg!check_php_fpm_7_2',
            }
        } else {
            icinga::service { 'php7.0-fpm':
                description   => 'php7.0-fpm',
                check_command => 'check_nrpe_1arg!check_php_fpm_7',
            }
        }
    }
}
