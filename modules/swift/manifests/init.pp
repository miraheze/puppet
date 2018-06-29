# == Class: swift

class swift {

    require_package('swift')

    file { '/etc/swift/swift.conf':
        ensure  => present,
        source  => 'puppet:///modules/swift/swift.conf',
        require => Package['swift'],
    }

    if hiera('swift_proxy', false) {
        include swift::proxy
    }

    # TODO: create class
    #if hiera('swift_backend', false) {
    #    include swift::backend
    #}
}
