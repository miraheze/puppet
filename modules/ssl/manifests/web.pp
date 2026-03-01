# === Class ssl::web
class ssl::web {
    include ssl::nginx

    stdlib::ensure_packages(['python3-flask', 'python3-filelock'])

    file { '/usr/local/bin/wikitiderenewssl.py':
        ensure => present,
        source => 'puppet:///modules/ssl/wikitiderenewssl.py',
        mode   => '0755',
        notify => Service['wikitiderenewssl'],
    }

    file { '/usr/local/bin/renew-ssl':
        ensure => present,
        source => 'puppet:///modules/ssl/renewssl.py',
        mode   => '0755',
    }

    file { '/var/log/ssl':
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0750',
        before => [
            File['/usr/local/bin/wikitiderenewssl.py'],
            File['/usr/local/bin/renew-ssl'],
        ],
    }

    systemd::service { 'wikitiderenewssl':
        ensure  => present,
        content => systemd_template('wikitiderenewssl'),
        restart => true,
    }

    $subquery = @("PQL")
    resources { type = 'Class' and title = 'Role::Icinga2' }
    | PQL
    $firewall_rules_str = vmlib::generate_firewall_ip($subquery)
    ferm::service { 'icinga 5000':
        proto  => 'tcp',
        port   => '5000',
        srange => "(${firewall_rules_str})",
    }

    if ( $facts['networking']['interfaces']['ens19'] and $facts['networking']['interfaces']['ens18'] ) {
        $address = $facts['networking']['interfaces']['ens19']['ip']
    } elsif ( $facts['networking']['interfaces']['ens18'] ) {
        $address = $facts['networking']['interfaces']['ens18']['ip6']
    } else {
        $address = $facts['networking']['ip6']
    }

    monitoring::services { 'WikiTideRenewSSL':
        check_command => 'tcp',
        docs          => 'https://meta.miraheze.org/wiki/Tech:Icinga/MediaWiki_Monitoring#WikiTideRenewSSL',
        vars          => {
            tcp_address => $address,
            tcp_port    => '5000',
        },
    }
}
