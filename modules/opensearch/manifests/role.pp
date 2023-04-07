# Manage x-pack roles.
#
# @param ensure
#   Whether the role should be present or not.
#   Set to 'absent' to ensure a role is not present.
#
# @param mappings
#   A list of optional mappings defined for this role.
#
# @param privileges
#   A hash of permissions defined for the role. Valid privilege settings can
#   be found in the x-pack documentation.
#
# @example create and manage the role 'power_user' mapped to an LDAP group.
#   opensearch::role { 'power_user':
#     privileges => {
#       'cluster' => 'monitor',
#       'indices' => {
#         '*' => 'all',
#       },
#     },
#     mappings => [
#       "cn=users,dc=example,dc=com",
#     ],
#   }
#
# @author Tyler Langlois <tyler.langlois@elastic.co>
# @author Gavin Williams <gavin.williams@elastic.co>
#
define opensearch::role (
  Enum['absent', 'present'] $ensure     = 'present',
  Array                     $mappings   = [],
  Hash                      $privileges = {},
) {
  if ($name.length < 1 or $name.length > 40) {
    fail("Invalid length role name '${name}' must be between 1 and 40")
  }

  if empty($privileges) or $ensure == 'absent' {
    $_role_ensure = 'absent'
  } else {
    $_role_ensure = $ensure
  }

  if empty($mappings) or $ensure == 'absent' {
    $_mapping_ensure = 'absent'
  } else {
    $_mapping_ensure = $ensure
  }

  opensearch_role { $name :
    ensure     => $_role_ensure,
    privileges => $privileges,
  }

  opensearch_role_mapping { $name :
    ensure   => $_mapping_ensure,
    mappings => $mappings,
  }
}
