# MediaWiki logging
class mediawiki::logging {
    file { [
        '/var/log/mediawiki',
        '/var/log/mediawiki/debuglogs'
    ]:
        ensure => 'directory',
        owner  => 'www-data',
        group  => 'www-data',
        mode   => '0755',
    }

    logrotate::rotate { 'mediawiki_wikilogs':
        logs   => '/var/log/mediawiki/*.log',
        rotate => '6',
        delay  => false,
    }

    logrotate::rotate { 'mediawiki_debuglogs':
        logs   => '/var/log/mediawiki/debuglogs/*.log',
        rotate => '6',
        delay  => false,
    }
}
