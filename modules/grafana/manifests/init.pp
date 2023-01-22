# class: grafana
class grafana (
    String $grafana_password = lookup('passwords::db::grafana'),
    String $mail_password = lookup('passwords::mail::noreply'),
    String $ldap_password = lookup('passwords::ldap_password'),
    String $grafana_db_host = lookup('grafana_db_host', {'default_value' => 'db112.miraheze.org'}),
) {

    include ::apt

    file { '/usr/share/keyrings/grafana.key':
        ensure => present,
        source => 'puppet:///modules/grafana/grafana.key',
    }

    apt::source { 'grafana_apt':
        comment  => 'Grafana stable',
        location => 'https://apt.grafana.com',
        release  => 'stable',
        repos    => 'main',
        keyring  => '/usr/share/keyrings/grafana.key',
        require  => File['/usr/share/keyrings/grafana.key'],
        notify   => Exec['apt_update_grafana'],
    }

    exec {'apt_update_grafana':
        command     => '/usr/bin/apt-get update',
        refreshonly => true,
        logoutput   => true,
    }

    package { 'grafana':
        ensure  => present,
        require => Apt::Source['grafana_apt'],
    }

    file { '/etc/grafana/grafana.ini':
        content => template('grafana/grafana.ini.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        notify  => Service['grafana-server'],
        require => Package['grafana'],
    }

    file { '/etc/grafana/ldap.toml':
        content => template('grafana/ldap.toml.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        notify  => Service['grafana-server'],
        require => Package['grafana'],
    }

    service { 'grafana-server':
        ensure  => 'running',
        enable  => true,
        require => Package['grafana'],
    }

    ssl::wildcard { 'grafana wildcard': }

    nginx::site { 'grafana.miraheze.org':
        ensure => present,
        source => 'puppet:///modules/grafana/nginx/grafana.conf',
    }

    monitoring::services { 'grafana.miraheze.org HTTPS':
        check_command => 'check_http',
        vars          => {
            http_ssl   => true,
            http_vhost => 'grafana.miraheze.org',
        },
    }
}
