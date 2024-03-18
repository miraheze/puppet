# SPDX-License-Identifier: Apache-2.0
# @summary
#   Adds a banner message to the server MOTD (usually displayed on login)
#   that identifies the role of the server.
#
# @param ensure Present or absent. (Default: present.)
# @param description A human-readable description of the role. Optional.
#
define system::role(
    VMlib::Ensure       $ensure      = present,
    Optional[String[1]] $description = undef,
) {
    $role_title = regsubst($title, '^role::', '')

    $message = $description ? {
        undef   => "${facts['networking']['hostname']} is ${role_title}",
        default => "${facts['networking']['hostname']} is a ${description} (${role_title})",
    }

    motd::message { "role-${role_title}":
        ensure   => $ensure,
        priority => 5,
        message  => $message,
    }
}
