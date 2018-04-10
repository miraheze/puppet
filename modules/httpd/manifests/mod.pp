define httpd::mod(
    $modules = [],
) {
    if defined(Httpd::Mod_conf($modules)) {
        httpd::mod_conf { $modules:
            ensure => present
        }
    }
}
