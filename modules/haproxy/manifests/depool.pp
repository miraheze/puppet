# === Class haproxy::depool
#
# API used by safe-service-restart to depool a backend from the load balancer
# pools of a cache host, and the lb-ctl tool for the same on a single host.
class haproxy::depool (
    Stdlib::Absolutepath $state_file = '/var/lib/haproxy/server-state',
) {
    stdlib::ensure_packages([
        'python3-flask',
        'python3-pyotp',
        'gunicorn',
    ])

    file { '/opt/haproxy-depool':
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0700',
    }

    file { '/opt/haproxy-depool/haproxy-depool.py':
        ensure  => present,
        source  => 'puppet:///modules/haproxy/haproxy-depool.py',
        owner   => 'root',
        group   => 'root',
        mode    => '0700',
        notify  => Service['haproxy-depool'],
        require => File['/opt/haproxy-depool'],
    }

    file { '/usr/local/sbin/lb-ctl':
        ensure => present,
        source => 'puppet:///modules/haproxy/lb-ctl.py',
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
    }

    $totp_secret = lookup('passwords::varnish::varnish_totp_secret')
    systemd::service { 'haproxy-depool':
        ensure  => present,
        content => systemd_template('haproxy-depool', {
            'totp_secret' => $totp_secret,
            'state_file'  => $state_file,
        }),
        restart => true,
        require => File['/opt/haproxy-depool/haproxy-depool.py'],
    }

    $subquery = @("PQL")
    (resources { type = 'Class' and title = 'Role::Icinga2' } or
    resources { type = 'Class' and title = 'Role::Mediawiki' } or
    resources { type = 'Class' and title = 'Role::Mediawiki_task' })
    | PQL
    $firewall_rules_str = vmlib::generate_firewall_ip($subquery)
    firewall::service { "${facts['networking']['fqdn']} haproxy depool service port 5001":
        proto  => 'tcp',
        port   => 5001,
        srange => "(${firewall_rules_str})",
    }

    if ($facts['networking']['interfaces']['ens19'] and $facts['networking']['interfaces']['ens18']) {
        $address = $facts['networking']['interfaces']['ens19']['ip']
    } elsif ($facts['networking']['interfaces']['ens18']) {
        $address = $facts['networking']['interfaces']['ens18']['ip6']
    } else {
        $address = $facts['networking']['ip6']
    }

    monitoring::services { 'haproxy-depool service':
        check_command => 'tcp',
        vars          => {
            tcp_address => $address,
            tcp_port    => '5001',
        },
    }

    # TODO: remove once puppet runs
    systemd::service { 'varnish-depool':
        ensure  => absent,
        content => '',
        before  => Service['haproxy-depool'],
    }

    file { '/opt/varnish-depool':
        ensure  => absent,
        force   => true,
        require => Systemd::Service['varnish-depool'],
    }

    firewall::service { "${facts['networking']['fqdn']} varnish depool service port 5001":
        ensure => absent,
        proto  => 'tcp',
        port   => 5001,
    }

    monitoring::services { 'varnish-depool service':
        ensure        => absent,
        check_command => 'tcp',
    }
}
