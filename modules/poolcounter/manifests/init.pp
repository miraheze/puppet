class poolcounter {

    group { 'poolcounter':
        ensure => present,
        system => true,
    }

    user { 'poolcounter':
        ensure => present,
        system => true,
        groups => 'poolcounter',
        home   => '/nonexistent',
    }

    file { '/usr/bin/poolcounterd':
        ensure  => present,
        mode   => '0755',
        source => 'puppet:///modules/poolcounter/binary/poolcounterd',
    }

    systemd::service { 'poolcounter':
        ensure  => present,
        content => systemd_template('poolcounter'),
        restart => true,
        require => File['/usr/bin/poolcounterd']
    }
}
