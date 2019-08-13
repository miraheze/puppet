# = Class: prometheus::nginx
#

class prometheus::nginx {

    file { '/usr/local/bin/nginx-prometheus-exporter':
        ensure => file,
        mode   => '0555',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/prometheus/nginx/nginx-prometheus-exporter',
    }

    systemd::service { 'nginx-prometheus-exporter':
        ensure  => present,
        content => systemd_template('nginx-prometheus-exporter'),
        restart => true,
        require => [
            File['/usr/local/bin/nginx-prometheus-exporter'],
        ],
    }

    ufw::allow { 'prometheus access 9113':
        proto => 'tcp',
        port  => 9113,
        from  => '185.52.3.121',
    }
}
