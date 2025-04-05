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
        version          => '10.6.1',
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

    $firewall_rules_str = join(
        query_facts('Class[Role::Mattermost]', ['networking'])
        .map |$key, $value| {
            if ( $value['networking']['interfaces']['ens19'] and $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens19']['ip']} ${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } elsif ( $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } else {
                "${value['networking']['ip']} ${value['networking']['ip6']}"
            }
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )

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

    $firewall_rules_cloudflare_str = join(
        $cloudflare_ipv4 + $cloudflare_ipv6 + query_facts('Class[Role::Varnish] or Class[Role::Icinga2]', ['networking'])
        .map |$key, $value| {
            if ( $value['networking']['interfaces']['he-ipv6'] ) {
                "${value['networking']['ip']} ${value['networking']['interfaces']['he-ipv6']['ip6']}"
            } elsif ( $value['networking']['interfaces']['ens19'] and $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens19']['ip']} ${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } elsif ( $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } else {
                "${value['networking']['ip']} ${value['networking']['ip6']}"
            }
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )

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

    # Backup provisioning
    file { '/srv/backups':
        ensure => directory,
    }

    file { '/var/log/mattermost-backup':
        ensure => 'directory',
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
    }

    systemd::timer::job { 'mattermost-data-backup':
        description       => 'Runs backup of mattermost data',
        command           => '/usr/local/bin/wikitide-backup backup mattermost-data',
        interval          => {
            'start'    => 'OnCalendar',
            'interval' => '*-*-1,15 01:00:00',
        },
        logfile_basedir   => '/var/log/mattermost-backup',
        logfile_name      => 'mattermost-data.log',
        syslog_identifier => 'mattermost-data',
        user              => 'root',
    }

    systemd::timer::job { 'mattermost-db-backup':
        description       => 'Runs backup of mattermost db',
        command           => '/usr/local/bin/wikitide-backup backup mattermost-db',
        interval          => {
            'start'    => 'OnCalendar',
            'interval' => '*-*-1,15 01:00:00',
        },
        logfile_basedir   => '/var/log/mattermost-backup',
        logfile_name      => 'mattermost-db.log',
        syslog_identifier => 'mattermost-db',
        user              => 'root',
    }

    monitoring::nrpe { 'Backups Mattermost Data':
        command  => '/usr/lib/nagios/plugins/check_file_age -w 1555200 -c 1814400 -f /var/log/mattermost-backup/mattermost-data/mattermost-data.log',
        docs     => 'https://meta.miraheze.org/wiki/Backups#General_backup_Schedules',
        critical => true
    }

    monitoring::nrpe { 'Backups Mattermost DB':
        command  => '/usr/lib/nagios/plugins/check_file_age -w 1555200 -c 1814400 -f /var/log/mattermost-backup/mattermost-db/mattermost-db.log',
        docs     => 'https://meta.miraheze.org/wiki/Backups#General_backup_Schedules',
        critical => true
    }

    monitoring::nrpe { 'Mattermost':
        command => '/usr/lib/nagios/plugins/check_procs -a /opt/mattermost/bin/mattermost -c 1:1'
    }

    system::role { 'role::mattermost':
        description => 'Mattermost server',
    }
}
