# role: swift
class role::swift (
    String $stats_reporter_host = lookup('role::swift::stats_reporter_host'),
    String $swift_expirer_host = lookup('role::swift::expirer_host'),
) {

    include ::swift
    include ::swift::ring

    $subquery = @("PQL")
    (resources { type = 'Class' and title = 'Role::Swift' } or
    resources { type = 'Class' and title = 'Role::Mediawiki' } or
    resources { type = 'Class' and title = 'Role::Mediawiki_task' } or
    resources { type = 'Class' and title = 'Role::Mediawiki_beta' } or
    resources { type = 'Class' and title = 'Role::Prometheus' } or
    resources { type = 'Class' and title = 'Role::Bastion' } or
    resources { type = 'Class' and title = 'Role::Varnish' } or
    resources { type = 'Class' and title = 'Role::Cache::Cache' } or
    resources { type = 'Class' and title = 'Role::Icinga2' })
    | PQL
    $firewall_rules_str = vmlib::generate_firewall_ip($subquery)

    $proxy = lookup('swift_proxy_enable', {'default_value' => false})
    if $proxy {
        include ::swift::proxy

        # TODO: Put this as a param to the role
        $accounts      = lookup('swift::accounts')
        $accounts_keys = lookup('swift::accounts_keys')

        $stats_ensure = ($stats_reporter_host == $facts['networking']['fqdn']).bool2str('present','absent')

        class { 'swift::stats_reporter':
            ensure      => $stats_ensure,
            accounts    => $accounts,
            credentials => $accounts_keys,
        }

        swift::stats::stats_container { 'mw-media':
            ensure        => $stats_ensure,
            account_name  => 'AUTH_mw',
            container_set => 'mw-media',
            statsd_host   => 'localhost',
            statsd_port   => '9125',
            statsd_prefix => 'swift.containers.mw-media',
        }

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

        if lookup('swift_enable_memcache', {'default_value' => false}) {
            include role::memcached

            ferm::service { 'swift_memcache_11211':
                proto   => 'tcp',
                port    => '11211',
                srange  => "(${firewall_rules_str})",
                notrack => true,
            }
        }
    }

    $ac = lookup('swift_ac_enable', {'default_value' => false})
    if $ac {
        include ::swift::ac

        ferm::service { 'swift_account_6002':
            proto   => 'tcp',
            port    => '6002',
            srange  => "(${firewall_rules_str})",
            notrack => true,
        }

        ferm::service { 'swift_container_6001':
            proto   => 'tcp',
            port    => '6001',
            srange  => "(${firewall_rules_str})",
            notrack => true,
        }

        ferm::service { 'swift-rsync':
            proto   => 'tcp',
            port    => '873',
            notrack => true,
            srange  => "(${firewall_rules_str})",
        }
    }

    $object = lookup('swift_object_enable', {'default_value' => false})
    if $object {
        include ::swift::storage

        $expirer_ensure = $swift_expirer_host? {
            $facts['networking']['fqdn'] => 'present',
            default => 'absent',
        }
        class { 'swift::expirer':
            ensure               => $expirer_ensure,
            statsd_metric_prefix => "swift.${facts['networking']['hostname']}",
        }

        ferm::service { 'swift_object_6000':
            proto   => 'tcp',
            port    => '6000',
            srange  => "(${firewall_rules_str})",
            notrack => true,
        }

        ferm::service { 'swift-rsync':
            proto   => 'tcp',
            port    => '873',
            notrack => true,
            srange  => "(${firewall_rules_str})",
        }
    }

    class { 'role::prometheus::statsd_exporter':
        relay_address => '',
    }

    system::role { 'swift':
        description => 'OpenStack Swift Service (Accounting, Container, Proxy, Object)',
    }
}
