# class: users::user
define users::user(
    $ensure     = 'present',
    $uid        = undef,
    $gid        = undef,
    $groups     = [],
    $comment    = '',
    $shell      = '/bin/bash',
    $privileges = undef,
    $ssh_keys   = [],
    )
{
    validate_ensure($ensure)

    user { $name:
        ensure     => $ensure,
        name       => $name,
        uid        => $uid,
        comment    => $comment,
        gid        => $gid,
        groups     => [],
        shell      => $shell,
        managehome => true,
        allowdupe  => false,
    }

    if $ensure == 'present' {
        file { "/home/${name}":
            ensure       => 'present',
            source       => [
                "puppet:///modules/users/home/${name}/",
                'puppet:///modules/users/home/skel',
            ],
            sourceselect => 'first',
            recurse      => 'remote',
            mode         => '0644',
            owner        => $name,
            group        => $gid,
            force        => true,
            require      => User[$name],
        }
    }

    if !is_array($ssh_keys) {
        fail("${name} is not a valid ssh_keys array: ${ssh_keys}")
    }

    # recursively-managed, automatically purged
    if !empty($ssh_keys) {
        users::key { $name:
            ensure  => $ensure,
            content => join($ssh_keys, "\n"),
        }
    }

    if !empty($privileges) {
        sudo::user { $name:
            ensure     => $ensure,
            privileges => $privileges,
        }
    }
}
