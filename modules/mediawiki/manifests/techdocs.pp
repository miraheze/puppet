# === Class mediawiki::techdocs
class mediawiki::techdocs {
    stdlib::ensure_packages(['python3-git', 'python3-mwparserfromhell'])

    file { '/usr/local/bin/techdocs':
        ensure => present,
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
        source => 'puppet:///modules/mediawiki/bin/techdocs.py',
    }

    file { '/var/lib/nagios/id_ed25519':
        ensure => present,
        source => 'puppet:///private/acme/id_ed25519',
        owner  => 'root',
        group  => 'root',
        mode   => '0400',
    }

    file { '/var/lib/nagios/id_ed25519.pub':
        ensure => present,
        source => 'puppet:///private/acme/id_ed25519.pub',
        owner  => 'root',
        group  => 'root',
        mode   => '0644',
    }

    systemd::timer::job { 'update-static-tech-docs':
        ensure            => present,
        description       => 'Update static tech documentation',
        command           => '/usr/bin/python3 /usr/local/bin/techdocs',
        interval          => {
            'start'    => 'OnCalendar',
            'interval' => 'daily',
        },
        user              => 'root',
        logfile_basedir   => '/var/log/mediawiki',
        logfile_name      => 'update-static-tech-docs.log',
        logfile_group     => 'root',
        syslog_identifier => 'update-static-tech-docs',
    }
}
