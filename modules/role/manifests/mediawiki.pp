# role: mediawiki
class role::mediawiki {
    include ::mediawiki

    $strictFirewall = lookup('role::mediawiki::use_strict_firewall', {'default_value' => false})
    if $strictFirewall {
        $firewall_rules = query_facts('Class[Role::Mediawiki] or Class[Role::Varnish] or Class[Role::Services] or Class[Role::Icinga2]', ['ipaddress', 'ipaddress6'])
        $firewall_rules_mapped = $firewall_rules.map |$key, $value| { "${value['ipaddress']} ${value['ipaddress6']}" }
        $firewall_rules_str = join($firewall_rules_mapped, ' ')

        ferm::service { 'http':
            proto  => 'tcp',
            port   => '80',
            srange => '($firewall_rules_str)',
        }

        ferm::service { 'https':
            proto  => 'tcp',
            port   => '443',
            srange => '($firewall_rules_str)',
        }
    } else {
        ferm::service { 'http':
            proto => 'tcp',
            port  => '80',
        }

        ferm::service { 'https':
            proto => 'tcp',
            port  => '443',
        }
    }

    motd::role { 'role::mediawiki':
        description => 'MediaWiki server',
    }

    # $gluster_volume_backup = lookup('gluster_volume_backup', {'default_value' => 'glusterfs2.miraheze.org:/mvol'})
    # backup-volfile-servers=
    if !defined(Gluster::Mount['/mnt/mediawiki-static']) {
        gluster::mount { '/mnt/mediawiki-static':
          ensure    => mounted,
          volume    => lookup('gluster_volume', {'default_value' => 'gluster3.miraheze.org:/static'}),
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
