# nginx
#
class nginx {
    include ::apt
    apt::source { 'nginx_apt':
        comment  => 'nginx apt repo',
        location => 'http://nginx.org/packages/debian',
        release  => 'jessie',
        repos    => 'nginx',
        key      => '573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62',
    }
    
    package { 'nginx':
        ensure => present,
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
