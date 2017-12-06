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
}
