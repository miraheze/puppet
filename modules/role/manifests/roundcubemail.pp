# = Class: role::roundcubemail
#
# Sets up a web based mail server.
#
# = Parameters
#
# [*db_host*]
#   The database hostname to connect to.
#
# [*db_name*]
#   The database name to use.
#
# [*db_user_name*]
#   The database user to use to connect to the database.
#
# [*db_user_password*]
#   The database user password to use to connect to the datbase.
#
# [*roundcubemail_des_key*]
#   A key used for encryption purposes
#
class role::roundcubemail (
    String $db_host               = lookup('roundcubemail_db_host', {'default_value' => 'db13.miraheze.org'}),
    String $db_name               = lookup('roundcubemail_db_name', {'default_value' => 'roundcubemail'}),
    String $db_user_name          = lookup('roundcubemail_user_name', {'default_value' => 'roundcubemail'}),
    String $db_user_password      = lookup('passwords::roundcubemail'),
    String $roundcubemail_des_key = lookup('passwords::roundcubemail_des_key'),
) {

    class { '::roundcubemail':
        db_host               => $db_host,
        db_name               => $db_name,
        db_user_name          => $db_user_name,
        db_user_password      => $db_user_password ,
        roundcubemail_des_key => $roundcubemail_des_key,
    }

    ensure_resource_duplicate('ufw::allow', 'http', {'proto' => 'tcp', 'port' => '80'})

    ensure_resource_duplicate('ufw::allow', 'https', {'proto' => 'tcp', 'port' => '443'})

    motd::role { 'roundcubemail':
        description => 'hosts our webmail client',
    }
}
