# class: ssh::client
class ssh::client {
    package { 'openssh-client':
        ensure => latest,
    }
}
