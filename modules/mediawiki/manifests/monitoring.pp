# MediaWiki monitoring
class mediawiki::monitoring {
    if hiera('base::monitoring::use_icinga2', false) {
        icinga2::custom::services { 'mediawiki_rendering':
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

    if os_version('debian >= stretch') {
        if hiera('base::monitoring::use_icinga2', false) {
            icinga2::custom::services { 'php7.0-fpm':
                check_command => 'nrpe',
                vars          => {
                    nrpe_command => 'check_php_fpm_7',
                },
            }
        } else {
            icinga::service { 'php7.0-fpm':
                description   => 'php7.0-fpm',
                check_command => 'check_nrpe_1arg!check_php_fpm_7',
            }
        }
    } else {
        if hiera('base::monitoring::use_icinga2', false) {
            icinga2::custom::services { 'php5-fpm':
                check_command => 'nrpe',
                vars          => {
                    nrpe_command => 'check_php_fpm_5',
                },
            }
        } else {
            icinga::service { 'php5-fpm':
                description   => 'php5-fpm',
                check_command => 'check_nrpe_1arg!check_php_fpm_5',
            }
        }
   }
}
