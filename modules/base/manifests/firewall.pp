# firewall for all servers
class base::firewall (
  Enum['ferm', 'ufw'] $firewall_mode = lookup('base::firewall::mode', {'default_value' => 'ufw'})
) {
    if $firewall_mode == 'ufw' {
        # Ensure ferm is purged when installing ufw.
        package { 'ferm':
          ensure => purged,
        }

        include ::ufw

        ufw::allow { 'ssh':
          proto => 'tcp',
          port  => 22,
        }

        $firewall_rules = query_facts('Class[Role::Icinga2]', ['ipaddress', 'ipaddress6'])
        $firewall_rules.each |$key, $value| {
          ufw::allow { "nrpe ${value['ipaddress']} IPv4":
            proto => 'tcp',
            port  => 5666,
            from  => $value['ipaddress'],
          }

          ufw::allow { "nrpe ${value['ipaddress6']} IPv6":
            proto => 'tcp',
            port  => 5666,
            from  => $value['ipaddress6'],
          }
        }

        file { '/root/ufw-fix':
          ensure => present,
          source => 'puppet:///modules/base/ufw/ufw-fix',
          mode   => '0755',
        }
    } else {
        # Ensure ufw is purged when installing ferm.
        package { 'ufw':
            ensure => purged,
        }

        include ferm

        # Increase the size of conntrack table size (default is 65536)
        sysctl::parameters { 'ferm_conntrack':
            values => {
                'net.netfilter.nf_conntrack_max'                   => 262144,
                'net.netfilter.nf_conntrack_tcp_timeout_time_wait' => 65,
            },
        }

        # The sysctl value net.netfilter.nf_conntrack_buckets is read-only. It is configured
        # via a modprobe parameter, bump it manually for running systems
        exec { 'bump nf_conntrack hash table size':
            command => '/bin/echo 32768 > /sys/module/nf_conntrack/parameters/hashsize',
            onlyif  => "/bin/grep --invert-match --quiet '^32768$' /sys/module/nf_conntrack/parameters/hashsize",
        }

        ferm::conf { 'main':
            prio   => '02',
            source => 'puppet:///modules/base/firewall/main-input-default-drop.conf',
        }

        $firewall_rules = query_facts('Class[Role::Icinga2]', ['ipaddress', 'ipaddress6'])
        $firewall_rules_mapped = $firewall_rules.map |$key, $value| { "${value['ipaddress']} ${value['ipaddress6']}" }
        $firewall_rules_str = join($firewall_rules_mapped, ' ')
        ferm::service { 'nrpe':
            proto  => 'tcp',
            port   => '5666',
            srange => "(${firewall_rules_str})",
        }

        ferm::service { 'ssh':
            proto  => 'tcp',
            port   => '22',
        }

        class { '::ulogd': }

        # Explicitly drop pxe/dhcp packets packets so they dont hit the log
        ferm::filter_log { 'filter-bootp':
            proto => 'udp',
            daddr => '255.255.255.255',
            sport => 67,
            dport => 68,
        }

        ferm::rule { 'log-everything':
            rule => "NFLOG mod limit limit 1/second limit-burst 5 nflog-prefix \"[fw-in-drop]\";",
            prio => '98',
        }

        file { '/usr/lib/nagios/plugins/check_conntrack':
            source => 'puppet:///modules/base/firewall/check_conntrack.py',
            mode   => '0755',
        }

        monitoring::services { 'conntrack_table_size':
            check_command   => 'nrpe',
            vars            => {
                nrpe_command => 'conntrack_table_size',
            },
            require         => File['/usr/lib/nagios/plugins/check_conntrack'],
        }

        sudo::user { 'nagios_check_ferm':
            user       => 'nagios',
            privileges => [ 'ALL = NOPASSWD: /usr/lib/nagios/plugins/check_ferm' ],
            require    => File['/usr/lib/nagios/plugins/check_ferm'],
        }

        file { '/usr/lib/nagios/plugins/check_ferm':
            source => 'puppet:///modules/base/firewall/check_ferm',
            owner  => 'root',
            group  => 'root',
            mode   => '0555',
        }

        monitoring::services { 'ferm_active':
          check_command   => 'nrpe',
          vars            => {
            nrpe_command  => 'ferm_active',
          },
          require         => [
            File['/usr/lib/nagios/plugins/check_ferm'],
            Sudo::User['nagios_check_ferm']
          ],
        }
    }
}
