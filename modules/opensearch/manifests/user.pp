# Manages security users.
#
# @example creates and manage a user with membership in the 'logstash' and 'kibana4' roles.
#   opensearch::user { 'bob':
#     password => 'foobar',
#     roles    => ['logstash', 'kibana4'],
#   }
#
# @param ensure
#   Whether the user should be present or not.
#   Set to `absent` to ensure a user is not installed
#
# @param password
#   Password for the given user. A plaintext password will be managed
#   with the esusers utility and requires a refresh to update, while
#   a hashed password from the esusers utility will be managed manually
#   in the uses file.
#
# @param roles
#   A list of roles to which the user should belong.
#
# @author Tyler Langlois <tyler.langlois@elastic.co>
# @author Gavin Williams <gavin.williams@elastic.co>
#
define opensearch::user (
  String                    $password,
  Enum['absent', 'present'] $ensure = 'present',
  Array                     $roles  = [],
) {
  if $password =~ /^\$2a\$/ {
    opensearch_user_file { $name:
      ensure          => $ensure,
      configdir       => $opensearch::configdir,
      hashed_password => $password,
      before          => Opensearch_user_roles[$name],
    }
  } else {
    opensearch_user { $name:
      ensure    => $ensure,
      configdir => $opensearch::configdir,
      password  => $password,
      before    => Opensearch_user_roles[$name],
    }
  }

  opensearch_user_roles { $name:
    ensure => $ensure,
    roles  => $roles,
  }
}
