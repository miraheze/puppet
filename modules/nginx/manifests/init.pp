# nginx
#
class nginx {
    package { [ 'nginx-light', 'nginx-common' ]: }

    service { 'nginx':
        ensure     => 'running',
        enable     => true,
        provider   => 'debian',
        hasrestart => true,
    }
}
