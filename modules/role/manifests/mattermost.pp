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
        version          => '11.4.2',
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

    $subquery = @("PQL")
    resources { type = 'Class' and title = 'Role::Mattermost' }
    | PQL
    $firewall_rules_str = vmlib::generate_firewall_ip($subquery)

    ferm::service { 'postgresql':
        proto   => 'tcp',
        port    => '5432',
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }

    ferm::service { 'mattermost':
        proto   => 'tcp',
        port    => '8065',
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }

    $cloudflare_ipv4 = split(file('/etc/puppetlabs/puppet/private/files/firewall/cloudflare_ipv4'), /[\r\n]/)
    $cloudflare_ipv6 = split(file('/etc/puppetlabs/puppet/private/files/firewall/cloudflare_ipv6'), /[\r\n]/)

    $subquery_2 = @("PQL")
    resources { type = 'Class' and title = 'Role::Icinga2' }
    | PQL
    $cf_ip = join($cloudflare_ipv4 + $cloudflare_ipv6, ' ')
    $ip = vmlib::generate_firewall_ip($subquery_2)
    $firewall_rules_cloudflare_str = "${cf_ip} ${ip}"

    ferm::service { 'http':
        proto   => 'tcp',
        port    => '80',
        # srange  => "(${$firewall_rules_cloudflare_str})",
        notrack => true,
    }

    ferm::service { 'https':
        proto   => 'tcp',
        port    => '443',
        # srange  => "(${$firewall_rules_cloudflare_str})",
        notrack => true,
    }

    ferm::service { 'https-quic':
        proto   => 'udp',
        port    => '443',
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
