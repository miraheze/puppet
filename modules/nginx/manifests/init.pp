# nginx
#
class nginx {
    package { 'nginx':
        ensure  => present,
    }

    service { 'nginx':
        ensure     => 'running',
        enable     => true,
        provider   => 'debian',
        hasrestart => true,
    }

    file { '/etc/logrotate.d/nginx':
        ensure => present,
        source => 'puppet:///modules/nginx/logrotate',
    }
}
