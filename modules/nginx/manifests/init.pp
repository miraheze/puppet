# nginx
class nginx (
    Variant[String, Integer] $nginx_worker_processes = lookup('nginx::worker_processes', {'default_value' => 'auto'}),
    Boolean $use_graylog                             = lookup('nginx::use_graylog', {'default_value' => false}),
    Integer $logrotate_number                        = lookup('nginx::logrotate_number', {'default_value' => 12}),
    Integer $keepalive_timeout                       = lookup('nginx::keepalive_timeout', {'default_value' => 60}),
    Integer $keepalive_requests                      = lookup('nginx::keepalive_requests', {'default_value' => 1000}),
) {
    # Ensure Apache is absent: https://phabricator.miraheze.org/T253
    package { 'apache2':
        ensure  => absent,
    }

    # We need to check the syntax before we reload
    systemd::unit { 'nginx.service':
        ensure   => present,
        content  => template('nginx/nginx-systemd-override.conf.erb'),
        override => true,
        restart  => false,
    }

    package { 'nginx':
        ensure  => present,
        require => Package['apache2'],
        notify  => Exec['nginx unmask'],
    }

    file { [ '/etc/nginx', '/etc/nginx/sites-available', '/etc/nginx/sites-enabled' ]:
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
        notify => Service['nginx'],
    }

    file { '/etc/nginx/mime.types':
        ensure => present,
        source => 'puppet:///modules/nginx/mime.types',
    }

    $module_path = get_module_path('varnish')

    $cache_proxies = query_facts("domain='${domain}' and Class['Role::Varnish']", ['ipaddress', 'ipaddress6'])
    file { '/etc/nginx/nginx.conf':
        content => template('nginx/nginx.conf.erb'),
        require => Package['nginx'],
        notify  => Service['nginx'],
    }

    file { '/etc/nginx/fastcgi_params':
        ensure => present,
        source => 'puppet:///modules/nginx/fastcgi_params',
        notify => Service['nginx'],
    }

    exec { 'nginx unmask':
        command     => '/bin/systemctl unmask nginx.service',
        refreshonly => true,
    }

    service { 'nginx':
        ensure  => 'running',
        enable  => true,
        restart => '/bin/systemctl reload nginx.service',
        require => [
            Exec['nginx unmask'],
            File['/etc/nginx/mime.types'],
            File['/etc/nginx/nginx.conf'],
            File['/etc/nginx/fastcgi_params']
        ],
    }

    logrotate::conf { 'nginx':
        ensure  => present,
        content => template('nginx/logrotate.erb'),
    }

    # Include nginx prometheus exported on all hosts that use the nginx class
    include prometheus::exporter::nginx
}
