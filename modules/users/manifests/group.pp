# class: users::group
define users::group(
    VMlib::Ensure     $ensure     = present,
    Optional[Integer] $gid        = undef,
    Array             $privileges = [],
)
    {

    # sans specified $gid we assume system group and do not create
    if ($ensure == 'absent') or ($gid) {
        group { $name:
            ensure    => $ensure,
            name      => $name,
            allowdupe => false,
            gid       => $gid,
        }
    }

    # If specified privilege is empty we manage
    # separately from the group as a whole and cleanup
    if empty($privileges) {
        $privileges_ensure = 'absent'
    } else {
        $privileges_ensure = $ensure
    }

    sudo::group { $name:
        ensure     => $privileges_ensure,
        privileges => $privileges,
    }
}
