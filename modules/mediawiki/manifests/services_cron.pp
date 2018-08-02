# class: mediawiki::services_cron
class mediawiki::services_cron {
      file { '/srv/services/id_rsa':
        ensure => present,
        source => 'puppet:///private/acme/id_rsa',
        owner  => 'nagiosre',
        group  => 'nagiosre',
        mode   => '0400',
      }

      cron { 'generate_services':
          ensure  => present,
          command => '/bin/bash /usr/local/bin/pushServices.sh',
          user    => 'www-data',
          minute  => '*/5',
          hour    => '*',
      }
}
