define salt::master_environment(
    $salt_state_roots,
    $salt_file_roots,
    $salt_pillar_roots,
    $salt_module_roots,
    $salt_returner_roots,
){

    if ! defined(File[$salt_state_roots) {
        file { $salt_state_roots[$title]:
            ensure => directory,
            mode   => '0755',
            owner  => 'root',
            group  => 'root',
        }
    }

    if ! defined(File[$salt_file_roots) {
        file { $salt_file_roots:
            ensure => directory,
            mode   => '0755',
            owner  => 'root',
            group  => 'root',
        }
    }

    if ! defined(File[$salt_pillar_roots) {
        file { $salt_pillar_roots[$title]:
            ensure => directory,
            mode   => '0755',
            owner  => 'root',
            group  => 'root',
        }
    }

    if ! defined(File[$salt_module_roots) {
        file { $salt_module_roots[$title]:
            ensure => directory,
            mode   => '0755',
            owner  => 'root',
            group  => 'root',
        }
    }

    if ! defined(File[$salt_returner_roots) {
        file { $salt_returner_roots[$title]:
            ensure => directory,
            mode   => '0755',
            owner  => 'root',
            group  => 'root',
        }
    }
}