# class: users::user
define users::user(
    VMlib::Ensure           $ensure     = present,
    Optional[Integer]       $uid        = undef,
    Optional[Integer]       $gid        = undef,
    Array[String]           $groups     = [],
    String                  $comment    = '',
    String                  $shell      = '/bin/bash',
    Optional[Array[String]] $privileges = undef,
    Array[String]           $ssh_keys   = [],
    Boolean                 $system     = false,
    String                  $homedir    = "/home/${name}",
) {

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
        system     => $system,
        home       => $homedir,
    }

    if $ensure == 'present' {
        file { $homedir:
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

    if !($ssh_keys =~ Array) {
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
