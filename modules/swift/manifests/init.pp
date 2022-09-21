# == Class: swift

class swift {

    ensure_packages(['swift', 'python3-swift', 'python3-swiftclient'])

    $hash_path_suffix = lookup('swift_hash_path_suffix')

    file {
        default:
            owner   => 'swift',
            group   => 'swift',
            mode    => '0440',
            require => Package['swift'];
        '/etc/swift':
            ensure  => directory,
            recurse => true;
        '/etc/swift/swift.conf':
            ensure  => file,
            content => template('swift/swift.conf.erb');
        '/var/cache/swift':
            ensure => directory,
            mode   => '0755';
        # Create swift user home.
        '/var/lib/swift':
            ensure => directory,
            mode   => '0755',
    }

    file { '/var/log/swift':
        ensure  => directory,
    }
}
