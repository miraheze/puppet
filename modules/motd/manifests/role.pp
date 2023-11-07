# class: motd::role
define motd::role(
    VMlib::Ensure $ensure          = present,
    Optional[String] $description = undef,
) {
    $message = $description ? {
        undef   => "${facts['networking']['hostname']} is ${title}",
        default => "${facts['networking']['hostname']} is a ${description} (${title})",
    }

    motd::script { "role-${title}":
        ensure   => $ensure,
        priority => 05,
        content  => "#!/bin/sh\necho '${message}'\n",
    }
}
