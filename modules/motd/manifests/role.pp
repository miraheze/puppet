# class: motd::role
define motd::role(
    VMlib::Ensure $ensure          = present,
    Optional[String] $description = undef,
) {
    $message = $description ? {
        undef   => "${::hostname} is ${title}",
        default => "${::hostname} is a ${description} (${title})",
    }

    motd::script { "role-${title}":
        ensure   => $ensure,
        priority => 05,
        content  => "#!/bin/sh\necho '${message}'\n",
    }
}
