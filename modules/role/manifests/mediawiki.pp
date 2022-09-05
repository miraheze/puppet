# === Class role::mediawiki
class role::mediawiki (
    Boolean $strict_firewall = lookup('role::mediawiki::use_strict_firewall', {'default_value' => false})
) {
    include prometheus::exporter::cadvisor

    include ::role::mediawiki::nutcracker
    include ::mediawiki

    if $strict_firewall {
        $firewall_rules_str = join(
            query_facts('Class[Role::Mediawiki] or Class[Role::Varnish] or Class[Role::Icinga2] or Class[Role::Prometheus]', ['ipaddress', 'ipaddress6'])
            .map |$key, $value| {
                "${value['ipaddress']} ${value['ipaddress6']}"
            }
            .flatten()
            .unique()
            .sort(),
            ' '
        )

        ferm::service { 'http':
            proto   => 'tcp',
            port    => '80',
            srange  => "(${firewall_rules_str})",
            notrack => true,
        }

        ferm::service { 'https':
            proto   => 'tcp',
            port    => '443',
            srange  => "(${firewall_rules_str})",
            notrack => true,
        }
    } else {
        ferm::service { 'http':
            proto   => 'tcp',
            port    => '80',
            notrack => true,
        }

        ferm::service { 'https':
            proto   => 'tcp',
            port    => '443',
            notrack => true,
        }
    }

    motd::role { 'role::mediawiki':
        description => 'MediaWiki server',
    }

    if !defined(Gluster::Mount['/mnt/mediawiki-static']) {
        gluster::mount { '/mnt/mediawiki-static':
          ensure => mounted,
          volume => lookup('gluster_volume', {'default_value' => 'gluster.miraheze.org:/static'}),
        }
    }

    file { '/usr/local/bin/remountGluster.sh':
        ensure => 'present',
        mode   => '0755',
        source => 'puppet:///modules/role/mediawiki/bin/remountGluster.sh',
    }

    cron { 'check_mount':
        ensure  => present,
        command => '/bin/bash /usr/local/bin/remountGluster.sh',
        user    => 'root',
        minute  => '*/1',
        hour    => '*',
    }
}
