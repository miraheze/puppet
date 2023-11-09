class poolcounter {

    file { '/usr/bin/poolcounterd':
        ensure  => present,
        mode   => '0755',
        source => 'puppet:///modules/poolcounter/binary/poolcounterd',
    }

    systemd::service { 'poolcounter':
        ensure  => present,
        content => systemd_template('poolcounter'),
        restart => true,
    }
}
