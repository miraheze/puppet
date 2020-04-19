# openldap server
class profile::openldap (
    String $master = hiera('profile::openldap::master', undef),
    Integer $server_id = hiera('profile::openldap::server_id'),
    String $hash_passwords = hiera('profile::openldap::hash_passwords'),
    Boolean $read_only = hiera('profile::openldap::read_only'),
) {
    include ssl::wildcard

    class { '::openldap':
        server_id      => $server_id,
        datadir        => '/var/lib/ldap/labs',
        master         => $master,
        hash_passwords => $hash_passwords,
        read_only      => $read_only,
    }


    # only allow access to ldap tls port
    ufw::allow { 'ldaps port':
        proto => 'tcp',
        port  => 636,
    }

    # TODO: Add monitoring for ldap

    # restart slapd if it uses more than 50% of memory (T130593)
    cron { 'restart_slapd':
        ensure  => present,
        minute  => fqdn_rand(60, $title),
        command => "/bin/ps -C slapd -o pmem= | awk '{sum+=\$1} END { if (sum <= 50.0) exit 1 }' \
        && /bin/systemctl restart slapd >/dev/null 2>/dev/null",
    }
}
