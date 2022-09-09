# === Class ssl::web
class ssl::web {
    include ssl::nginx

    ensure_packages(['python3-flask', 'python3-filelock'])

    file { '/usr/local/bin/mirahezerenewssl.py':
        ensure => present,
        source => 'puppet:///modules/ssl/mirahezerenewssl.py',
        mode   => '0755',
        notify => Service['mirahezerenewssl'],
    }

    systemd::service { 'mirahezerenewssl':
        ensure  => present,
        content => systemd_template('mirahezerenewssl'),
        restart => true,
    }

    $firewall_rules = query_facts('Class[Role::Icinga2]', ['ipaddress', 'ipaddress6'])
    $firewall_rules_mapped = $firewall_rules.map |$key, $value| { "${value['ipaddress']} ${value['ipaddress6']}" }
    $firewall_rules_str = join($firewall_rules_mapped, ' ')
    ferm::service { 'icinga 5000':
        proto  => 'tcp',
        port   => '5000',
        srange => "(${firewall_rules_str})",
    }

    monitoring::services { 'MirahezeRenewSsl':
        check_command => 'tcp',
        docs          => 'https://meta.miraheze.org/wiki/Tech:Icinga/MediaWiki_Monitoring#MirahezeRenewSSL',
        vars          => {
            tcp_address => $::ipaddress6,
            tcp_port    => '5000',
        },
    }
}
