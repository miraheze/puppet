# === Class ssl::web
class ssl::web {
    include ssl::nginx

    stdlib::ensure_packages(['python3-flask', 'python3-filelock'])

    file { '/usr/local/bin/mirahezerenewssl.py':
        ensure => present,
        source => 'puppet:///modules/ssl/mirahezerenewssl.py',
        mode   => '0755',
        notify => Service['mirahezerenewssl'],
    }

    file { '/usr/local/bin/renew-ssl':
        ensure => present,
        source => 'puppet:///modules/ssl/renewssl.py',
        mode   => '0755',
    }

    systemd::service { 'mirahezerenewssl':
        ensure  => present,
        content => systemd_template('mirahezerenewssl'),
        restart => true,
    }

    $firewall_rules_str = join(
        query_facts('Class[Role::Icinga2]', ['networking'])
        .map |$key, $value| {
            "${value['networking']['ip']} ${value['networking']['ip6']}"
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )
    ferm::service { 'icinga 5000':
        proto  => 'tcp',
        port   => '5000',
        srange => "(${firewall_rules_str})",
    }

    monitoring::services { 'MirahezeRenewSsl':
        check_command => 'tcp',
        docs          => 'https://meta.miraheze.org/wiki/Tech:Icinga/MediaWiki_Monitoring#MirahezeRenewSSL',
        vars          => {
            tcp_address => $facts['networking']['ip6'],
            tcp_port    => '5000',
        },
    }
}
