# class: mediawiki::services_cron
class mediawiki::services_cron {
    file { '/srv/services':
        ensure => 'directory',
        owner  => 'www-data',
        group  => 'www-data',
        mode   => '0755',
    }

    file { '/srv/services/id_ed25519':
        ensure  => present,
        source  => 'puppet:///private/acme/id_ed25519',
        owner   => 'www-data',
        group   => 'www-data',
        mode    => '0400',
        require => File['/srv/services'],
    }

    cron { 'generate_services':
        ensure  => present,
        command => '/bin/bash /usr/local/bin/pushServices.sh',
        user    => 'www-data',
        minute  => '*/5',
        hour    => '*',
    }
}
