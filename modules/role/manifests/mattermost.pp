# === Role mattermost
class role::mattermost {
    class { 'postgresql::master':
        root_dir => lookup('postgresql::root_dir', {'default_value' => '/srv/postgres'}),
        use_ssl  => lookup('postgresql::ssl', {'default_value' => false}),
    }

    $mattermost_pass = lookup('passwords::postgresql::mattermost')
    # Create the mattermost user for localhost
    # This works on every server and is used for read-only db lookups
    postgresql::user { 'mattermost@localhost':
        ensure   => present,
        user     => 'mattermost',
        database => 'mattermost',
        password => $mattermost_pass,
        master   => true,
    }

    # Create the database
    postgresql::db { 'mattermost':
        owner   => 'mattermost',
        require => Class['postgresql::master'],
    }
    -> class { 'mattermost':
        edition          => 'enterprise',
        version          => '11.10.0',
        override_options => {
            'TeamSettings'    => {
                'SiteName'                  => 'WikiTide Foundation',
                'TeammateNameDisplay'       => 'nickname_full_name',
                'RestrictCreationToDomains' => 'wikitide.org',
                'EnableUserCreation'        => true,
                'EnableOpenServer'          => false,
            },
            'EmailSettings'   => {
                'SendEmailNotifications'   => true,
                'RequireEmailVerification' => true,
                'EnableSignInWithEmail'    => true,
                'EnableSignInWithUsername' => true,
                'SMTPServer'               => 'smtp-relay.gmail.com',
                'SMTPPort'                 => '465',
                'ConnectionSecurity'       => 'TLS',
                'FeedbackName'             => 'No Reply',
                'FeedbackEmail'            => 'noreply@wikitide.org',
            },
            'SupportSettings' => {
                'SupportEmail' => 'noreply@wikitide.org',
            },
            'ServiceSettings' => {
                'SiteURL'                          => 'https://mattermost.wikitide.net',
                'SessionLengthSSOInHours'          => 2160,
                'SessionLengthWebInHours'          => 2160,
                'SessionLengthMobileInHours'       => 2160,
                'EnablePostUsernameOverride'       => true,
                'EnablePostIconOverride'           => true,
                'EnableEmailInvitations'           => true,
                'EnableMultifactorAuthentication'  => true,
                'EnforceMultifactorAuthentication' => true,
                'ScheduledPosts'                   => true,
            },
            'SqlSettings'     => {
                'DriverName' => 'postgres',
                'DataSource' => "postgres://mattermost:${mattermost_pass}@localhost:5432/mattermost?sslmode=disable&connect_timeout=10",
            },
            'FileSettings'    => {
                'Directory' => '/var/mattermost/',
            },
            'LogSettings'     => {
                'FileLocation' => '/var/log/mattermost',
            },
        },
    }

    nginx::site { 'mattermost':
        ensure => present,
        source => 'puppet:///modules/role/mattermost/nginx.conf',
    }


    firewall::service { 'postgresql':
        proto    => 'tcp',
        port     => 5432,
        src_sets => ['MATTERMOST_HOSTS'],
        notrack  => true,
    }

    firewall::service { 'mattermost':
        proto    => 'tcp',
        port     => 8065,
        src_sets => ['MATTERMOST_HOSTS'],
        notrack  => true,
    }

    $cloudflare_ipv4 = split(file('/etc/puppetlabs/puppet/private/files/firewall/cloudflare_ipv4'), /[\r\n]/)
    $cloudflare_ipv6 = split(file('/etc/puppetlabs/puppet/private/files/firewall/cloudflare_ipv6'), /[\r\n]/)
    $cf_ip = join($cloudflare_ipv4 + $cloudflare_ipv6, ' ')

    firewall::service { 'http':
        proto   => 'tcp',
        port    => 80,
        # srange   => "(${cf_ip})",
        # src_sets => ['ICINGA2_HOSTS'],
        notrack => true,
    }

    firewall::service { 'https':
        proto   => 'tcp',
        port    => 443,
        # srange   => "(${cf_ip})",
        # src_sets => ['ICINGA2_HOSTS'],
        notrack => true,
    }

    firewall::service { 'https-quic':
        proto   => 'udp',
        port    => 443,
        notrack => true,
    }

    # Backups
    backup::job { 'mattermost-data':
        ensure          => present,
        interval        => '*-*-1,15 01:00:00',
        logfile_basedir => '/var/log/mattermost-backup',
    }

    backup::job { 'mattermost-db':
        ensure          => present,
        interval        => '*-*-1,15 01:00:00',
        logfile_basedir => '/var/log/mattermost-backup',
    }

    monitoring::nrpe { 'Mattermost':
        command => '/usr/lib/nagios/plugins/check_procs -a /opt/mattermost/bin/mattermost -c 1:1'
    }

    system::role { 'role::mattermost':
        description => 'Mattermost server',
    }
}
