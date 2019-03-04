# class: letsencrypt::web
class letsencrypt::web (
    $username = undef,
    $password = undef,
) {
    
    require_package('python3-flask', 'python3-flask-restful', 'python3-filelock')

    # To be used for miraheze/ssl
    file { '/root/.gitconfig':
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        source  => 'puppet:///modules/letsencrypt/.gitconfig',
        mode    => '0755',
    }

    group { 'sslrenewal':
        ensure => present,
    }

    user { 'sslrenewal':
        ensure     => present,
        gid        => 'sslrenewal',
        shell      => '/bin/false',
        home       => '/home/sslrenewal',
        managehome => true,
        system     => true,
    }

    file { '/home/sslrenewal/.ssh':
        ensure  => directory,
        owner   => 'sslrenewal',
        group   => 'sslrenewal',
        mode    => '0700',
        require => [
            User['sslrenewal'],
            Group['sslrenewal'],
        ],
    }

    file { '/home/sslrenewal/.ssh/id_rsa':
        ensure  => present,
        source  => 'puppet:///private/acme/id_rsa',
        owner   => 'sslrenewal',
        group   => 'sslrenewal',
        mode    => '0400',
        require => File['/home/sslrenewal/.ssh'],
    }

    file { '/home/sslrenewal/.gitconfig':
        ensure  => present,
        owner   => 'sslrenewal',
        group   => 'sslrenewal',
        source  => 'puppet:///modules/letsencrypt/.gitconfig',
        mode    => '0755',
        require => [
            User['sslrenewal'],
            Group['sslrenewal'],
        ],
    }

    file { '/home/sslrenewal/sslrenewal.py':
        ensure  => present,
        owner   => 'sslrenewal',
        group   => 'sslrenewal',
        source  => 'puppet:///modules/letsencrypt/sslrenewal.py',
        mode    => '0755',
        require => [
            User['sslrenewal'],
            Group['sslrenewal'],
        ],
    }

    git::clone { 'ssl':
        ensure    => present,
        directory => '/mnt/mediawiki-static/private/miraheze/ssl',
        origin    => 'git@github.com:miraheze/ssl.git',
        branch    => 'master',
        owner     => 'sslrenewal',
        group     => 'sslrenewal',
        mode      => '0755',
        require   => [
            File['/home/sslrenewal/.gitconfig'],
            File['/home/sslrenewal/.ssh/id_rsa'],
        ],
    }

    file { '/mnt/mediawiki-static/private/miraheze/file_lock/':
        ensure => directory,
        owner  => 'sslrenewal',
        group  => 'sslrenewal',
        mode   => '0755',
    }

    file { '/usr/local/bin/sslrenewalservice.py':
        ensure  => present,
        content => template('letsencrypt/sslrenewalservice.py.erb'),
        mode    => '0755',
        notify  => Service['sslrenewalservice'],
    }

    sudo::user { 'sslrenewal_ssl-certificate':
        user       => 'sslrenewal',
        privileges => [
            'ALL = NOPASSWD: /root/ssl-certificate',
        ],
    }

    systemd::syslog { 'sslrenewalservice':
        readable_by  => 'all',
        base_dir     => '/var/log',
        owner        => 'sslrenewal',
        group        => 'root',
        log_filename => 'sslrenewalservice.log',
    }

    systemd::service { 'sslrenewalservice':
        ensure  => present,
        content => systemd_template('sslrenewalservice'),
        restart => true,
        require => File['/usr/local/bin/sslrenewalservice.py'],
    }

    ufw::allow { "misc1 to port 5000":
        proto => 'tcp',
        port  => 5000,
        from  => '185.52.1.76',
    }

    monitoring::services { 'Ssl Renewal Service':
        check_command => 'tcp',
        vars          => {
            tcp_port    => '5000',
        },
    }
}
