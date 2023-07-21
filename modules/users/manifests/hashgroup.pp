# class: user::hashgroup
define users::hashgroup(
    Hash $phash = {},
) {
    #explicit error as otherwise it goes forward later
    #complaining of 'invalid hash' which is hard to track down
    if !($name in $phash['groups']) {
        fail("${name} is not a valid group name")
    }

    $gdata = $phash['groups'][$name]
    if ('posix_name' in $gdata) {
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
