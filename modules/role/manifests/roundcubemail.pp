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
    String $db_host               = 'db112.miraheze.org',
    String $db_name               = 'roundcubemail',
    String $db_user_name          = 'roundcubemail',
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

    $firewall_rules_str = join(
        query_facts('Class[Role::Varnish] or Class[Role::Icinga2]', ['ipaddress', 'ipaddress6'])
        .map |$key, $value| {
            "${value['ipaddress']} ${value['ipaddress6']}"
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )

    ferm::service { 'http':
        proto   => 'tcp',
        port    => '80',
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }

    ferm::service { 'https':
        proto   => 'tcp',
        port    => '443',
        srange  => "(${firewall_rules_str})",
        notrack => true,
    }

    motd::role { 'roundcubemail':
        description => 'hosts our webmail client',
    }
}
