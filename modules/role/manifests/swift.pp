# role: swift
class role::swift (
    String $stats_reporter_host = lookup('role::swift::stats_reporter_host'),
    String $swift_expirer_host = lookup('role::swift::expirer_host'),
) {

    include ::swift
    include ::swift::ring


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

        firewall::service { 'http':
            proto    => 'tcp',
            port     => 80,
            src_sets => ['SWIFT_HOSTS', 'MEDIAWIKI_HOSTS', 'MEDIAWIKI_TASK_HOSTS', 'MEDIAWIKI_BETA_HOSTS', 'PROMETHEUS_HOSTS', 'BASTION_HOSTS', 'VARNISH_HOSTS', 'CACHE_CACHE_HOSTS', 'ICINGA2_HOSTS'],
            notrack  => true,
        }

        firewall::service { 'https':
            proto    => 'tcp',
            port     => 443,
            src_sets => ['SWIFT_HOSTS', 'MEDIAWIKI_HOSTS', 'MEDIAWIKI_TASK_HOSTS', 'MEDIAWIKI_BETA_HOSTS', 'PROMETHEUS_HOSTS', 'BASTION_HOSTS', 'VARNISH_HOSTS', 'CACHE_CACHE_HOSTS', 'ICINGA2_HOSTS'],
            notrack  => true,
        }

        if lookup('swift_enable_memcache', {'default_value' => false}) {
            include role::memcached

            firewall::service { 'swift_memcache_11211':
                proto    => 'tcp',
                port     => 11211,
                src_sets => ['SWIFT_HOSTS', 'MEDIAWIKI_HOSTS', 'MEDIAWIKI_TASK_HOSTS', 'MEDIAWIKI_BETA_HOSTS', 'PROMETHEUS_HOSTS', 'BASTION_HOSTS', 'VARNISH_HOSTS', 'CACHE_CACHE_HOSTS', 'ICINGA2_HOSTS'],
                notrack  => true,
            }
        }
    }

    $ac = lookup('swift_ac_enable', {'default_value' => false})
    if $ac {
        include ::swift::ac

        firewall::service { 'swift_account_6002':
            proto    => 'tcp',
            port     => 6002,
            src_sets => ['SWIFT_HOSTS', 'MEDIAWIKI_HOSTS', 'MEDIAWIKI_TASK_HOSTS', 'MEDIAWIKI_BETA_HOSTS', 'PROMETHEUS_HOSTS', 'BASTION_HOSTS', 'VARNISH_HOSTS', 'CACHE_CACHE_HOSTS', 'ICINGA2_HOSTS'],
            notrack  => true,
        }

        firewall::service { 'swift_container_6001':
            proto    => 'tcp',
            port     => 6001,
            src_sets => ['SWIFT_HOSTS', 'MEDIAWIKI_HOSTS', 'MEDIAWIKI_TASK_HOSTS', 'MEDIAWIKI_BETA_HOSTS', 'PROMETHEUS_HOSTS', 'BASTION_HOSTS', 'VARNISH_HOSTS', 'CACHE_CACHE_HOSTS', 'ICINGA2_HOSTS'],
            notrack  => true,
        }

        firewall::service { 'swift-rsync':
            proto    => 'tcp',
            port     => 873,
            notrack  => true,
            src_sets => ['SWIFT_HOSTS', 'MEDIAWIKI_HOSTS', 'MEDIAWIKI_TASK_HOSTS', 'MEDIAWIKI_BETA_HOSTS', 'PROMETHEUS_HOSTS', 'BASTION_HOSTS', 'VARNISH_HOSTS', 'CACHE_CACHE_HOSTS', 'ICINGA2_HOSTS'],
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

        firewall::service { 'swift_object_6000':
            proto    => 'tcp',
            port     => 6000,
            src_sets => ['SWIFT_HOSTS', 'MEDIAWIKI_HOSTS', 'MEDIAWIKI_TASK_HOSTS', 'MEDIAWIKI_BETA_HOSTS', 'PROMETHEUS_HOSTS', 'BASTION_HOSTS', 'VARNISH_HOSTS', 'CACHE_CACHE_HOSTS', 'ICINGA2_HOSTS'],
            notrack  => true,
        }

        firewall::service { 'swift-rsync':
            proto    => 'tcp',
            port     => 873,
            notrack  => true,
            src_sets => ['SWIFT_HOSTS', 'MEDIAWIKI_HOSTS', 'MEDIAWIKI_TASK_HOSTS', 'MEDIAWIKI_BETA_HOSTS', 'PROMETHEUS_HOSTS', 'BASTION_HOSTS', 'VARNISH_HOSTS', 'CACHE_CACHE_HOSTS', 'ICINGA2_HOSTS'],
        }
    }

    class { 'role::prometheus::statsd_exporter':
        relay_address => '',
    }

    system::role { 'swift':
        description => 'OpenStack Swift Service (Accounting, Container, Proxy, Object)',
    }
}
