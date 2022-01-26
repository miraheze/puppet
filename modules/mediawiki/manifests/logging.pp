# === Class mediawiki::logging
class mediawiki::logging {
    file { [
        '/var/log/mediawiki',
        '/var/log/mediawiki/cron',
        '/var/log/mediawiki/debuglogs'
    ]:
        ensure => 'directory',
        owner  => 'www-data',
        group  => 'www-data',
        mode   => '0755',
    }

    logrotate::conf { 'mediawiki_cron_logs':
        ensure => present,
        source => 'puppet:///modules/mediawiki/logging/mediawiki_cron_logs.logrotate.conf',
    }

    logrotate::conf { 'mediawiki_debug_logs':
        ensure => present,
        source => 'puppet:///modules/mediawiki/logging/mediawiki_debug_logs.logrotate.conf',
    }
}
