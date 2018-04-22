# MediaWiki monitoring
class mediawiki::monitoring {
    if hiera('base::monitoring::user_icinga2', false) {
        Icinga2::Object::Service { 'mediawiki_rendering':
            description   => 'MediaWiki Rendering',
            check_command => 'check_mediawiki!meta.miraheze.org',
        }
    } else {
        icinga::service { 'mediawiki_rendering':
            description   => 'MediaWiki Rendering',
            check_command => 'check_mediawiki!meta.miraheze.org',
        }
    }

    if os_version('debian >= stretch') {
        if hiera('base::monitoring::user_icinga2', false) {
            Icinga2::Object::Service { 'php7.0-fpm':
                description   => 'php7.0-fpm',
                check_command => 'check_nrpe_1arg!check_php_fpm_7',
            }
        } else {
            icinga::service { 'php7.0-fpm':
                description   => 'php7.0-fpm',
                check_command => 'check_nrpe_1arg!check_php_fpm_7',
            }
        }
    } else {
        if hiera('base::monitoring::user_icinga2', false) {
            Icinga2::Object::Service { 'php5-fpm':
                description   => 'php5-fpm',
                check_command => 'check_nrpe_1arg!check_php_fpm_5',
            }
        } else {
            icinga::service { 'php5-fpm':
                description   => 'php5-fpm',
                check_command => 'check_nrpe_1arg!check_php_fpm_5',
            }
        }
   }
}
