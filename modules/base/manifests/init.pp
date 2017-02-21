# class: base
class base {
    include base::packages
    include base::puppet
    include base::timezone
    include base::upgrades
    include base::monitoring
    include base::rsyslog
    include base::ufw
    include base::ssl
    include ssh
    include users

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
}
