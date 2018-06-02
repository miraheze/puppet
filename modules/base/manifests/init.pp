# class: base
class base {
    include apt
    include base::packages
    include base::puppet
    include base::rsyslog
    include base::ssl
    include base::timezone
    include base::upgrades
    include base::ufw
    include base::monitoring
    include ssh
    include users

    if hiera('acme') {
        include acme
    }

    if hiera('arcanist') {
        include base::arcanist
    }

    if !hiera('mailserver') {
        include base::mail
    }

    file { '/usr/local/bin/gen_fingerprints':
        ensure => present,
        source => 'puppet:///modules/base/environment/gen_fingerprints',
        mode   => '0555',
    }
    
    class { 'apt::backports': }

    # Create a user to allow db transfers between servers
    users::user { 'nagios':
        ensure      => present,
        uid         => 3001,
        ssh_keys    => [
            'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDTRdK2A00FRVV60Db+qJLspRw+mYnsG3X+MK3UR6JuK6bmueXA03Y1QNAxGsMIJarvTpuzEU30v/zh4NuQFCCX7vBKQfFxV32SyTIT7OQQpdzh0VlHzGQPq2Oz0fcDDxvCm5cldPZkq/rdQu5Qt395LHSLsiu7hblErlaUfFJ8UPIpIzi87NfaCvZiEad+kcqR5ELoK3LKUbu7vtv+UoCjSzc4eD/OFIuIhXFNk0TlRJppG5XxgnKgL3B1ho/x8i3f6mTwu6zx3IX6tO+0GN00nLVRbOGhZhvDuM2iSeQCKaQ0SbXRsn+DIEt2fUQT5D9xP1uTKB5+/NgWb0L4vVvd/a7rjpVniKWQjzJUxiel4/AjBudDwImP5wN7t8P3+4zYa/ooL8qe15nv40J66LuzRT0MNV4NCjNTrv2lOBMVz+cMy+xFDUtChleoABBQence8iqUvmZ2cH7GrK5IiKbRTjyIesfPmd+ewcRXmIQ0Y/UXTYi1oJqVP+pslQDa3aTgJGSgWvwbRFmQRHwLodAv3QXYT3KKbdPiynEvZ6A7qPkULGfeZ/W/R/JEr70csnHqKqvkz81jnqM9MFw2oDwU2vlhoHBhea8A+SJv38wAAuzpbcTzNQP8feXgKWnHavP6uRDxO8KUbV4LTt2Fveb+livtCGidU4wBtagDfTkgzQ== root@db3'
        ],
    }
}
