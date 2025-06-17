# === Class mediawiki::techdocs
class mediawiki::techdocs {
    stdlib::ensure_packages(['python3-GitPython', 'python3-mwparserfromhell'])

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
        branch    => 'main',
        owner     => 'www-data',
        group     => 'www-data',
        mode      => '0755',
        ssh       => 'ssh -i /var/lib/nagios/id_ed25519 -F /dev/null -o ProxyCommand=\'nc -X connect -x bastion.fsslc.wtnet:8080 %h %p\'',
        require   => [
            File['/var/lib/nagios/id_ed25519'],
            File['/var/lib/nagios/id_ed25519.pub'],
            File['/srv/statichelp'],
        ],
    }

    mediawiki::periodic_job { 'update-static-tech-docs':
        command  => '/usr/bin/python3 /usr/local/bin/techdocs',
        interval => 'Sun *-*-* 00:00:00',
    }
}
