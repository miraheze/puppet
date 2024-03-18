# == Define: motd::script
define motd::script (
    VMlib::Ensure $ensure    = present,
    Integer[0, 99] $priority  = 50,
    Optional[String] $content = undef,
    VMlib::Sourceurl $source  = undef,
) {
    include motd

    if $source == undef and $content == undef  { fail('you must provide either "source" or "content"') }
    if $source != undef and $content != undef  { fail('"source" and "content" are mutually exclusive') }

    $safe_name = regsubst($title, '[\W_]', '-', 'G').downcase
    $script    = sprintf('%02d-%s', $priority, $safe_name)

    file { "/etc/update-motd.d/${script}":
        ensure  => $ensure,
        content => $content,
        source  => $source,
        mode    => '0555',
    }
}
