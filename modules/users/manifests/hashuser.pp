# class: users::hashuser
define users::hashuser(
    $phash={},
)
{

    $uinfo = $phash['users'][$name]

    if has_key($uinfo, 'gid') {
        $group_id = $uinfo['gid']
    } else {
        $group_id = $uinfo['uid']
    }

    if has_key($uinfo, 'ssh_keys') {
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
