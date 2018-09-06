# class: role::dbreplication
class role::dbreplication {
    include mariadb::packages

    class { 'mariadb::config':
        config      => 'mariadb/config/mw.cnf.erb',
        password    => hiera('passwords::db::root'),
        server_role => 'slave',
    }

    ufw::allow { 'mysql port db4':
        proto => 'tcp',
        port  => '3306',
        from  => '81.4.109.166',
    }

    file { '/etc/ssl/private':
        ensure  => directory,
        owner   => 'root',
        group   => 'mysql',
        mode	=> '0750',
    }

    include ssl::wildcard

    # Create a user to allow db transfers between servers
    users::user { 'dbcopy':
        ensure      => present,
        uid         => 3000,
        ssh_keys    => [
            'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDTRdK2A00FRVV60Db+qJLspRw+mYnsG3X+MK3UR6JuK6bmueXA03Y1QNAxGsMIJarvTpuzEU30v/zh4NuQFCCX7vBKQfFxV32SyTIT7OQQpdzh0VlHzGQPq2Oz0fcDDxvCm5cldPZkq/rdQu5Qt395LHSLsiu7hblErlaUfFJ8UPIpIzi87NfaCvZiEad+kcqR5ELoK3LKUbu7vtv+UoCjSzc4eD/OFIuIhXFNk0TlRJppG5XxgnKgL3B1ho/x8i3f6mTwu6zx3IX6tO+0GN00nLVRbOGhZhvDuM2iSeQCKaQ0SbXRsn+DIEt2fUQT5D9xP1uTKB5+/NgWb0L4vVvd/a7rjpVniKWQjzJUxiel4/AjBudDwImP5wN7t8P3+4zYa/ooL8qe15nv40J66LuzRT0MNV4NCjNTrv2lOBMVz+cMy+xFDUtChleoABBQence8iqUvmZ2cH7GrK5IiKbRTjyIesfPmd+ewcRXmIQ0Y/UXTYi1oJqVP+pslQDa3aTgJGSgWvwbRFmQRHwLodAv3QXYT3KKbdPiynEvZ6A7qPkULGfeZ/W/R/JEr70csnHqKqvkz81jnqM9MFw2oDwU2vlhoHBhea8A+SJv38wAAuzpbcTzNQP8feXgKWnHavP6uRDxO8KUbV4LTt2Fveb+livtCGidU4wBtagDfTkgzQ== root@db3'
        ],
    }

    motd::role { 'role::dbreplication':
        description => 'replication backup database server',
    }
}
