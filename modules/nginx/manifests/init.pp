# nginx
#
class nginx {
    package { 'nginx':
        ensure  => present,
        require => Apt::Source['nginx_apt'],
    }

    service { 'nginx':
        ensure     => 'running',
        enable     => true,
        provider   => 'debian',
        hasrestart => true,
    }
    
    file { [ '/etc/nginx/sites-available', '/etc/nginx/sites-enabled' ]:
        ensure => 'directory',
        mode   => 0755,
        owner  => 'root',
        group  => 'root',
    }
}
