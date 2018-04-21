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

    logrotate::conf { 'mediawiki_wikilogs':
        ensure => present,
        source => 'puppet:///modules/mediawiki/mediawiki_wikilogs.logrotate.conf',
    }

    logrotate::conf { 'mediawiki_debuglogs':
        ensure => present,
        source => 'puppet:///modules/mediawiki/mediawiki_debuglogs.logrotate.conf',
    }
}
