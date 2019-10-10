# role: mediawiki
class role::mediawiki {
    include ::mediawiki
    include nfs::client

    if hiera('role::mediawiki::use_strict_firewall', false) {
        # Cache proxies will never use port 80.

        ufw::allow { 'https port cp2':
            proto => 'tcp',
            port  => 443,
            from  => '107.191.126.23',
        }

        ufw::alow { ' https port cp3':
            proto => 'tcp',
            port  => 443,
            from  => '128.199.139.216',
        }

        ufw::allow { 'https port cp4':
            proto => 'tcp',
            port  => 443,
            from  => '81.4.109.133',
        }

        ufw::allow { 'https port icinga':
            proto => 'tcp',
            port  => 443,
            from  => '185.52.1.76'
        }
    } else {
        ufw::allow { 'http port tcp':
            proto => 'tcp',
            port  => 80,
        }

        ufw::allow { 'https port tcp':
            proto => 'tcp',
            port  => 443,
        }
    }

    motd::role { 'role::mediawiki':
        description => 'MediaWiki server',
    }

    file { '/mnt/mediawiki-static':
        ensure => directory,
    }

    mount { '/mnt/mediawiki-static':
        ensure  => mounted,
        device  => '185.52.1.71:/mnt/mediawiki-static',
        fstype  => 'nfs4',
        options => 'rw,soft,timeo=50,retrans=1,vers=4',
        atboot  => true,
        remounts => false,
        require => File['/mnt/mediawiki-static'],
    }
}
