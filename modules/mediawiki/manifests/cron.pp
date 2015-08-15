# class: mediawiki::cron
class mediawiki::cron {
    $cron_log = "/var/log/mediawiki/cron/${title}"

    cron { 'jobqueue':
        ensure  => present,
        command => "/usr/local/bin/foreachwikiindblist /srv/mediawiki/dblist/all.dblist /srv/mediawiki/w/maintenance/runJobs.php > ${cron_log}",
        user    => 'www-data',
        minute  => '*/10',
    }

    cron { 'purge_checkuser':
        ensure  => present,
        command => "/usr/local/bin/foreachwikiindblist /srv/mediawiki/dblist/all.dblist /srv/mediawiki/w/extensions/CheckUser/maintenance/purgeOldData.php > ${cron_log}",
        user    => 'www-data',
        minute  => '0',
        hour    => '*/12',
    }

    cron { 'purge_abusefilter':
        ensure => present,
        command => "/usr/local/bin/foreachwikiindblist /srv/mediawiki/dblist/all.dblist /srv/mediawiki/w/extensions/AbuseFilter/maintenance/purgeOldLogIPData.php > ${cron_log}",
        user    => 'www-data',
        minute  => '0',
        hour    => '*/12',
    }
}
