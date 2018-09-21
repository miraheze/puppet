define httpd::mod(
    Array[String] $modules = [],
) {
    httpd::mod_conf { $modules:
        ensure => present
    }
}
