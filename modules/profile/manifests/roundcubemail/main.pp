class profile::roundcubemail::main (
    String $db_host               = lookup('roundcubemail_db_host', {'default_value' => 'db13.miraheze.org'}),
    String $db_name               = lookup('roundcubemail_db_name', {'default_value' => 'roundcubemail'}),
    String $db_user_name          = lookup('roundcubemail_user_name', {'default_value' => 'roundcubemail'}),
    String $db_user_password      = lookup('passwords::roundcubemail'),
    String $roundcubemail_des_key = lookup('passwords::roundcubemail_des_key'),
) {
    class { '::roundcubemail':
        db_host               => $db_host,
        db_name               => $db_name,
        db_user_name          => $db_user,
        db_user_password      => $db_user_password ,
        roundcubemail_des_key => $roundcubemail_des_key,
    }
}
