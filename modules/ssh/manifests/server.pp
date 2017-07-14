# class: ssh::server
class ssh::server (
    $listen_port = '22',
    $permit_root = false,
    $authorized_keys_file = undef,
) {
    package { 'openssh-server':
        ensure => latest;
    }

    service { 'ssh':
        ensure    => running,
        subscribe => File['/etc/ssh/sshd_config'],
    }

    if $authorized_keys_file {
        $ssh_authorized_keys_file = $authorized_keys_file
    } else {
        $ssh_authorized_keys_file ='/etc/ssh/userkeys/%u .ssh/authorized_keys'
    }

    file { '/etc/ssh/userkeys':
        ensure  => directory,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        recurse => true,
        purge   => true,
    }

    file { '/etc/ssh/sshd_config':
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        content => template('ssh/sshd_config.erb'),
    }
}
