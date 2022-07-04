# class: ssh::server
class ssh::server (
    String $listen_port = '22',
    Boolean $permit_root = false,
    Optional[String] $authorized_keys_file = undef,
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

    if $::ipaddress6 == undef {
        $aliases = [ $::hostname, $::ipaddress ]
    } elsif $::ipaddress6 != undef and $::ipaddress == undef {
        $aliases = [ $::hostname, $::ipaddress6 ]
    } else {
        $aliases = [ $::hostname, $::ipaddress, $::ipaddress6 ]
    }

    debug("Storing ecdsa-sha2-nistp256 SSH hostkey for ${::fqdn}")
    @@sshkey { $::fqdn:
        ensure       => present,
        type         => 'ecdsa-sha2-nistp256',
        key          => $::sshecdsakey,
        host_aliases => $aliases,
    }
}
