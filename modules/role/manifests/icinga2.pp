# = Class: role::icinga2
#
# Configures an Icinga 2 monitoring server with Icinga DB, Icinga Web 2,
# Redis, LDAP authentication, and API support.
#
# = Parameters
#
# [*icinga2_db_host*]
#   Hostname of the Icinga IDO database server.
#
# [*icinga2_db_name*]
#   Name of the Icinga IDO database.
#
# [*icinga2_db_user*]
#   Username used to connect to the Icinga IDO database.
#
# [*ido_db_user_password*]
#   Password for the Icinga IDO database user.
#
# [*mirahezebots_password*]
#   Password used by the IRCEcho/MirahezeBots integration.
#
# [*icingaweb2_db_host*]
#   Hostname of the Icinga Web 2 database server.
#
# [*icingaweb2_db_name*]
#   Name of the Icinga Web 2 database.
#
# [*icingaweb2_db_user*]
#   Username used to connect to the Icinga Web 2 database.
#
# [*icingaweb2_db_user_password*]
#   Password for the Icinga Web 2 database user.
#
# [*icingadb_db_host*]
#   Hostname of the Icinga DB database server.
#
# [*icingadb_db_name*]
#   Name of the Icinga DB database.
#
# [*icingadb_db_user*]
#   Username used to connect to the Icinga DB database.
#
# [*icingadb_redis_host*]
#   Hostname of the Redis server used by Icinga DB.
#
# [*icingadb_redis_port*]
#   Port of the Redis server used by Icinga DB.
#
# [*icingadb_redis_password*]
#   Password used to authenticate to the Redis server.
#
# [*ticket_salt*]
#   Shared secret used for Icinga 2 certificate auto-signing.
#
# [*ldap_password*]
#   Password used by Icinga Web 2 to authenticate against LDAP.
#
# [*icinga2_api_bind_host*]
#   Optional IP address or hostname to bind the Icinga 2 API listener to.
#   If undef, the default Icinga 2 behavior is used.
#
class role::icinga2 (
    String $icinga2_db_host                  = lookup('icinga_ido_db_host', {'default_value' => 'db182.fsslc.wtnet'}),
    String $icinga2_db_name                  = lookup('icinga_ido_db_name', {'default_value' => 'icinga'}),
    String $icinga2_db_user                  = lookup('icinga_ido_user_name', {'default_value' => 'icinga2'}),
    String $ido_db_user_password             = lookup('passwords::icinga_ido'),
    String $mirahezebots_password            = lookup('passwords::irc::mirahezebots'),
    String $icingaweb2_db_host               = lookup('icingaweb_db_host', {'default_value' => 'db182.fsslc.wtnet'}),
    String $icingaweb2_db_name               = lookup('icingaweb_db_name', {'default_value' => 'icingaweb2'}),
    String $icingaweb2_db_user               = lookup('icingaweb_user_name', {'default_value' => 'icingaweb2'}),
    String $icingaweb2_db_user_password      = lookup('passwords::icingaweb2'),
    String $icingadb_db_host                 = lookup('icingadb_db_host', {'default_value' => 'db182.fsslc.wtnet'}),
    String $icingadb_db_name                 = lookup('icingadb_db_name', {'default_value' => 'icingadb'}),
    String $icingadb_db_user                 = lookup('icingadb_db_user', {'default_value' => 'icinga2'}),
    String $icingadb_redis_host              = lookup('icingadb_redis_host', {'default_value' => 'localhost'}),
    Stdlib::Port $icingadb_redis_port        = lookup('icingadb_redis_port', {'default_value' => 6379}),
    String $icingadb_redis_password          = lookup('passwords::icingadb_redis_password'),
    String $ticket_salt                      = lookup('passwords::ticket_salt', {'default_value' => ''}),
    String $ldap_password                    = lookup('passwords::ldap_password'),
    Optional[String] $icinga2_api_bind_host  = lookup('icinga2_api_bind_host', {'default_value' => undef}),
) {
    # include prometheus::exporter::cloudflare

    class { '::monitoring':
        ido_db_host             => $icinga2_db_host,
        ido_db_name             => $icinga2_db_name,
        ido_db_user             => $icinga2_db_user,
        ido_db_password         => $ido_db_user_password,
        icingadb_db_host        => $icingadb_db_host,
        icingadb_db_name        => $icingadb_db_name,
        icingadb_db_user        => $icingadb_db_user,
        icingadb_db_password    => $ido_db_user_password,
        icingadb_redis_host     => $icingadb_redis_host,
        icingadb_redis_port     => $icingadb_redis_port,
        icingadb_redis_password => $icingadb_redis_password,
        icinga2_api_bind_host   => $icinga2_api_bind_host,
        mirahezebots_password   => $mirahezebots_password,
        ticket_salt             => $ticket_salt,
    }

    class { '::icingaweb2':
        db_host                   => $icingaweb2_db_host,
        db_name                   => $icingaweb2_db_name,
        db_user_name              => $icingaweb2_db_user,
        db_user_password          => $icingaweb2_db_user_password,
        ido_db_host               => $icinga2_db_host,
        ido_db_name               => $icinga2_db_name,
        ido_db_user_name          => $icinga2_db_user,
        ido_db_user_password      => $ido_db_user_password,
        icingadb_db_host          => $icingadb_db_host,
        icingadb_db_name          => $icingadb_db_name,
        icingadb_db_user          => $icingadb_db_user,
        icingadb_db_user_password => $ido_db_user_password,
        ldap_password             => $ldap_password,
    }

    if !defined(Ferm::Service['http']) {
        ferm::service { 'http':
            proto   => 'tcp',
            port    => '80',
            notrack => true,
        }
    }

    if !defined(Ferm::Service['https']) {
        ferm::service { 'https':
            proto   => 'tcp',
            port    => '443',
            notrack => true,
        }
    }

    system::role { 'icinga2':
        description => 'monitoring server',
    }
}
