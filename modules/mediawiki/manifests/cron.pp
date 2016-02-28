# class: mediawiki::cron
class mediawiki::cron {
    # HACK BAD BAD HACK
    cron { 'hhvm_hack_restart':
        ensure  => present,
        command => "/usr/sbin/service hhvm restart",
        user    => 'root',
        hour    => '*/2',
    }

    cron { 'jobqueue':
        ensure  => present,
        command => '/usr/bin/flock -xn "/usr/local/bin/foreachwikiindblist /srv/mediawiki/dblist/all.dblist /srv/mediawiki/w/maintenance/runJobs.php" > /var/log/mediawiki/cron/jobqueue.log',
        user    => 'www-data',
        minute  => '*/10',
    }

    cron { 'purge_checkuser':
        ensure  => present,
        command => '/usr/local/bin/foreachwikiindblist /srv/mediawiki/dblist/all.dblist /srv/mediawiki/w/extensions/CheckUser/maintenance/purgeOldData.php > /var/log/mediawiki/cron/purge_checkuser.log',
        user    => 'www-data',
        minute  => '0',
        hour    => '*/12',
    }

    cron { 'purge_abusefilter':
        ensure => present,
        command => '/usr/local/bin/foreachwikiindblist /srv/mediawiki/dblist/all.dblist /srv/mediawiki/w/extensions/AbuseFilter/maintenance/purgeOldLogIPData.php > /var/log/mediawiki/cron/purge_abusefilter.log',
        user    => 'www-data',
        minute  => '0',
        hour    => '*/12',
    }
    
    cron { 'update_database_lists':
        ensure  => present,
        command => '/usr/bin/php /srv/mediawiki/w/extensions/CreateWiki/DBListGenerator.php --wiki metawiki',
        user    => 'www-data',
        minute  => '*',
        hour    => '*',
    }
}
