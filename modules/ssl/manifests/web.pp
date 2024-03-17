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

    file { '/var/log/ssl':
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0750',
        before => [
            File['/usr/local/bin/mirahezerenewssl.py'],
            File['/usr/local/bin/renew-ssl'],
        ],
    }

    systemd::service { 'mirahezerenewssl':
        ensure  => present,
        content => systemd_template('mirahezerenewssl'),
        restart => true,
    }

    $firewall_rules_str = join(
        query_facts('Class[Role::Icinga2]', ['networking'])
        .map |$key, $value| {
            if ( $value['networking']['interfaces']['ens19'] and $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens19']['ip']} ${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } elsif ( $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } else {
                "${value['networking']['ip']} ${value['networking']['ip6']}"
            }
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

    if ( $facts['networking']['interfaces']['ens19'] and $facts['networking']['interfaces']['ens18'] ) {
        $address = $facts['networking']['interfaces']['ens19']['ip']
    } elsif ( $facts['networking']['interfaces']['ens18'] ) {
        $address = $facts['networking']['interfaces']['ens18']['ip6']
    } else {
        $address = $facts['networking']['ip6']
    }

    monitoring::services { 'MirahezeRenewSsl':
        check_command => 'tcp',
        docs          => 'https://meta.miraheze.org/wiki/Tech:Icinga/MediaWiki_Monitoring#MirahezeRenewSSL',
        vars          => {
            tcp_address => $address,
            tcp_port    => '5000',
        },
    }
}
