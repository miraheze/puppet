# class: mediawiki::services_cron
class mediawiki::services_cron {
    cron { 'generate_services':
        ensure  => absent,
        command => '/bin/bash /usr/local/bin/pushServices.sh',
        user    => 'www-data',
        minute  => '*/5',
        hour    => '*',
    }
}
