class profile::icinga2::main (
    String $icinga2_db_host                 = hiera('icinga_ido_db_host', 'db4.miraheze.org'),
    String $icinga2_db_name                 = hiera('icinga_ido_db_name', 'icinga'),
    String $icinga2_db_user                 = hiera('icinga_ido_user_name', 'icinga2'),
    String $ido_db_user_password            = hiera('passwords::icinga_ido'),
    String $mirahezebots_password           = hiera('passwords::irc::mirahezebots'),
    String $icingaweb2_db_host              = hiera('icingaweb_db_host', 'db4.miraheze.org'),
    String $icingaweb2_db_name              = hiera('icingaweb_db_name', 'icingaweb2'),
    String $icingaweb2_db_user_name         = hiera('icingaweb_user_name', 'icingaweb2'),
    String $icingaweb2_db_user_password     = hiera('passwords::icingaweb2'),
    String $icingaweb2_ido_db_host          = hiera('icinga_ido_db_host', 'db4.miraheze.org'),
    String $icingaweb2_ido_db_name          = hiera('icinga_ido_db_name', 'icinga'),
    String $icingaweb2_ido_db_user_name     = hiera('icinga_ido_user_name', 'icinga2'),
    String $icingaweb2_icinga_api_password  = hiera('passwords::icinga_api'),
    String $ticket_salt                     = hiera('passwords::ticket_salt', ''),
) {
    class { '::monitoring':
        db_host               => $icinga2_db_host,
        db_name               => $icinga2_db_name,
        db_user               => $icinga2_db_user,
        db_password           => $ido_db_user_password ,
        mirahezebots_password => $mirahezebots_password,
        ticket_salt           => $ticket_salt,
    }

    class { '::icingaweb2':
        db_host               => $icingaweb2_db_host,
        db_name               => $icingaweb2_db_name,
        db_user_name          => $icingaweb2_db_user_name,
        db_user_password      => $icingaweb2_db_user_password,
        ido_db_host           => $icingaweb2_ido_db_host,
        ido_db_name           => $icingaweb2_ido_db_name,
        ido_db_user_name      => $icingaweb2_ido_db_user_name,
        ido_db_user_password  => $ido_db_user_password ,
        icinga_api_password   => $icingaweb2_icinga_api_password,
    }
}
