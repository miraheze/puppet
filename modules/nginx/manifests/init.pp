# nginx
class nginx (
    Variant[String, Integer] $nginx_worker_processes                  = lookup('nginx::worker_processes', {'default_value' => 'auto'}),
    Boolean                  $use_graylog                             = lookup('nginx::use_graylog', {'default_value' => false}),
    Boolean                  $remove_apache                           = lookup('nginx::remove_apache', {'default_value' => true}),
    Integer                  $logrotate_number                        = lookup('nginx::logrotate_number', {'default_value' => 12}),
    String                   $logrotate_maxsize                       = lookup('nginx::logrotate_maxsize', {'default_value' => '5G'}),
    Integer                  $keepalive_timeout                       = lookup('nginx::keepalive_timeout', {'default_value' => 60}),
    Integer                  $keepalive_requests                      = lookup('nginx::keepalive_requests', {'default_value' => 1000}),
    String                   $nginx_client_max_body_size              = lookup('nginx::client_max_body_size', {'default_value' => '250M'}),
    Boolean                  $use_varnish_directly                    = lookup('nginx::use_varnish_directly', {'default_value' => true}),
) {
    if $remove_apache {
        # Ensure Apache is absent: https://issue-tracker.miraheze.org/T253
        package { 'apache2':
            ensure => absent,
        }
    }

    # We need to check the syntax before we reload
    systemd::unit { 'nginx.service':
        ensure   => present,
        content  => template('nginx/nginx-systemd-override.conf.erb'),
        override => true,
        restart  => false,
    }

    if $remove_apache {
        package { 'nginx':
            ensure  => present,
            require => Package['apache2'],
            notify  => Exec['nginx unmask'],
        }
    } else {
        package { 'nginx':
            ensure => present,
            notify => Exec['nginx unmask'],
        }
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

    $mem_gb = $facts['memory']['system']['total_bytes'] / 1073741824.0
    if ($mem_gb < 3.0) {
        $ssl_session_cache = 256
    } elsif ($mem_gb < 4.0) {
        $ssl_session_cache = 1024
    } else {
        $ssl_session_cache = 2048
    }

    $cache_proxies = query_facts("Class['Role::Varnish']", ['networking'])
    $cloudflare_ipv4 = split(file('/etc/puppetlabs/puppet/private/files/firewall/cloudflare_ipv4'), /[\r\n]/)
    $cloudflare_ipv6 = split(file('/etc/puppetlabs/puppet/private/files/firewall/cloudflare_ipv6'), /[\r\n]/)
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

    class { 'logrotate':
        hourly => true,
    }

    logrotate::conf { 'nginx':
        ensure  => present,
        content => template('nginx/logrotate.erb'),
    }

    # Include nginx prometheus exported on all hosts that use the nginx class
    include prometheus::exporter::nginx
}
