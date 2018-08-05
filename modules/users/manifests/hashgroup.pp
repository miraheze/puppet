# A defined type for group creation / user realization from hash
#
# === Parameters
#
# [*name*]
#  Hash group name
#
define users::hashgroup(
)
{

    #explicit error as otherwise it goes forward later
    #complaining of 'invalid hash' which is hard to track down
    if !has_key($::users::data['groups'], $name) {
        fail("${name} is not a valid group name")
    }

    $gdata = $::users::data['groups'][$name]
    if has_key($gdata, 'posix_name') {
        $group_name = $gdata['posix_name']
    } else {
        $group_name = $name
    }

    users::group { $group_name:
        ensure     => $gdata['ensure'],
        gid        => $gdata['gid'],
        privileges => $gdata['privileges'],
    }
}
