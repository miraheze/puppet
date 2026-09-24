# === Class ssl::custom_domain_checker
class ssl::custom_domain_checker {
    file { '/usr/local/bin/custom_domain_checker':
        ensure => present,
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
        source => 'puppet:///modules/ssl/bin/custom_domain_checker',
    }

    file { '/tokens/cloudflare_ssl.txt':
        ensure => present,
        content => lookup('passwords::mediawiki::cloudflare_requestcustomdomain_apikey')
        owner  => 'root',
        group  => 'root',
        mode   => '0400',
    }
    file { '/tokens/cloudflare_zone.txt':
        ensure => present,
        content => lookup('cloudflare::zone_id')
        owner  => 'root',
        group  => 'root',
        mode   => '0644',
    }

    systemd::timer::job { 'check-custom-domains':
        ensure            => present,
        description       => 'Check custom domain availability and remove if unavailable for 3 days',
        command           => '/usr/local/bin/custom_domain_checker',
        interval          => {
            'start'    => 'OnCalendar',
            'interval' => 'daily',
        },
        user              => 'root',
        logfile_basedir   => '/var/log/ssl',
        logfile_name      => 'check-custom-domains.log',
        logfile_group     => 'root',
        syslog_identifier => 'check-custom-domains',
    }
}