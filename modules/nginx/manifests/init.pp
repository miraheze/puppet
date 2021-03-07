# nginx
class nginx (
    Variant[String, Integer] $nginx_worker_processes = lookup('nginx::worker_processes', {'default_value' => 'auto'}),
    Boolean $use_graylog                             = false,
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

    $cache_proxies = query_facts("domain='$domain' and Class['Role::Varnish']", ['ipaddress', 'ipaddress6'])
    $frame_whitelist = loadyaml("${module_path}/data/frame_whitelist.yaml")
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
        ensure     => 'running',
        enable     => true,
        hasrestart => true,
        require    => [
            Exec['nginx unmask'],
            File['/etc/nginx/mime.types'],
            File['/etc/nginx/nginx.conf'],
            File['/etc/nginx/fastcgi_params']
        ],
    }

    logrotate::conf { 'nginx':
        ensure => present,
        source => 'puppet:///modules/nginx/logrotate',
    }

    # Include nginx prometheus exported on all hosts that use the nginx class
    include prometheus::nginx
}
