# class: role::decommission
class role::decommission {
    include base
    
    motd::role { 'role::decommission':
        description => 'Decommisioned role',
    }
}
