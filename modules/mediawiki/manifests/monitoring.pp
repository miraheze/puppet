# MediaWiki monitoring
class mediawiki::monitoring {
    icinga::service { 'mediawiki_rendering':
        description   => 'MediaWiki Rendering',
        check_command => 'check_mediawiki!meta.miraheze.org',
    }

    if os_version('debian >= stretch') {
        icinga::service { 'php7.0-fpm':
            description   => 'php7.0-fpm',
            check_command => 'check_nrpe_1arg!check_php_fpm_7',
        }
    } else {
        icinga::service { 'php5-fpm':
            description   => 'php5-fpm',
            check_command => 'check_nrpe_1arg!check_php_fpm_5',
        }
   }
}
