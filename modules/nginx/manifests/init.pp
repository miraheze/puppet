# nginx
class nginx {
    package { 'nginx':
        ensure  => present,
    }

    # Ensure Apache is absent: https://phabricator.miraheze.org/T253
    package { 'apache2':
        ensure  => absent,
    }

    service { 'nginx':
        ensure      => 'running',
        enable      => true,
        provider    => 'debian',
        hasrestart  => true,
        require     => Package['apache2'],
    }

    file { '/etc/logrotate.d/nginx':
        ensure => present,
        source => 'puppet:///modules/nginx/logrotate',
    }
}
