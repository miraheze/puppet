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
}
