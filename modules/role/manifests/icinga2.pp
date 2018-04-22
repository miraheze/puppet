# role: icinga
class role::icinga2 {
    include ::icinga2

    # Purge unmanaged icinga2::object::host and icinga2::object::service resources
    # This will only happen for non exported resources, that is resources that
    # are declared by the icinga host itself
    resources { 'icinga2::object::host': purge => true, }
    resources { 'icinga2::object::service': purge => true, }

    Icinga2::Object::Host <<||>> ~> Service['icinga']
    Icinga2::Object::Service <<||>> ~> Service['icinga']

    include ::icingaweb2

    ufw::allow { 'icinga2 http':
        proto => 'tcp',
        port  => '80',
    }

    ufw::allow { 'icinga2 https':
        proto => 'tcp',
        port  => '443',
    }

    motd::role { 'role::icinga2':
        description => 'central monitoring server',
    }
}
