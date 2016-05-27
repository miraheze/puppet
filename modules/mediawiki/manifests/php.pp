# mediawiki::php
	file { '/etc/php5/fpm/php-fpm.conf':
		ensure => 'present',
        mode   => 0755,
        source => 'puppet:///modules/mediawiki/php/php-fpm.conf',
    }

    file { '/etc/php5/fpm/pool.d/www.conf':
        ensure => 'present',
        mode   => 0755,
        source => 'puppet:///modules/mediawiki/php/www.conf',
    }

    file { '/etc/php5/fpm/php.ini':
        ensure => present,
        mode   => 0755,
        source => 'puppet:///modules/mediawiki/php/php.ini',
    }
}
