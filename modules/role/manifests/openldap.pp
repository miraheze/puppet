# class: role::openldap
class role::openldap {
    include ::base
    include ::profile::openldap
    
    motd::role { 'role::openldap':
        description => 'LDAP server',
    }
}
