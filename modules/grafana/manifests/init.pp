# class: grafana
class grafana (
    String $mail_password = lookup('passwords::mail::noreply'),
    String $ldap_password = lookup('passwords::ldap_password'),
    Optional[String] $http_proxy = lookup('http_proxy', {'default_value' => undef}),
    String $no_proxy = lookup('grafana::no_proxy', {'default_value' => 'localhost,127.0.0.1,::1,10.0.0.0/8,.fsslc.wtnet,ldap.wikitide.net,opensearch.wikitide.net'}),
    VMlib::Ensure $proxy_ensure = lookup('grafana::proxy_ensure', {'default_value' => absent}),
) {

    include apt

    file { '/etc/apt/keyrings/grafana.gpg':
        ensure => present,
        source => 'puppet:///modules/grafana/grafana.gpg',
    }

    apt::source { 'grafana_apt':
        comment  => 'Grafana stable',
        location => 'https://apt.grafana.com',
        release  => 'stable',
        repos    => 'main',
        keyring  => '/etc/apt/keyrings/grafana.gpg',
        require  => File['/etc/apt/keyrings/grafana.gpg'],
        notify   => Exec['apt_update_grafana'],
    }

    exec {'apt_update_grafana':
        command     => '/usr/bin/apt-get update',
        refreshonly => true,
        logoutput   => true,
    }

    package { ['grafana', 'sqlite3']:
        ensure  => present,
        require => Apt::Source['grafana_apt'],
    }

    file { '/etc/grafana/grafana.ini':
        content => epp('grafana/grafana.ini.epp'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        notify  => Service['grafana-server'],
        require => Package['grafana'],
    }

    file { '/etc/grafana/ldap.toml':
        content => epp('grafana/ldap.toml.epp', { 'ldap_password' => $ldap_password }),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        notify  => Service['grafana-server'],
        require => Package['grafana'],
    }

    systemd::override { 'proxy':
        ensure  => $http_proxy ? {
            undef   => absent,
            default => $proxy_ensure,
        },
        unit    => 'grafana-server',
        restart => true,
        content => join([
            '[Service]',
            "Environment=\"HTTP_PROXY=${http_proxy}\"",
            "Environment=\"HTTPS_PROXY=${http_proxy}\"",
            "Environment=\"NO_PROXY=${no_proxy}\"",
            '',
        ], "\n"),
        require => Package['grafana'],
    }

    service { 'grafana-server':
        ensure  => 'running',
        enable  => true,
        require => Package['grafana'],
    }

    nginx::site { 'grafana.wikitide.net':
        ensure => present,
        source => 'puppet:///modules/grafana/nginx/grafana.conf',
    }

    ssl::wildcard { 'grafana wildcard': }

    if ( $facts['networking']['interfaces']['ens19'] and $facts['networking']['interfaces']['ens18'] ) {
        $address = $facts['networking']['interfaces']['ens19']['ip']
    } elsif ( $facts['networking']['interfaces']['ens18'] ) {
        $address = $facts['networking']['interfaces']['ens18']['ip6']
    } else {
        $address = $facts['networking']['ip6']
    }

    monitoring::services { 'grafana.wikitide.net HTTPS':
        check_command => 'check_http',
        vars          => {
            address    => $address,
            http_ssl   => true,
            http_vhost => 'grafana.wikitide.net',
        },
    }
}
