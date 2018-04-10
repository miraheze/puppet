define httpd::mod(
    $modules = [],
) {
    httpd::mod_conf { $modules:
        ensure => present
    }
}
