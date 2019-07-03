# = Class: prometheus::nginx
#

class prometheus::nginx {

    file { '/etc/prometheus-nginxlog-exporter.hcl':
        ensure => file,
        mode   => '0444',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/prometheus/nginx/prometheus-nginxlog-exporter.hcl',
    }

    file { '/usr/local/bin/prometheus-nginxlog-exporter':
        ensure => file,
        mode   => '0555',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/prometheus/nginx/prometheus-nginxlog-exporter',
    }

    systemd::service { 'prometheus-nginxlog-exporter':
        ensure  => present,
        content => systemd_template('prometheus-nginxlog-exporter'),
        restart => true,
        require => [
            File['/usr/local/bin/prometheus-nginxlog-exporter'],
            File['/etc/prometheus-nginxlog-exporter.hcl'],
        ],
    }

    ufw::allow { 'prometheus access 4040':
        proto => 'tcp',
        port  => 4040,
        from  => '185.52.3.121',
    }
}
