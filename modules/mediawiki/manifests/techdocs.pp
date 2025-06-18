# === Class mediawiki::techdocs
class mediawiki::techdocs {
    stdlib::ensure_packages('python3-mwparserfromhell')
    stdlib::ensure_packages(
        'GitPython',
        {
            provider        => 'pip3',
            install_options => [ '--break-system-packages' ],
            before          => File['/usr/local/bin/techdocs'],
            require         => Package['python3-pip'],
        },
    )

    file { '/usr/local/bin/techdocs':
        ensure => present,
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
        source => 'puppet:///modules/mediawiki/bin/techdocs.py',
    }

    file { '/srv/statichelp':
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0770',
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

    git::clone { 'statichelp':
        ensure    => present,
        directory => '/srv/statichelp',
        origin    => 'git@github.com:miraheze/statichelp.git',
        ssh       => 'ssh -i /var/lib/nagios/id_ed25519 -F /dev/null -o ProxyCommand=\'nc -X connect -x bastion.fsslc.wtnet:8080 %h %p\'',
        require   => [
            File['/var/lib/nagios/id_ed25519'],
            File['/var/lib/nagios/id_ed25519.pub'],
            File['/srv/statichelp'],
        ],
    }

    systemd::timer::job { 'update-static-tech-docs':
        ensure            => present,
        description       => 'Update static tech documentation',
        command           => '/usr/bin/python3 /usr/local/bin/techdocs',
        interval          => {
            'start'    => 'OnCalendar',
            'interval' => 'Sun *-*-* 00:00:00',
        },
        user              => 'root',
        logfile_basedir   => '/var/log/mediawiki',
        logfile_name      => 'update-static-tech-docs.log',
        logfile_group     => 'root',
        syslog_identifier => 'update-static-tech-docs',
    }
}
