# class: mediawiki::jobrunner
#
# Crons which should be ran on a jobrunner selected machine only.
class mediawiki::jobrunner {
    cron { 'jobqueue':
        ensure  => present,
        command => '/usr/bin/flock -xn "/usr/local/bin/foreachwikiindblist /srv/mediawiki/dblist/all.dblist /srv/mediawiki/w/maintenance/runJobs.php" > /var/log/mediawiki/cron/jobqueue.log',
        user    => 'www-data',
        minute  => '*/15',
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
}
