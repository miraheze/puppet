# === Define logrotate::conf
#
# Thin helper for the definition of logrotate rules.
# It basically ensure consistency and that we don't risk things.
#
define logrotate::conf (
    $ensure = present,
    $source = undef,
    $content = undef,
) {

    file { "/etc/logrotate.d/${title}":
        ensure  => $ensure,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        source  => $source,
        content => $content,
    }
}
