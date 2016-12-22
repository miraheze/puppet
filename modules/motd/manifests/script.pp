# class: motd::script
define motd::script(
    $ensure    = present,
    $priority  = 50,
    $content   = undef,
    $source    = undef,
) {
    include ::motd

    validate_ensure($ensure)
    validate_re($priority, '^\d?\d$', '"priority" must be between 0 - 99')
    if $source == undef and $content == undef  { fail('you must provide either "source" or "content"') }
    if $source != undef and $content != undef  { fail('"source" and "content" are mutually exclusive') }

    $safe_name = regsubst($title, '[\W_]', '-', 'G')
    $script    = sprintf('%02d-%s', $priority, $safe_name)

    file { "/etc/update-motd.d/${script}":
        ensure  => $ensure,
        content => $content,
        source  => $source,
        mode    => '0555',
    }
}
