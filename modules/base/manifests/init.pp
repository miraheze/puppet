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

    file { '/etc/apt/sources.list.d/security_updates.list':
        ensure => present,
        source => 'puppet:///modules/base/security_updates.list',
    }

    # Create a user to allow executing renewing ssl script between servers
    users::user { 'nagiosre':
        ensure      => present,
        uid         => 3001,
        ssh_keys    => [
            'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDkaCSnz6EWa4Dc3WtvqxXG/5QuhOEfzCraZUfMDDCLTjJrrWxo+8gPynm4IbsMbfur+dmi0JylABWvLM6OBXyGDZBasoFXTN0qQiVesKVFnUSdtsRXo9PZe2AR/pi/sE1i+L/j8daerx4uCY3gavG+RiHxeJUyWhFjxILmy+06X9xYKM9dY63pD6t4YdhIJPGcBylc3jBZ+8wkdYCr0hFvNLO7IAgVhc2LhaYcxbuhMuvrQtg4PQeSunQFEtkGjebxqvbzvTgfkcuK9mj58fMuC4fff9cdizuMuso4+HQ/G53P6QQYkKjVD49KipdHzyfrgf2QaTnZpVeOLCHonRl7c8DaXE1iWbifvI7+K2jZ+/qqT/cZ4jzCetBzRBpzW4En90abJ/jhV4wDAfLc34XUT+mexDAYO6LgivFsFuYLiQEOB6WwLtjXxYriWR7C/aHmDnUc3oJ/kXcZCnQ/c/YawXyDU+kUzUhkELHtEBnyaum0yEd4yiC/PrPYqkoOlbGO6GaV/ykjfcaNV4esBsiaOn72xobPTjfMhJdFRDebeoejPGWl4gHCZTtOjnpScYjEAuz4ZNCv7n9i/i8h1KvASf0FayU+yj2B/QvysxAzgbWuEMXulTVc8L4yYFLvIZtoRRg4drQ4mWLzhx1D/JVJDndUmHcWo1N3Rl2o6E5Ytw== nagiosre@misc1'
        ],
    }
}
