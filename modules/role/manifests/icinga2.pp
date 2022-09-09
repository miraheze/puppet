# = Class: role::icinga2
#
# Sets up a icinga2 server using icingaweb2.
#
# = Parameters
#
# [*icinga2_db_host*]
#   The database host you want to use for icinga2.
#
# [*icinga2_db_name*]
#   The database name.
#
# [*icinga2_db_user*]
#   Database user to connect to the database.
#
# [*ido_db_user_password*]
#   The database users password for ido
#
# [*mirahezebots_password*]
#   IRCEcho password
#
# [*icingaweb2_db_host*]
#   The database host that houses icingaweb2 database.
#
# [*icingaweb2_db_name*]
#   The database name for the icingaweb2 database.
#
# [*icingaweb2_db_user_name*]
#   The database user name for icingaweb2 database.
#
# [*icingaweb2_db_user_password*]
#   The database user password for icingaweb2 database.
#
# [*icingaweb2_ido_db_host*]
#   The database host for the ido database.
#
# [*icingaweb2_ido_db_name*]
#   The database name for the ido database.
#
# [*icingaweb2_ido_db_user_name*]
#   The database user name for the ido database.
#
# [*icingaweb2_icinga_api_password*]
#   The api password for icinga2.
#
# [*ticket_salt*]
#   Private key for CSR auto-signing.
#
# [*ldap_password*]
#   The ldap password to connect icingaweb2 to (for authentication).
#
class role::icinga2 (
    String $icinga2_db_host                 = lookup('icinga_ido_db_host', {'default_value' => 'db112.miraheze.org'}),
    String $icinga2_db_name                 = lookup('icinga_ido_db_name', {'default_value' => 'icinga'}),
    String $icinga2_db_user                 = lookup('icinga_ido_user_name', {'default_value' => 'icinga2'}),
    String $ido_db_user_password            = lookup('passwords::icinga_ido'),
    String $mirahezebots_password           = lookup('passwords::irc::mirahezebots'),
    String $icingaweb2_db_host              = lookup('icingaweb_db_host', {'default_value' => 'db112.miraheze.org'}),
    String $icingaweb2_db_name              = lookup('icingaweb_db_name', {'default_value' => 'icingaweb2'}),
    String $icingaweb2_db_user_name         = lookup('icingaweb_user_name', {'default_value' => 'icingaweb2'}),
    String $icingaweb2_db_user_password     = lookup('passwords::icingaweb2'),
    String $icingaweb2_ido_db_host          = lookup('icinga_ido_db_host', {'default_value' => 'db112.miraheze.org'}),
    String $icingaweb2_ido_db_name          = lookup('icinga_ido_db_name', {'default_value' => 'icinga'}),
    String $icingaweb2_ido_db_user_name     = lookup('icinga_ido_user_name', {'default_value' => 'icinga2'}),
    String $icingaweb2_icinga_api_password  = lookup('passwords::icinga_api'),
    String $ticket_salt                     = lookup('passwords::ticket_salt', {'default_value' => ''}),
    String $ldap_password                   = lookup('passwords::ldap_password'),
    Optional[String] $icinga2_api_bind_host = lookup('icinga2_api_bind_host', {'default_value' => undef}),
) {
    class { '::monitoring':
        db_host               => $icinga2_db_host,
        db_name               => $icinga2_db_name,
        db_user               => $icinga2_db_user,
        db_password           => $ido_db_user_password ,
        icinga2_api_bind_host => $icinga2_api_bind_host,
        mirahezebots_password => $mirahezebots_password,
        ticket_salt           => $ticket_salt,
    }

    class { '::icingaweb2':
        db_host              => $icingaweb2_db_host,
        db_name              => $icingaweb2_db_name,
        db_user_name         => $icingaweb2_db_user_name,
        db_user_password     => $icingaweb2_db_user_password,
        ido_db_host          => $icingaweb2_ido_db_host,
        ido_db_name          => $icingaweb2_ido_db_name,
        ido_db_user_name     => $icingaweb2_ido_db_user_name,
        ido_db_user_password => $ido_db_user_password ,
        icinga_api_password  => $icingaweb2_icinga_api_password,
        ldap_password        => $ldap_password,
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

    motd::role { 'icinga2':
        description => 'central monitoring server which runs icinga2',
    }
}
