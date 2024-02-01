# class: users::hashuser
define users::hashuser(
    Hash $phash = {},
) {

    $uinfo = $phash['users'][$name]

    if ('gid' in $uinfo) {
        $group_id = $uinfo['gid']
    } else {
        $group_id = $uinfo['uid']
    }

    if ('ssh_keys' in $uinfo) {
        $key_set = $uinfo['ssh_keys']
    } else {
        $key_set = []
    }

    users::user { $name:
        ensure     => $uinfo['ensure'],
        uid        => $uinfo['uid'],
        groups     => $uinfo['groups'],
        comment    => $uinfo['realname'],
        shell      => $uinfo['shell'],
        privileges => $uinfo['privileges'],
        ssh_keys   => $key_set,
    }
}
